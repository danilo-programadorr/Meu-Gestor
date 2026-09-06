<#
Responsabilidade: roteiro manual de deploy development que só aceita o circuito
desligado e valores fornecidos fora do repositório. Este script não é executado
pelos testes nem autoriza publicação.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidatePattern('^[a-z][a-z0-9-]{5,62}$')]
  [string]$ProjectId,
  [Parameter(Mandatory = $true)]
  [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
  [string]$FirebaseCliPath
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($env:ASSISTANT_RUNTIME_SERVICE_ACCOUNT)) {
  throw 'ASSISTANT_RUNTIME_SERVICE_ACCOUNT precisa existir somente no processo manual de deploy.'
}
if ($env:ASSISTANT_REAL_PROVIDER_ENABLED -eq 'true' -or $env:ASSISTANT_KILL_SWITCH_DISABLED -eq 'true') {
  throw 'O roteiro publica somente o circuito desligado: mantenha provedor falso e kill switch ativo.'
}

# Nenhum valor de ambiente é exibido. A etapa posterior de ativação requer
# autorização independente, revisão de IAM/controles e nova validação.
& $FirebaseCliPath deploy --only functions:assistant:assistRemoteV1 --project $ProjectId
exit $LASTEXITCODE
