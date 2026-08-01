# Acesso proprietário

## Objetivo

O acesso proprietário é uma autorização interna, exclusiva do ambiente `development`, que libera funcionalidades do produto sem ampliar acesso a dados, regras ou segredos. A identidade administrativa nunca é compilada no aplicativo: ela deriva exclusivamente da leitura pontual e confirmada pelo servidor de `system_admins/{uid}`, usando o UID da sessão Firebase Authentication.

## Modelo administrativo

O documento possui exatamente cinco campos:

| Campo | Tipo | Valor aceito |
|---|---|---|
| `role` | string | `owner` |
| `active` | boolean | `true` ou `false` |
| `environment` | string | `development` |
| `grantedAt` | timestamp | timestamp válido |
| `schemaVersion` | number inteiro | `1` |

O UID existe somente como ID do documento e não é duplicado nos campos.

## Fluxo

1. Authentication fornece o usuário atual em tempo de execução.
2. O ProfileGate confirma e-mail, perfil e versões jurídicas.
3. `MasterAccessController` consulta somente o próprio documento com `Source.server` e timeout de 12 segundos.
4. `FirestoreMasterAccessMapper` exige campos exatos, tipos e valores compatíveis.
5. `AccessContext` deriva capabilities somente quando o resultado é `activeOwner` confirmado pelo servidor.
6. `MasterAccessGate` impede apresentação parcial da área protegida.
7. Logout, troca de usuário, retorno ao aplicativo e “Atualizar acesso” invalidam ou revalidam a decisão.

Documento inexistente produz `regularUser`. Cache, escrita pendente, timeout, documento inválido ou erro não concedem capabilities. Erros administrativos não bloqueiam os módulos normais do próprio usuário.

## Capabilities centralizadas

- `accessOwnerArea`
- `viewDevelopmentDiagnostics`
- `accessExperimentalFeatures`
- `accessAllImplementedModules`
- `bypassSubscriptionGates`
- `accessAllPaidFeatures`
- `accessAllAiFeatures`
- `bypassCommercialUsageLimits`
- `manageDevelopmentPreferences`

O papel `owner` recebe todas as capabilities registradas. Usuários comuns recebem o contexto regular, sem capabilities administrativas. Identificadores desconhecidos são negados.

As capabilities comerciais preparam o owner para ignorar futuramente assinatura, plano, funcionalidades pagas, funcionalidades de IA e limites comerciais destinados a usuários comuns. Elas não implementam cobrança, assinatura, pagamentos, loja, Google Play Billing, Stripe, Mercado Pago, limites comerciais reais ou consumo real de IA.

## Limites que nunca são ignorados

- Security Rules do Firestore;
- isolamento por UID;
- autenticação e confirmação de e-mail;
- integridade e validações financeiras;
- cancelamento irreversível;
- controles de concorrência;
- proteção contra dados de terceiros;
- limites técnicos contra loops, falhas e consumo acidental excessivo de APIs.

## Camadas

- Domínio: `AppRole`, `AppCapability`, `AccessContext`, `MasterAccess`, falhas e contrato de repositório, sem Flutter, Riverpod ou Firebase.
- Dados: mapper estrito, repositório Firestore somente leitura e diagnóstico sanitizado.
- Apresentação: controller Riverpod, estados fechados, portão, observador de ciclo de vida, selo e Área do proprietário.
- Rotas: `/proprietario`, condicionada ao estado já controlado; o redirect não faz leitura Firestore.

## Privacidade e observabilidade

A interface e os logs não mostram UID, e-mail, conteúdo do documento, project ID, client ID, token, saldos ou dados de terceiros. Em development, o diagnóstico contém apenas operação, etapa, duração, código Firestore, tipo de exceção e estado final.
