# ADR-022 — SUB-1D: Google Play Billing local e falha fechada

## Status

Aceito localmente em 10/08/2026. A integração estrutural não autoriza produto, cobrança, backend Cloud, deploy de regras ou produção.

## Decisão

- Usar `in_app_purchase` 3.3.0, mantido pelo Flutter, como adaptador da Google Play Billing; `url_launcher` 6.3.2, também mantido pelo Flutter, abre somente a Central oficial de Assinaturas.
- IDs mensal/anual são configuração explícita e validada. Não há ID, preço, oferta, token ou pacote real versionado.
- A UI mostra preço e moeda somente quando a loja devolve dados completos. Sem catálogo ou verificador, mostra “Assinaturas em preparação”.
- Uma atualização local de compra nunca concede capability. O token permanece em memória apenas para o contrato de verificação e não aparece em estado, diagnóstico ou log. A liberação exige verificação de backend e releitura confirmada do entitlement canônico.
- `pending` não confirma nem reconhece compra; acknowledgement fica condicionado ao backend/outbox real após confirmação. O identificador ofuscado de conta também é contrato de backend futuro: UID puro não será enviado à Google Play.
- O app oferece restauração e link externo seguro para a Central de Assinaturas, sem cancelamento simulado ou retenção artificial.
- A concessão development permanece serviço backend puro, abstrato, idempotente, revogável e agora produz auditoria sanitizada. Não existe comando, endpoint público, UID ou credencial operacional nesta etapa.

## Consequências

O fluxo real continua bloqueado porque faltam produtos Play, backend verificador, geração segura de identidade ofuscada, App Check preparado, entitlement development real e publicação autorizada das regras SUB-1C. Nenhum owner, debug, e-mail, UID ou `dart-define` libera acesso.

Fontes: [Flutter in_app_purchase](https://pub.dev/packages/in_app_purchase), [integração Billing](https://developer.android.com/google/play/billing/integrate), [testes com license testers](https://developer.android.com/google/play/billing/test) e [gerenciamento de assinaturas](https://developer.android.com/google/play/billing/subscriptions).
