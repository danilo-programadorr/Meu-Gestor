# ADR-010 — Saldo, verificação, reajustes e meios financeiros

- Status: aceito
- Data: 22/07/2026

## Contexto

Saldo, acesso pré-verificação, reajustes e meios de movimentação precisam de fontes e enumerações únicas para evitar divergência entre cliente, backend e relatórios.

## Decisão

- O saldo canônico é saldo inicial mais entradas confirmadas, menos saídas confirmadas, mais transferências recebidas confirmadas e menos transferências enviadas confirmadas.
- Saldos materializados e `monthlySummaries` são caches protegidos e totalmente reconstruíveis.
- Usuário sem `emailVerified=true` fica limitado a confirmação, reenvio, atualização do estado, logout, exclusão e documentos jurídicos.
- Reajuste é fixo ou percentual, possui vigência e entidade relacionada e afeta somente ocorrências futuras.
- Reajuste retroativo exige confirmação explícita e operações auditáveis.
- Formas de recebimento: pix, transferência bancária, dinheiro, cartão, boleto, cheque e outro.
- Formas de pagamento: pix, transferência bancária, dinheiro, cartão de débito, cartão de crédito, boleto, débito automático e outro.

## Consequências

- Caches podem ser descartados e reconstruídos sem perda financeira.
- Security Rules e guardas de rota deverão bloquear dados financeiros antes da verificação.
- Conversores usarão enumerações fechadas e rótulos pt-BR.
- Alterações retroativas não sobrescreverão silenciosamente ocorrências existentes.
