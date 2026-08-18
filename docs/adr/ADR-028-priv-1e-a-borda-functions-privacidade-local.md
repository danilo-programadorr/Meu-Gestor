# ADR-028 — PRIV-1E-A: borda local Gen 2 de privacidade

**Status:** implementado somente localmente; não publicado.

## Decisão

O reset financeiro e a exclusão de conta terão codebase Gen 2 dedicado `privacy`, runtime Node 22 e apenas três callables: `preparePrivacyOperation`, `confirmPrivacyOperation` e `getPrivacyOperationStatus`. Região, identidade runtime e demais parâmetros de ambiente são fornecidos no deploy futuro; nenhuma conta de serviço, Project ID, App ID, token ou segredo é versionado.

As callables exigem Auth, App Check, e-mail verificado e perfil jurídico corrente. `prepare` e `confirm` exigem ainda `auth_time` de no máximo cinco minutos, verificado contra relógio do servidor. O UID é derivado de Auth; a frase é comparada em memória e descartada. Não há endpoint administrativo, listagem, escrita direta pelo app, cancelamento Play ou acesso a dados de outro UID.

## Consequências

O Flutter usa `cloud_functions` e `firebase_app_check` oficiais. Em debug development, App Check usa o provider de debug sem token no código; builds distribuídos usam Play Integrity. A resposta callable é consultada novamente antes de qualquer limpeza e jamais vira sucesso por cache.

Os adaptadores Admin são injetáveis para Firestore, revogação de refresh tokens, exclusão Auth e relógio. A persistência Firestore paginada e o processamento real permanecem desligados e falham fechados até PRIV-1E-B. Nenhuma Function, Rule, dado, sessão, usuário ou assinatura foi alterado neste incremento.
