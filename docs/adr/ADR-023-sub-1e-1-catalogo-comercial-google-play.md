# ADR-023 — SUB-1E-1: catálogo comercial único Google Play

## Status

Aceito para preparação local em 10/08/2026. Esta decisão não cria produto, preço, teste, testador, cobrança, backend Cloud, recurso Firebase ou configuração na Google Play.

## Contexto

O adaptador local do SUB-1D havia sido estruturado para dois IDs de produto. O modelo comercial aprovado usa uma única assinatura Google Play com variações de cobrança no próprio produto. Manter dois produtos distintos aumentaria a superfície de reconciliação e não corresponderia à configuração aprovada.

## Decisão

- O catálogo canônico local prevê somente o produto de assinatura `meu_gestor_premium`.
- O catálogo local prevê os planos-base `mensal` e `anual`. A oferta gratuita `teste-3d` pertence exclusivamente ao plano-base `mensal`, dura três dias (72 horas) e não existe para o anual.
- O país comercial inicial é o Brasil. Os preços aprovados para futura configuração no Play Console são R$ 19,90 no mensal e R$ 209,90 no anual. São parâmetros comerciais para a loja, não preços persistidos no aplicativo, no entitlement ou no Firestore.
- O cliente consulta apenas o produto único e seleciona plano-base/oferta a partir dos detalhes efetivamente retornados pela Google Play. Título, elegibilidade, moeda e preço apresentado ao usuário vêm dessa resposta localizada; um valor local nunca autoriza compra, entitlement ou cobrança.
- `in_app_purchase_android` 0.5.0 passa a ser dependência direta, já resolvida pela dependência Flutter `in_app_purchase` 3.3.0, para expor `basePlanId` e `offerToken` oficiais no Android. É mantida pelo Flutter sob licença BSD; não adiciona serviço, permissão ou SDK separado. A API genérica não oferece esses campos e por isso não é alternativa segura para selecionar a oferta.
- O domínio continua sem preço, status de loja, relógio do aparelho, recibo ou token. Compra, restauração e cancelamento exigem verificação autoritativa posterior por backend, releitura do entitlement canônico e acknowledgement idempotente pelo backend/outbox após confirmação; o cliente não reconhece a compra. O futuro backend será preparado para Google Play Developer API e RTDN, mas nesta etapa usa somente contratos, fakes e fixtures sintéticas.
- A projeção interna do backend vincula cada ciclo a um fingerprint HMAC não reversível e à origem configurada (`environment`, projeto e pacote). Eventos do mesmo ciclo não podem restaurar terminalidade, reduzir período ou trocar origem; um novo ciclo só pode começar no limite temporal permitido. Esses metadados são internos ao backend e não pertencem ao contrato público do entitlement.
- Investimentos manuais e proventos continuam Premium; o núcleo financeiro permanece gratuito. Não há integração B3, integração com corretora nem cotação implementada neste incremento.

## Consequências

Contratos e testes locais devem distinguir produto, plano-base e oferta; devem cobrir indisponibilidade da loja/rede, compra pendente, restauração, cancelamento e resposta tardia sem conceder acesso pelo cliente. O fluxo permanece falha-fechada até que uma etapa autorizada configure a loja, verificador, identidade ofuscada, App Check, backend e regras correspondentes.

R$ 19,90 e R$ 209,90 não representam receita ou margem líquida. O resultado real depende de taxa da Google Play, tributos, reembolsos, chargebacks quando aplicáveis e custos Cloud; nenhuma margem de 16–20% é prometida sem contabilidade e dados operacionais reais.

Fontes de referência: [integração de assinaturas Google Play](https://developer.android.com/google/play/billing/subscriptions), [consulta de produtos no Google Play Billing](https://developer.android.com/google/play/billing/integrate) e [restauração e testes](https://developer.android.com/google/play/billing/test).
