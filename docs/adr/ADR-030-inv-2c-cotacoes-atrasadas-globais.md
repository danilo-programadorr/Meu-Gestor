# ADR-030 — INV-2C: snapshots globais de cotações atrasadas

## Contexto

O INV-2B definiu o contrato de cotação e da rentabilidade estimada sem persistência ou provedor. O aplicativo precisa consumir somente snapshots confirmados, sem consultar mercado por usuário, sem alterar posições manuais e sem fazer da cotação uma recomendação financeira.

## Decisão

- O contrato externo continua provider-neutral. O primeiro adaptador local é BRAPI, isolado atrás de gateway injetável, com `fetch` nativo do Node 22 e sem SDK, token ou chamada real nesta etapa.
- O snapshot global `marketQuoteSnapshots/{ticker}` contém somente ticker, classe (`stock`/`fii`), BRL, mercado `B3`, fonte, preço escalado, variação em pontos-base, horário observado, captura, atraso declarado, `staleAfter`, estado e versão. Não contém UID, carteira, posição, preço médio, valores do usuário ou token.
- A atualização Gen 2 é endpoint interno futuro, protegida por segredo injetado. Ela aceita lote interno estrito, aplica lease e idempotência por `requestId`, mantém circuit breaker por ticker e nunca substitui horário observado mais recente por resposta antiga.
- Secret Manager, Scheduler, identidade runtime e a Function são apenas referências parametrizadas. A ausência de segredo falha fechada antes de qualquer leitura/escrita; nenhum recurso externo é criado por este ADR.
- O aplicativo lê somente documentos conhecidos por ticker e somente enquanto o entitlement Premium `investmentQuotes` estiver integralmente vigente. Não há listagem, escrita cliente, acesso owner especial ou leitura após perda do serviço recorrente.
- Não existe índice composto: a única consulta implementada é `get` direto por ID de ticker. Um índice só será criado se uma consulta global futura aprovada exigir.

## Consequências

- A BRAPI não está contratada, configurada ou validada contra dados reais; fixtures são sintéticas. Antes da ativação, será necessária aprovação de licença/cobertura, limites, custo, segredo, Scheduler e deploy separado.
- Snapshot atrasado, mercado fechado, indisponível, inválido e possível evento corporativo permanecem explícitos; cobertura parcial não gera total de carteira ou histórico inventado.
- Cotações jamais alteram operações, quantidade, custo, preço médio, proventos, contas, saldo ou resumo mensal. B3 e corretoras continuam canceladas como integração, não sendo alternativa de provedor.
