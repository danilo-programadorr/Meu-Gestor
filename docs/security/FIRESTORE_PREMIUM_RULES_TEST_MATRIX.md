# Matriz de testes Firestore — SUB-1B Premium

Escopo: `users/{uid}/entitlements/premium` é somente leitura própria; coleções operacionais de billing são totalmente privadas. A suíte local aprovou 57/57 casos no Emulator `demo-*` e as regras foram publicadas exclusivamente em development, sem acesso a production, com SHA-256 `F01E52545F2CE88896A48B28B957BF45F8AE79B0173DF2E20449929FF21532B4`. Nenhum documento foi criado e investimentos permanecem sem bloqueio Premium; commit e push estão pendentes.

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
| SUB-R-016 | criar carteira sem entitlement no SUB-1B | permitir conforme regras atuais | automatizado |

A suíte também preserva todos os casos anteriores de perfil, owner, contas, categorias, lançamentos, compromissos, investimentos e proventos. O SUB-1B não usa entitlement para liberar ou bloquear investimentos.
