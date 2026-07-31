# ADR-001 — Dados de demonstração controlados

- Status: aceito
- Data: 22/07/2026

## Contexto

A especificação pede dados de demonstração opcionais, enquanto as regras permanentes proibiam dados fictícios.

## Decisão

Permitir demonstração somente em development e testes, desativada por padrão, ativada explicitamente, sem dados reais, apagável e impedida de acessar Firebase production.

## Consequências

- Produção nunca apresenta dados fictícios.
- Configuração de ambiente precisa ser verificável e testada.
- AGENTS.md contém a exceção controlada.
