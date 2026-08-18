# ADR-029 — INV-2B: cotações atrasadas e rentabilidade estimada

## Contexto

O acompanhamento manual já registra custo, operações, resultado realizado e proventos. O aplicativo não pode preencher preço de mercado, rentabilidade ou série histórica sem uma fonte autorizada, e a integração B3/corretora permanece cancelada.

## Decisão

- Cotação é um snapshot global por ticker, BRL e tipo de ativo (`stock` ou `fii`), nunca uma consulta por usuário ou carteira.
- O contrato exige preço unitário escalado positivo, variação em pontos-base, horário observado pela fonte, captura no servidor, atraso declarado e `staleAfter`. Preço zero/negativo, moeda divergente, timestamp ausente, campo extra e resposta antiga falham fechados.
- Estados explícitos são disponível, atrasada, mercado fechado, indisponível, inválida e possível evento corporativo. Ausência não equivale a zero.
- O backend local usa gateway injetável, lotes deduplicados, cache global, lease, retry idempotente e circuit breaker. Nenhum provedor, chave, rede, coleção ou Scheduler foi escolhido/criado nesta decisão.
- Valor de mercado e resultado não realizado são estimativas a partir de posições próprias e snapshots disponíveis. Resultado realizado e proventos recebidos continuam separados; o resultado econômico é a soma explicitamente decomposta.
- Total estimado e rentabilidade de carteira não são mostrados com cobertura parcial. Uma evolução só será exibida com snapshots realmente persistidos; histórico anterior não é inferido.
- Cotações não alteram operações, quantidade, custo, preço médio, proventos, contas, saldo ou resumo mensal. A interface declara atraso, indisponibilidade e ausência de recomendação financeira.

## Consequências

- A área exige `investmentQuotes`, capability Premium de serviço recorrente; sem confirmação ela não consulta nem reutiliza cache como autoridade.
- Antes de operação externa será necessária aprovação de provedor independente, licença/cobertura, custo, limite, contrato de atraso, segredo em cofre, persistência global, job backend e observabilidade sanitizada.
- B3, corretoras, Open Finance e consulta direta pelo aplicativo não são alternativas deste incremento.
