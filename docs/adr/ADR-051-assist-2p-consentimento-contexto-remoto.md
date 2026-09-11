# ADR-051 — ASSIST-2P: consentimento canônico para contexto remoto

## Contexto

O consentimento geral de IA não autoriza, por si só, a preparação de contexto
financeiro para uma chamada remota. A autorização precisa ser própria, estrita,
revogável e confirmada pelo servidor, sem ampliar o acesso da identidade runtime
ao banco Firestore `(default)`.

## Decisão

- O único documento de consentimento remoto é
  `users/{uid}/assistantSettings/remote`. Ele contém somente
  `consentVersion`, `financialContextAllowed` e `updatedAt`.
- A ausência do documento, campo extra/inválido, versão divergente, valor
  revogado ou leitura sem servidor equivale a `financialPrivacyActive=true`.
  Nunca existe valor padrão permissivo.
- A callable monta a autorização usando GETs REST com o bearer do próprio
  envelope autenticado. A identidade runtime usa ADC apenas para o ledger no
  banco nomeado; não recebe Firebase Admin ou permissão IAM no `(default)`.
- O Flutter exige identidade renovada e e-mail confirmado para registrar ou
  revogar o aceite. A tela lê o documento com fonte server-only e falha fechada
  diante de cache, indisponibilidade ou formato inesperado.
- A Rule local restringe o caminho ao proprietário verificado, forma exata e
  timestamp do servidor. Ela não é publicada por este incremento.

## Consequências

A callable e o provedor real permanecem desligados: nenhum dado financeiro foi
lido, enviado ou persistido nesta etapa. Qualquer ativação futura continua
dependente de validação development separada, Rules publicadas e autorização
explícita para recursos externos.
