# ADR-013 — Categorias, lançamentos e saldo atual

## Estado

Aceita, com regras publicadas em development e validação Android concluída.

## Decisão

Categorias e lançamentos pertencem ao usuário em subcoleções diretas. Categorias têm tipo imutável e arquivamento reversível. Lançamentos representam somente receitas e despesas ocorridas, têm valor positivo em centavos, sinal derivado pelo tipo, campos financeiros imutáveis após criação e cancelamento irreversível sem exclusão.

O saldo atual não é materializado: deriva do saldo inicial das contas e de lançamentos ativos confirmados. Resumo mensal também é calculado localmente. Leituras financeiras iniciais e confirmações de mutação exigem servidor.

## Consequências

- evita divergência entre saldo persistido e movimentos;
- permite reconstrução completa dos totais;
- exige leitura do histórico inteiro nesta primeira versão do módulo;
- exige paginação e resumos derivados protegidos quando o volume crescer;
- mantém histórico após arquivamento ou cancelamento;
- posterga transferências, recorrência e projeções para incrementos próprios.
