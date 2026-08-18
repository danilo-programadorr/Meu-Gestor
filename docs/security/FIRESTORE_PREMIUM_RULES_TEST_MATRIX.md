# Matriz de testes Firestore — SUB-1B/SUB-1C/SUB-1F Premium

Escopo: `users/{uid}/entitlements/premium` é somente leitura própria; coleções operacionais de billing e o diretório de teste fechado são totalmente privados. O SUB-1C acrescenta enforcement local às quatro coleções de investimentos. O SUB-1F-1 amplia a suíte para 70/70 no Emulator isolado: as novas regras permanecem somente locais, nenhum documento real foi criado e nenhum Firebase real foi acessado.

| ID | Caso | Resultado esperado | Estado local |
|---|---|---|---|
| SUB-R-001 | usuário autenticado, verificado e com perfil jurídico lê o próprio `premium` | permitir `get` | automatizado |
| SUB-R-002 | usuário lê entitlement de outro UID | negar | automatizado |
| SUB-R-003 | owner lê entitlement de outro UID | negar | automatizado |
| SUB-R-004 | usuário anônimo | negar | automatizado |
| SUB-R-005 | e-mail não confirmado | negar | automatizado |
| SUB-R-006 | perfil jurídico ausente/inválido | negar | automatizado |
| SUB-R-007 | listar `entitlements` | negar | automatizado |
| SUB-R-008 | criar, atualizar ou excluir entitlement | negar | automatizado |
| SUB-R-009 | ler ID diferente de `premium` | negar | automatizado |
| SUB-R-010 | acessar subcoleção do entitlement | negar | automatizado |
| SUB-R-011 | ler/escrever `_premiumBillingEvents` | negar | automatizado |
| SUB-R-012 | ler/escrever `_premiumPurchaseBindings` | negar | automatizado |
| SUB-R-013 | ler/escrever `_premiumRtdnInbox` | negar | automatizado |
| SUB-R-014 | ler/escrever `_premiumAcknowledgementOutbox` | negar | automatizado |
| SUB-R-015 | ler/escrever `_premiumAdministrativeGrants` | negar | automatizado |
| SUB-R-016 | criar carteira sem entitlement no SUB-1C | negar | automatizado |
| SUB-R-017 | ausência ou `pending` lê/lista/escreve investimentos | negar | automatizado |
| SUB-R-018 | trial/active/grace/cancelled vigente com capability | permitir leitura e escrita | automatizado |
| SUB-R-019 | expired/hold/paused/revoked/refunded | permitir leitura histórica e negar escrita | automatizado |
| SUB-R-020 | `investmentsManual` sem `investmentIncome` | negar proventos | automatizado |
| SUB-R-021 | `investmentIncome` sem `investmentsManual` | negar carteira, ativo e operação | automatizado |
| SUB-R-022 | capability duplicada/desconhecida ou schema/revisão/owner/ambiente inválidos | negar | automatizado |
| SUB-R-023 | vencimento e limite da carência usam `request.time` | integral antes; somente leitura no/depois | automatizado |
| SUB-R-024 | operações atômicas existentes com entitlement | permitir sem atingir limites | automatizado |
| SUB-R-025 | delete, subcoleção e path desconhecido | negar | automatizado |
| SUB-R-026 | batch cliente tenta criar entitlement e editar investimento | negar integralmente | automatizado |
| SUB-R-027 | ler ou listar `_premiumClosedTestTesters` e `_premiumClosedTestGrants`, inclusive com UID diferente ou owner | negar | automatizado |
| SUB-R-028 | criar, editar ou excluir o diretório ou concessão interna de teste fechado pelo cliente | negar | automatizado |

A suíte também preserva todos os casos anteriores de perfil, owner, contas, categorias, lançamentos, compromissos, investimentos e proventos. O log integral deve permanecer sem limite de 1.000 expressões, excesso de leituras, avaliação interrompida, valor nulo ou falha interna.

SUB-1F-1 não adiciona escrita cliente de entitlement, chamada Google Play ou concessão real no Emulator. A matriz mantém a negação de todas as escritas de `premium`, da lista autorizada e dos caminhos internos; a autorização de testadores é um fluxo administrativo futuro e a ativação somente pode ocorrer pelo backend server-side após publicação explicitamente aprovada.
