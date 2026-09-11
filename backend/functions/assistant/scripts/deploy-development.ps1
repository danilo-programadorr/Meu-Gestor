<#
Responsabilidade: conduz manualmente o rollout development da única callable do
Assistente. Nunca é chamado por testes, não possui identificador real e falha
fechado antes de deploy, ativação do provedor ou APK se qualquer fronteira divergir.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidateSet('Inspect', 'DeploySafeCircuit', 'ActivateDevelopment', 'BuildDevelopmentApk')]
  [string]$Phase,
  [Parameter(Mandatory = $true)]
  [ValidatePattern('^[a-z][a-z0-9-]{5,62}$')]
  [string]$ProjectId,
  [Parameter(Mandatory = $true)]
  [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
  [string]$FirebaseCliPath,
  [Parameter(Mandatory = $true)]
  [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
  [string]$GcloudCliPath,
  [Parameter(Mandatory = $true)]
  [ValidatePattern('^[^\s@]+@[^\s@]+\.iam\.gserviceaccount\.com$')]
  [string]$RuntimeServiceAccount,
  [switch]$Execute
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path
$assistantRoot = Join-Path $repositoryRoot 'backend\functions\assistant'
$temporaryEnvironmentFile = Join-Path $assistantRoot '.env'
$temporaryProjectEnvironmentFile = Join-Path $assistantRoot ".env.$ProjectId"
$createdTemporaryEnvironmentFiles = [System.Collections.Generic.List[string]]::new()
$reportPath = Join-Path $repositoryRoot '.codex-tmp\assistant-rollout-development-result.json'
$expectedRegion = 'southamerica-east1'
$expectedLedgerDatabase = 'assistant-controls-dev'
$dailyLimitCents = 500
$monthlyLimitCents = 4500

# Responsabilidade: evita que parâmetros, mensagens de ferramentas ou relatórios
# possam direcionar por engano uma ação manual à produção.
function Assert-DevelopmentTarget {
  if ($ProjectId -match '(?i)(?:^|[-_])(prod|production)(?:$|[-_])' -or $ProjectId -notmatch '(?i)dev') {
    throw 'AÇÃO SUA: informe exclusivamente o identificador development confirmado; produção é sempre recusada.'
  }
  Write-Host "Alvo confirmado visualmente: development ($ProjectId)."
}

# Responsabilidade: preserva stdout e stderr de CLIs fora do relatório, mantendo
# somente resultados agregados e uma falha sanitizada para a decisão manual.
function Invoke-CapturedTool {
  param([string]$ToolPath, [string[]]$Arguments, [string]$FailureAction)
  $output = & $ToolPath @Arguments 2>&1
  if ($LASTEXITCODE -ne 0) { throw "AÇÃO SUA: $FailureAction" }
  return ($output -join "`n")
}

# Responsabilidade: exige uma escolha humana específica antes de qualquer etapa
# mutável; ausência de entrada, texto diferente ou modo sem Execute não opera nada.
function Confirm-ManualAction {
  param([string]$Phrase)
  if (-not $Execute) { throw 'Modo de inspeção: informe -Execute somente após revisar os resultados visíveis.' }
  $typed = Read-Host "Digite exatamente $Phrase"
  if ($typed -cne $Phrase) { throw 'Confirmação não correspondeu; nenhuma ação foi executada.' }
}

# Responsabilidade: garante que o dotenv efêmero não possa ser versionado antes
# de receber a identidade runtime e remove-o em finally após o deploy permitido.
function Assert-TemporaryEnvironmentPath {
  foreach ($file in @($temporaryEnvironmentFile, $temporaryProjectEnvironmentFile)) {
    if (Test-Path -LiteralPath $file) { throw 'AÇÃO SUA: arquivo .env preexistente; preserve-o e audite manualmente antes de continuar.' }
    $relativeFile = [System.IO.Path]::GetRelativePath($repositoryRoot, $file).Replace('\', '/')
    & git -C $repositoryRoot check-ignore -q -- $relativeFile
    if ($LASTEXITCODE -ne 0) { throw 'AÇÃO SUA: arquivo temporário .env não está ignorado pelo Git.' }
  }
}

# Responsabilidade: cria somente os dois dotenvs ausentes e com newline final;
# o arquivo base recebe a identidade e o específico do projeto fixa os flags seguros.
function New-SafeTemporaryEnvironmentFiles {
  [System.IO.File]::WriteAllLines($temporaryEnvironmentFile, @("ASSISTANT_RUNTIME_SERVICE_ACCOUNT=$RuntimeServiceAccount"))
  $createdTemporaryEnvironmentFiles.Add($temporaryEnvironmentFile)
  [System.IO.File]::WriteAllLines($temporaryProjectEnvironmentFile, @('ASSISTANT_REAL_PROVIDER_ENABLED=false', 'ASSISTANT_KILL_SWITCH_DISABLED=false'))
  $createdTemporaryEnvironmentFiles.Add($temporaryProjectEnvironmentFile)
}

# Responsabilidade: remove exclusivamente dotenvs cuja criação foi registrada
# neste processo, preservando qualquer arquivo preexistente do usuário.
function Remove-CreatedTemporaryEnvironmentFiles {
  foreach ($file in $createdTemporaryEnvironmentFiles) {
    if (Test-Path -LiteralPath $file) { Remove-Item -LiteralPath $file -Force }
  }
}

# Responsabilidade: confere o artefato local que será implantado, inclusive os
# limites Gen 2, App Check e as flags fechadas, sem consultar ou mudar a nuvem.
function Assert-LocalSafeCircuit {
  $options = Get-Content -LiteralPath (Join-Path $assistantRoot 'src\function_options.mjs') -Raw
  $entryPoint = Get-Content -LiteralPath (Join-Path $assistantRoot 'index.mjs') -Raw
  $dependencies = Get-Content -LiteralPath (Join-Path $assistantRoot 'src\fail_closed_dependencies.mjs') -Raw
  $ledger = Get-Content -LiteralPath (Join-Path $repositoryRoot 'backend\assistant\src\cost_control_ledger.mjs') -Raw
  foreach ($required in @('southamerica-east1', '256MiB', 'timeoutSeconds: 30', 'maxInstances: 1', 'concurrency: 1', 'enforceAppCheck: true')) {
    if (-not $options.Contains($required)) { throw 'AÇÃO SUA: o artefato local não corresponde aos limites aprovados.' }
  }
  if (-not $entryPoint.Contains('createFailClosedAssistantDependencies') -or -not $dependencies.Contains('const unavailable')) {
    throw 'AÇÃO SUA: o circuito seguro local não está fail-closed.'
  }
  if (-not $ledger.Contains('dailyLimitCents: 500') -or -not $ledger.Contains('monthlyOperationalLimitCents: 4_500')) {
    throw 'AÇÃO SUA: o ledger local não corresponde aos limites development aprovados.'
  }
  Write-Host 'Circuito local confirmado: App Check, limites Gen 2, kill switch e provedor permanecem fechados.'
}

# Responsabilidade: limita a identidade a Vertex, logs e ao ledger nomeado; uma
# concessão fora dessa lista ou acesso ao banco padrão impede todo rollout.
function Assert-MinimumRuntimePermissions {
  $policyJson = Invoke-CapturedTool -ToolPath $GcloudCliPath -Arguments @('projects', 'get-iam-policy', $ProjectId, '--format=json') -FailureAction 'sem leitura de IAM suficiente para auditar a identidade runtime.'
  $policy = $policyJson | ConvertFrom-Json
  $member = "serviceAccount:$RuntimeServiceAccount"
  $bindings = @($policy.bindings | Where-Object { $_.members -contains $member })
  $roles = @($bindings | ForEach-Object { $_.role })
  $allowedRoles = @('roles/aiplatform.user', 'roles/logging.logWriter', 'roles/datastore.user')
  if ($roles -notcontains 'roles/aiplatform.user') { throw 'AÇÃO SUA: falta a permissão mínima Vertex da identidade runtime; não altere IAM por este script.' }
  if (@($roles | Where-Object { $_ -notin $allowedRoles }).Count -ne 0) { throw 'AÇÃO SUA: a identidade runtime possui papel não aprovado; revise IAM manualmente.' }
  $ledgerBindings = @($bindings | Where-Object { $_.role -eq 'roles/datastore.user' })
  foreach ($binding in $ledgerBindings) {
    $expression = [string]$binding.condition.expression
    if ($expression -notmatch [regex]::Escape("databases/$expectedLedgerDatabase") -or $expression -match '\(default\)') {
      throw 'AÇÃO SUA: acesso Firestore da identidade runtime não está limitado ao ledger nomeado.'
    }
  }
  Write-Host 'IAM confirmado de forma agregada: Vertex mínimo, logs e ledger nomeado; sem banco padrão.'
}

# Responsabilidade: compara a Function existente com a configuração aprovada
# sem expor identidade, URL, configuração de ambiente ou outro dado privado.
function Assert-RemoteFunctionConfiguration {
  $functionJson = Invoke-CapturedTool -ToolPath $GcloudCliPath -Arguments @('functions', 'describe', 'assistRemoteV1', '--gen2', "--region=$expectedRegion", "--project=$ProjectId", '--format=json') -FailureAction 'a Function development não foi encontrada ou não pôde ser lida.'
  $function = $functionJson | ConvertFrom-Json
  $service = $function.serviceConfig
  $effectiveMinInstanceCount = if ($null -eq $service.minInstanceCount) { 0 } else { $service.minInstanceCount }
  $differences = [System.Collections.Generic.List[string]]::new()
  if ($function.environment -ne 'GEN_2') { $differences.Add('ambiente Gen 2') }
  if ([string]$function.name -notmatch [regex]::Escape("/locations/$expectedRegion/")) { $differences.Add('região') }
  if ([string]$service.serviceAccountEmail -ne $RuntimeServiceAccount) { $differences.Add('identidade runtime') }
  if ([string]$service.availableMemory -notin @('256M', '256Mi', '256MiB')) { $differences.Add('memória') }
  if ($service.timeoutSeconds -ne 30) { $differences.Add('timeout') }
  if ($service.maxInstanceCount -ne 1) { $differences.Add('máximo de instâncias') }
  if ($effectiveMinInstanceCount -ne 0) { $differences.Add('mínimo de instâncias') }
  if ($service.maxInstanceRequestConcurrency -ne 1) { $differences.Add('concorrência') }
  if ($differences.Count -ne 0) {
    throw "AÇÃO SUA: a configuração remota divergiu em: $($differences -join ', ')."
  }
  Write-Host 'Function remota confirmada: região, identidade e limites aprovados.'
}

# Responsabilidade: impede ativação global enquanto os adaptadores concretos de
# autorização, ledger e contexto ainda forem explicitamente fail-closed no código.
function Assert-ActivationReadiness {
  $node = Get-Command node -ErrorAction SilentlyContinue
  if ($null -eq $node) { throw 'AÇÃO SUA: Node local indisponível para validar os adaptadores antes da ativação.' }
  & $node.Source (Join-Path $assistantRoot 'scripts\assert-activation-readiness.mjs')
  if ($LASTEXITCODE -ne 0) { throw 'AÇÃO SUA: ativação global bloqueada; adaptadores concretos não estão conectados localmente.' }
}

# Responsabilidade: registra apenas fase, instante e limites agregados em pasta
# ignorada; nunca escreve identidade, prompts, respostas, contexto ou credenciais.
function Write-AggregateReport {
  param([string]$Result)
  $directory = Split-Path -Parent $reportPath
  New-Item -ItemType Directory -Force -Path $directory | Out-Null
  & git -C $repositoryRoot check-ignore -q -- '.codex-tmp/assistant-rollout-development-result.json'
  if ($LASTEXITCODE -ne 0) { throw 'Relatório temporário não está ignorado pelo Git.' }
  $report = [ordered]@{ phase = $Phase; result = $Result; completedAt = [DateTime]::UtcNow.ToString('o'); dailyLimitCents = $dailyLimitCents; monthlyLimitCents = $monthlyLimitCents } | ConvertTo-Json
  Set-Content -LiteralPath $reportPath -Value $report -Encoding utf8 -NoNewline
}

Assert-DevelopmentTarget
Assert-LocalSafeCircuit
Assert-MinimumRuntimePermissions

switch ($Phase) {
  'Inspect' {
    Assert-RemoteFunctionConfiguration
    Write-AggregateReport -Result 'inspection_passed'
    Write-Host 'Inspeção concluída; nenhuma alteração externa foi executada.'
  }
  'DeploySafeCircuit' {
    Confirm-ManualAction -Phrase 'PUBLICAR CIRCUITO DEVELOPMENT DESLIGADO'
    Assert-TemporaryEnvironmentPath
    try {
      New-SafeTemporaryEnvironmentFiles
      & $FirebaseCliPath deploy --only functions:assistant:assistRemoteV1 --project $ProjectId
      if ($LASTEXITCODE -ne 0) { throw 'Deploy do circuito development desligado falhou.' }
    } finally {
      Remove-CreatedTemporaryEnvironmentFiles
    }
    Assert-RemoteFunctionConfiguration
    Write-AggregateReport -Result 'safe_circuit_deployed'
    Write-Host 'Deploy seguro concluído; provedor continua desligado e kill switch ativo.'
  }
  'ActivateDevelopment' {
    Assert-ActivationReadiness
    Confirm-ManualAction -Phrase 'ATIVAR PROVEDOR SOMENTE EM DEVELOPMENT'
    throw 'Ativação não pode prosseguir sem uma autorização específica de deploy e adaptadores concretos auditados.'
  }
  'BuildDevelopmentApk' {
    Confirm-ManualAction -Phrase 'GERAR APK DEVELOPMENT COM ASSISTENTE REMOTO'
    & flutter build apk --debug --dart-define=APP_ENV=development --dart-define=ASSISTANT_REMOTE_ENABLED=true
    if ($LASTEXITCODE -ne 0) { throw 'Build do APK debug development falhou.' }
    Write-AggregateReport -Result 'development_apk_built'
    Write-Host 'APK debug development criado; builds production continuam sem chamada remota.'
  }
}
