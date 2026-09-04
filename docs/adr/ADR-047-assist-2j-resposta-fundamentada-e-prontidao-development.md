# ADR-047 — ASSIST-2J: resposta fundamentada e prontidão development

## Decisão

Toda resposta financeira futura é neutra e estruturada. Cada afirmação exige
um alias efêmero de evidência, fonte permitida e período civil
`America/Sao_Paulo` já presentes no contexto confirmado pelo servidor. A
ausência de base, uma fonte/período inválido, recomendação, identidade,
terceiro, segredo ou número não comprovado devolve somente `safe_unavailable`.

A montagem ocorre apenas no backend por leitores injetados depois de
consentimento, privacidade, escopo próprio e período admitidos. Nesta etapa os
testes usam somente fixtures sintéticas; Flutter não recebe o contexto nem há
rede ou provedor.

A prontidão development é um checklist local sem valores de configuração:
identidade runtime, Secret Manager, App Check, consentimento e rollback devem
ser validados em autorização externa futura. Kill switch e flag do provedor
permanecem desligados. Flash é a rota padrão lógica, Pro só pode ser escolhido
internamente pelo backend, e o ledger já limita R$5/dia e R$45/mês.

## Consequências

Nenhuma chamada Vertex, segredo, identidade, recurso externo ou integração
Flutter é criada. A ativação development exigirá autorização separada e a
validação de todos os pré-requisitos reais antes de qualquer liberação.
