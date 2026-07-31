# ADR-004 — Recorrência, cartões, taxas e pagamentos

- Status: aceito
- Data: 22/07/2026

## Contexto

Meses curtos, fechamento de fatura, taxas desconhecidas e pagamento parcial podiam gerar divergência.

## Decisão

- Dia inexistente usa o último dia do mês em America/Sao_Paulo.
- Compra antes do fechamento entra na fatura atual; no fechamento ou depois entra na próxima.
- Melhor dia inicial é o dia seguinte ao fechamento, com correção manual auditada.
- Taxas vêm do usuário/regra ou são desconhecidas e usam pontos-base.
- Pagamentos parciais são imutáveis; correções usam cancelamento ou compensação.

## Consequências

- Competência e ocorrência têm chaves idempotentes.
- Custos desconhecidos mostram limitação explícita.
- Faturas e pagamentos exigem trilha auditável.
