# ADR-025 — SUB-1E-3A: borda Premium para Cloud Functions Gen 2

**Status:** bootstrap publicado exclusivamente em development no SUB-1E-3B-1 e republicado com Node 22; RTDN, compra, restauração real, grants, Secret Manager e demais integrações continuam indisponíveis.

## Decisão

O núcleo de negócio de Premium permanece em `backend/subscriptions`. A borda em `backend/functions/premium` continua testável por factories e dependências injetadas; no bootstrap development, a composição real usa os SDKs oficiais Admin e Functions Gen 2, sem credencial versionada ou integração comercial habilitada.

Os contratos preparados são: verificação futura de compra, restauração futura, leitura do entitlement confirmado, RTDN como sinal seguido de releitura autoritativa, administração de `closedTestGrant` e materialização de sua expiração. Apenas os três callables novos solicitam App Check; não existe enforcement global nem endpoint exposto ao aplicativo para administrar grants.

## Segurança e operação futuras

- Cada Function Gen 2 usa identidade de runtime dedicada, mínima e separada por ambiente. O identificador da conta é parâmetro de deploy por ambiente, não código versionado. Leitura/escrita transacional de Firestore, consulta Play e consumo RTDN serão concedidos somente às funções que precisarem deles.
- O adapter de armazenamento recebe `runTransaction`, leitura e escrita injetadas; a integração futura com Admin SDK não poderá duplicar regras do processador nem expor metadados internos no documento público.
- Nenhuma chave JSON será criada. Credenciais transitórias, chaves HMAC e qualquer segredo futuro serão obtidos no runtime por Secret Manager/identidade de serviço autorizados, com rotação e sem logs.
- RTDN será aceito somente por perímetro autenticado, deduplicado por mensagem e sempre reconsultará a API autoritativa. A mensagem não concede entitlement por si só.
- Antes de implantar callables, App Check/Play Integrity precisa estar configurado e observado em development. O enforcement será limitado às novas rotas Premium; não será aplicado globalmente.
- Rollback futuro interrompe novas invocações ou retorna a versão anterior sem apagar entitlement, binding, evento, outbox ou auditoria. Reprocessamento da outbox permanece idempotente.

No SUB-1E-3B-1, apenas as três callables Premium foram publicadas em `southamerica-east1`, com uma identidade runtime dedicada e limites conservadores. A leitura exige autenticação, token com e-mail verificado, App Check e perfil jurídico atual; compra/restauração falham fechadas e não escrevem dados. Nenhuma regra, dado Firestore, Auth, App Check global, produto Play ou production foi alterado. A política de limpeza do Artifact Registry foi configurada separadamente para reter somente artefatos de deploy de até 14 dias na região das Functions, sem exclusões manuais.

`closedTestGrant` continua development/track fechado/15 dias apenas. Não é assinatura, compra, preço, oferta Play ou direito de production; production exige entitlement verificado da Google Play.

## Compatibilidade de runtime e superfície de dependências

O codebase Premium usa Node 22. Mantém `firebase-admin` 14.2.0 e `firebase-functions` 7.3.2, com `@google-cloud/firestore` 8.7.1 declarado diretamente porque a leitura Admin é necessária. A instalação de produção omite dependências opcionais: não instala Cloud Storage nem `uuid` transitivo, e um teste estrutural impede importações do runtime por esses caminhos. A árvore de produção instalada sem opcionais passou na auditoria sem vulnerabilidades; o lockfile continua registrando a resolução opcional completa apenas como informação de reprodutibilidade. A revisão Node 22 foi publicada somente no codebase Premium development. As regras SUB-1E continuam locais e não foram publicadas.
