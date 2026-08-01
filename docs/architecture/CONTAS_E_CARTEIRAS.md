# Contas e carteiras — Etapa 4A

## Escopo

Este incremento implementa somente contas financeiras, carteiras, saldo inicial, total, criação, listagem, detalhes, edição, arquivamento e restauração. Não existem transações, transferências, receitas, despesas, cartões, faturas, projeções ou exclusão definitiva.

## Arquitetura

O módulo `features/accounts` mantém as dependências voltadas ao domínio:

- `domain`: `FinancialAccount`, tipos, validação de nome e dinheiro, cálculo do total, falhas e contrato do repositório;
- `data`: mapper estrito, diagnóstico sanitizado e implementação Cloud Firestore;
- `presentation/controllers`: leitura de lista, leitura por documento e ações com Riverpod;
- `presentation/pages`: lista, formulário, detalhes e arquivadas;
- `presentation/widgets`: cartão, total, seletor de tipo, campo monetário e suporte visual.

Widgets não importam Cloud Firestore. O domínio não importa Firebase, Flutter widgets ou Riverpod. `Map<String, dynamic>` fica restrito ao mapper e ao repositório de dados.

## Fluxo de autorização

1. `go_router` exige usuário autenticado e email confirmado.
2. `ProfileGate` exige token atualizado, perfil confirmado pelo servidor e versões jurídicas atuais.
3. O controller confirma que o proprietário da sessão corresponde ao perfil válido.
4. O repositório consulta somente `users/{uid}/accounts` ou um documento dessa subcoleção.
5. As regras Firestore repetem Auth, `email_verified`, UID e existência de perfil com esquema e versões jurídicas atuais; a interface não é o controle de segurança final.

As rotas protegidas são `/contas`, `/contas/nova`, `/contas/:accountId`, `/contas/:accountId/editar` e `/contas-arquivadas`. O redirect não lê Firestore diretamente.

## Modelo e saldo

O documento contém exatamente `ownerId`, `name`, `type`, `openingBalanceCents`, `currencyCode`, `includeInTotal`, `isArchived`, `archivedAt`, `createdAt`, `updatedAt` e `schemaVersion`. O ID está somente no caminho.

Nesta etapa:

`saldo exibido = openingBalanceCents`

`total = soma de openingBalanceCents onde isArchived=false e includeInTotal=true`

O cálculo usa `int`. Cada saldo inicial aceita de -9.999.999.999 a 9.999.999.999 centavos. Não há `double`, saldo materializado ou `currentBalanceCents`.

Quando movimentos existirem, a fonte canônica será saldo inicial mais entradas e transferências recebidas confirmadas, menos saídas e transferências enviadas confirmadas. A edição direta do saldo inicial deverá ser bloqueada ou convertida em ajuste auditável.

## Criação e confirmação

O controller valida antes do envio, impede toques simultâneos e gera o ID uma vez por tentativa. O repositório usa transação sem merge: documento ausente é criado; documento existente com o mesmo ID e os mesmos dados confirma retry idempotente; conteúdo diferente é conflito. O sucesso só é informado depois de releitura `Source.server` sem escrita pendente.

Em falha incerta de rede, o repositório procura o mesmo ID no servidor. Sem confirmação, a interface orienta nova tentativa com o mesmo ID, evitando duplicação.

## Edição, arquivamento e restauração

Edição altera somente nome, tipo, saldo inicial e participação no total, além de `updatedAt`. Arquivamento grava estado, `archivedAt` e `updatedAt` com timestamp do servidor. Restauração limpa `archivedAt` e atualiza estado e timestamp. Não existe método de exclusão no contrato nem ação de exclusão na interface.

## Consultas e offline

A lista lê a subcoleção própria sem filtros ou ordenação no servidor; separação de ativas/arquivadas, ordenação nominal e total são locais. Não há `collectionGroup`, listener persistente ou índice composto.

A primeira lista e os detalhes exigem servidor. Cache não autoriza nem confirma mutações. A estratégia offline financeira completa permanece pendente; indisponibilidade mostra erro seguro e retry, sem total potencialmente enganoso.

## Diagnósticos

Em development, registros contêm somente operação, etapa, tipo de exceção, código Firestore e categoria. UID, email, nome, saldo, documento, token, projeto e caminho completo não são registrados. Production não emite esses diagnósticos.

## Limitações deliberadas

- regras de contas aguardam publicação manual;
- testes reais no Emulator Suite aguardam autorização;
- nenhum APK da Etapa 4A foi gerado no Ponto de Controle 1;
- nenhuma conta real foi criada por automação;
- transações, cartões e exclusão permanente permanecem ausentes.
