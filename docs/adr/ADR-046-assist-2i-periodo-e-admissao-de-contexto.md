# ADR-046 — ASSIST-2I: período financeiro e admissão de contexto

## Decisão

Períodos financeiros usam exclusivamente `America/Sao_Paulo`, representados
como intervalo civil `[startDate, endDateExclusive)`. UTC permanece apenas em
`generatedAt` e na janela técnica derivada pelo servidor. A conversão usa a
base de fusos do runtime, incluindo o horário de verão histórico brasileiro.

Cada fato transportável contém fonte fechada, período civil e uma evidência
com alias efêmero. Faltas de fonte, intervalo ambíguo, valor sem evidência,
campo extra, dado de terceiro ou identificador persistente invalidam todo o
contexto.

Uma admissão fail-closed ocorre antes de qualquer leitor futuro: valida
privacidade financeira, escopo próprio fechado, limite de fontes e período
civil. Ela não aceita UID, e-mail, IDs, valores ou instruções do cliente.
Flash/Pro continuam desligados; a borda remota preserva `safe_unavailable`.

## Consequências

Leitores reais, acesso ao banco padrão, Vertex ou ligação Flutter continuam
fora deste incremento e requerem autorização separada.
