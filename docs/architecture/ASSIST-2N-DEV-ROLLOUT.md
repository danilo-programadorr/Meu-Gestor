# ASSIST-2N — roteiro de rollout development do Assistente

## Limite desta preparação

O roteiro em `backend/functions/assistant/scripts/deploy-development.ps1` é
versionado para revisão, mas não foi executado neste incremento. Ele não contém
identificador de projeto, e-mail, token, chave, prompt, resposta ou contexto
financeiro. Toda operação externa continua dependendo de autorização separada.

## Pré-requisitos manuais

1. Em um PowerShell visível, informe somente o identificador development já
   confirmado, os caminhos locais das CLIs e a identidade runtime existente.
2. Execute primeiro a fase `Inspect`. Ela exige o alvo development, confere a
   única Function, região `southamerica-east1`, 256 MiB, 30 segundos,
   concorrência e instâncias, App Check no artefato, circuito fechado e IAM
   mínimo. A ausência de `minInstanceCount` no retorno Gen 2 é normalizada
   estritamente para o valor efetivo `0`; qualquer outro campo ausente ou
   divergente interrompe o roteiro com o nome do campo. Qualquer papel fora de
   Vertex, Logs Writer ou acesso condicionado ao ledger nomeado interrompe o
   roteiro.
3. Revise somente a mensagem agregada exibida. Não copie saída bruta de IAM,
   Function, token ou configuração para documentação, chat ou Git.

## Deploy seguro desligado

Execute `DeploySafeCircuit` apenas depois de conferir o resultado da inspeção e
digitar literalmente `PUBLICAR CIRCUITO DEVELOPMENT DESLIGADO`. O script cria
um `.env` e um `.env.<development>` ignorados e efêmeros somente durante o
deploy da callable `assistRemoteV1`. O primeiro recebe somente a identidade e
o segundo fixa provedor falso e kill switch ativo, ambos com newline final. O
script cria apenas arquivos antes ausentes e remove somente os que ele próprio
registrou, inclusive em falha. O seletor Firebase é estrito:
`functions:assistant:assistRemoteV1`.

Após o deploy, o roteiro relê região, identidade e limites. A callable deve
continuar respondendo somente indisponibilidade segura; ela não pode montar
contexto, reservar custo, consultar Vertex ou receber dados do Flutter.
Os flags seguros são avaliados apenas no runtime da callable e do gateway; o
deploy não materializa seus valores por avaliar `defineBoolean.value()`.

## Ativação global development

`ActivateDevelopment` permanece apenas como um roteiro manual versionado: ela
exige que os adaptadores concretos e transacionais de autorização, contexto
próprio e ledger já passem no pré-check local, que a Function development
existente corresponda a região, identidade e limites aprovados e que uma pessoa
digite literalmente `ATIVAR PROVEDOR SOMENTE EM DEVELOPMENT`.

Somente depois dessas fronteiras, a fase cria os dois dotenvs efêmeros antes
ausentes: o base recebe a identidade runtime fornecida fora do Git e o do
projeto development recebe explicitamente
`ASSISTANT_REAL_PROVIDER_ENABLED=true` e
`ASSISTANT_KILL_SWITCH_DISABLED=true`. O deploy continua limitado a
`functions:assistant:assistRemoteV1`. Um `finally` remove somente os arquivos
registrados pelo próprio processo, mesmo se o deploy falhar.

Após o deploy, o roteiro relê a configuração Gen 2 e exige, além da região,
identidade e limites, os dois controles de runtime com valor efetivo `true`.
Qualquer alvo production, projeto não-development, adaptador ausente, falha de
deploy ou flag inconsistente interrompe a etapa. A existência desse roteiro não
constitui ativação: a execução externa ainda exige autorização específica.

## APK debug de development

Após autorização externa independente e somente com a Function segura, a fase
`BuildDevelopmentApk` exige a confirmação `GERAR APK DEVELOPMENT COM
ASSISTENTE REMOTO`. Ela compila somente:

```powershell
flutter build apk --debug --dart-define=APP_ENV=development --dart-define=ASSISTANT_REMOTE_ENABLED=true
```

O define não é uma chave nem habilita production: a política Flutter só permite
rede quando ambos `APP_ENV=development` e `ASSISTANT_REMOTE_ENABLED=true` foram
compilados. Sem essa combinação, nenhuma chamada é criada.

## Primeiro teste real futuro

1. Confirmar consentimento de IA, e-mail verificado, App Check e privacidade
   financeira desativada para a conta autorizada.
2. Usar uma pergunta curta sem dados financeiros pessoais para verificar a
   resposta fundamentada ou indisponibilidade segura.
3. Conferir somente métricas agregadas de fase, custo reservado/confirmado e
   duração. Não registrar pergunta, resposta, UID, e-mail, token, contexto ou
   valores.
4. Ao primeiro limite, falha de App Check, falta de evidência ou divergência,
   manter kill switch ativo e interromper o rollout.
