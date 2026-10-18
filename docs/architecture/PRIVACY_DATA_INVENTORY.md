# Inventário técnico de privacidade — PRIV-1E-B

Estado confrontado com o código em 18/10/2026. “Retenção” descreve somente
decisões já aceitas; itens futuros não são tratados como dados existentes.

| Domínio | Local | Owner | Reset remove? | Exclusão remove? | Retenção | Dependências | Ordem | Idempotência | Evidência |
|---|---|---|---|---|---|---|---|---|---|
| Firebase Authentication | Auth | UID verificado | não | sim, por último | não aplicável após exclusão | revogação de refresh tokens | depois de todos os dados | `user-not-found` equivale a exclusão já concluída | ADR-027 e adaptadores Admin |
| Perfil e consentimentos gerais | `users/{uid}` | `ownerId`/UID do caminho | não | sim | apagar | perfil jurídico na preparação | último documento Firestore próprio | delete repetível | Rules, perfil Firebase |
| Consentimento remoto da Luma | `users/{uid}/assistantSettings/remote` | UID do caminho | não | sim | apagar | nenhuma | antes do perfil | delete repetível | ADR-051 e repositório Flutter |
| Contas, categorias e lançamentos | subcoleções de `users/{uid}` | `ownerId` | sim | sim | apagar | referências financeiras | início | lotes transacionais repetíveis | repositórios e Rules |
| Compromissos a pagar/receber e liquidações materializadas | `payables`, `receivables`, `transactions` | `ownerId` | sim | sim | apagar | contas/categorias/transações | antes da identidade | lotes transacionais | repositório de compromissos |
| Carteiras, ativos, operações e proventos | subcoleções de `users/{uid}` | `ownerId` | sim | sim | apagar | demanda de cotação derivada | antes da identidade | lote apaga ativo e demanda opaca | repositório de investimentos |
| Demanda de cotação derivada | `_marketQuoteDemands/{hash(uid,assetId)}` | referência pseudonimizada | sim, junto do ativo | sim, junto do ativo | apagar com a fonte | trigger recompõe catálogo global | no lote do ativo | delete repetível; trigger consulta estado atual | sync INV-2C-D |
| Cotações e notícias globais | coleções globais de mercado | nenhum | não | não | não aplicável | catálogo global | fora da operação | não aplicável | contratos BRAPI/Marketaux |
| Uso/custo da Luma | banco `assistant-controls-dev`, `assistantRuntime/ledger` | `ownerScope` SHA-256 | não | sim | apagar chaves owner-scoped; preservar agregados globais anônimos | ADC e banco nomeado | antes do perfil/Auth | transação remove `usage`, `records` e `periods` do owner | ledger do Assistente |
| Entitlement Premium | `users/{uid}/entitlements/premium` | `ownerId` | não | sim | apagar | Google Play não é cancelada | antes do perfil | delete repetível | ADR-027/Rules |
| Owner development | `system_admins/{uid}` | UID do caminho | não | sim | apagar | nenhuma | antes do perfil | delete repetível | repositório owner |
| Teste fechado | `_premiumClosedTestTesters/{uid}` e grants por `ownerId` | UID/`ownerId` | não | sim | apagar | entitlement | antes do perfil | documento + consulta owner-scoped | adapter Premium |
| Projeções Premium conceituais | `_premiumBillingEvents` e correlatas | não implantadas | não | não aplicável hoje | decisão futura antes de ativação | KMS/Play/runtime futuros | fora do manifesto atual | não aplicável | `PREMIUM_E_ASSINATURAS.md` |
| Recorrências do calendário | SharedPreferences `calendar_recurrences_v1_{uid}` | chave por UID | sim | sim | apagar após recibo | compromissos remotos | após confirmação server-side | `remove` repetível | repositório local |
| Seleção de agenda Android | SharedPreferences `android_calendar_selection_v1_{uid}` | chave por UID | não | sim | apagar | calendário do aparelho não é alterado | após recibo | `remove` repetível | repositório local |
| Personalização/apresentação da Luma | SharedPreferences por UID | chave por UID | não | sim | apagar | nenhuma | após recibo | `remove` repetível | repositórios locais da Luma |
| Tema do aparelho | `appearance.theme_mode` | dispositivo, não UID | não | não | preservar | nenhuma | fora da operação | não aplicável | ADR-027/STORAGE-1 |
| Cache Firestore e estado Riverpod | SDK/app | sessão local | invalidado pelos deletes/estado de Auth | inacessível após Auth; não se usa `clearPersistence()` | não é fonte canônica | listeners e Auth | depois do servidor | reconstruível | STORAGE-1 |
| Storage/anexos/dispositivos/notificações/auditLogs | futuros, não implementados | futuro | não aplicável hoje | não aplicável hoje | ADR-006/008, exige implementação futura | Storage/FCM | fora do manifesto atual | não aplicável | ausência no código/Rules |
| Recibo anônimo | `_privacyReceipts/{operationId opaco}` | nenhum campo owner | não | não | 30 dias, decisão aceita; TTL externo não configurado nesta fase | relógio do servidor | conclusão | create transacional e releitura idempotente | ADR-027 |

## Operações

- `financialReset` preserva Auth, perfil/consentimentos, preferências, uso da
  Luma, entitlement e owner. Remove somente dados financeiros, recorrências
  locais e demandas de cotação derivadas dos ativos removidos.
- `accountDeletion` inclui o reset, remove configurações e referências próprias,
  revoga sessões e apaga Auth por último. Não cancela assinatura Google Play.
- O cliente nunca escolhe UID, caminho, cursor ou lote. A preparação exige perfil
  jurídico e autenticação recente; uma operação de exclusão já destrutiva pode
  continuar sem o perfil somente quando o backend comprova a operação ativa do
  mesmo UID.

## Exportação

ADR-006 define CSV/Excel/PDF locais por relatório, mas não define um pacote de
portabilidade integral da conta, formato, versionamento ou conjunto de campos.
Portanto PRIV-1E-B não inventa uma exportação geral. Essa lacuna não altera o
fluxo de reset/exclusão e permanece como decisão de produto futura.
