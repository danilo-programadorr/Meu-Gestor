# Categorias, lançamentos e saldo atual

## Escopo do incremento 4B

Este incremento implementa categorias próprias, receitas e despesas já ocorridas, cancelamento sem exclusão, resumo do mês e saldo atual derivado. Não inclui recorrência, transferências, contas a pagar/receber, anexos, cartões, projeções, notificações ou IA.

## Fonte canônica

O saldo de cada conta é calculado em memória por:

`saldo inicial + receitas ativas confirmadas - despesas ativas confirmadas`

Lançamentos cancelados não participam do saldo. `currentBalanceCents`, totais e resumos mensais não são persistidos como fonte canônica. O cálculo usa `BigInt` durante a agregação e só converte para inteiro após validar o intervalo seguro de 64 bits.

## Camadas

- `domain`: entidades imutáveis, enums fechados, normalização, datas, parser monetário e cálculo;
- `data`: mappers estritos, repositórios Firestore, confirmação pelo servidor e diagnóstico sanitizado;
- `presentation`: controllers Riverpod, rotas, formulários, filtros locais e telas acessíveis;
- `firestore.rules`: isolamento por UID, campos exatos, referências ativas, tipos compatíveis e transições permitidas.

Widgets não acessam Firebase diretamente. O estado recebe a entidade já confirmada pelo servidor após mutações; não há atualização otimista de valores financeiros.

## Convenção de datas

`occurredAt` representa uma data civil em `America/Sao_Paulo`. A data escolhida é persistida como 03:00 UTC, correspondente à meia-noite em São Paulo no fuso inicial UTC-3. Comparações de hoje, futuro e mês convertem primeiro para a data civil de São Paulo. Uma futura política multirregional exigirá revisão desta convenção.

## Consultas e custo

As leituras usam somente `users/{uid}/categories` e `users/{uid}/transactions`, com origem servidor. Ordenação e filtros são locais; nenhum índice composto foi adicionado. Esta estratégia é adequada ao volume pessoal inicial, mas exige paginação e consultas indexadas antes de histórico grande.

## Limites deliberados

- não há exclusão definitiva de categoria ou lançamento;
- o tipo da categoria é imutável;
- conta, tipo e valor do lançamento são imutáveis após criação;
- cancelamento é irreversível na interface e nas regras;
- categorias arquivadas permanecem legíveis para histórico, mas não podem ser usadas em novos lançamentos;
- conta arquivada não aceita novo lançamento;
- primeira leitura offline não libera dados financeiros como confirmados;
- testes reais das regras aguardam autorização futura do Emulator Suite.
