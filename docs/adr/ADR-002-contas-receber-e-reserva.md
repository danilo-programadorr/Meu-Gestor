# ADR-002 — Contas a receber e reserva financeira

- Status: aceito
- Data: 22/07/2026

## Contexto

Contas a receber e reserva possuíam fontes de verdade ambíguas.

## Decisão

Contas a receber usam coleção própria receivables. Cada recebimento cria ou vincula uma renda por chave idempotente.

Reserva é uma meta vinculada a conta. Movimentos da meta são canônicos; o valor reservado da conta é resumo reconstruível.

## Consequências

- Renda e crédito a receber não são confundidos.
- Recebimentos e resumos exigem idempotência.
- Reserva integra saldo bancário, mas não dinheiro livre.
