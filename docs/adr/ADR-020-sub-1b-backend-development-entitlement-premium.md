# ADR-020 — SUB-1B backend development do entitlement Premium

## Status

Aceita em 10/08/2026. A implementação e o backend de referência permanecem locais; somente as Security Rules foram posteriormente compiladas e publicadas no Firebase development, sem acesso a production, com SHA-256 `F01E52545F2CE88896A48B28B957BF45F8AE79B0173DF2E20449929FF21532B4`. Nenhum backend real, recurso Google Play, documento ou entitlement foi criado. Commit e push permanecem pendentes.

## Contexto

O domínio SUB-1A precisa receber uma projeção autoritativa sem confiar no aplicativo, no relógio do aparelho ou em um purchase token apresentado pelo cliente. Eventos de loja podem repetir, chegar fora de ordem ou sofrer timeout antes/depois de uma gravação. Tokens, payloads e auditoria operacional não podem ficar legíveis pelo aplicativo.

## Decisão

- manter um backend isolado em ESM compatível com Node 20+, sem dependências externas e sem endpoint;
- representar Google Play por gateway, DTO estrito e fake determinístico; não implementar HTTP, autenticação Google, Pub/Sub ou RTDN real;
- tratar o token somente de forma transitória, persistindo impressão digital HMAC versionada e referência abstrata de cofre; a implementação recuperável em memória existe apenas para testes sintéticos e deverá ser substituída por KMS/Secret Manager;
- validar pacote, produto permitido, ambiente, estado, período, conta ofuscada, confirmação, token vinculado e campos exatos antes do mapeamento canônico;
- vincular uma compra a apenas um UID, ambiente, pacote e produto; identidade futura exige ID token, App Check e identificador de conta ofuscado derivado irreversivelmente do UID;
- reconciliar eventos em transação, com revisão crescente, evento antigo sem regressão, repetição idempotente e recuperação após timeout pós-commit;
- gravar conceitualmente eventos sanitizados, vínculos, inbox RTDN, outbox de acknowledgement e grants em coleções internas inacessíveis ao cliente;
- aceitar RTDN apenas como sinal: o processador sempre consulta novamente o gateway autoritativo;
- limitar grants administrativos/development ao próprio UID, ambiente, validade, capabilities, motivo e auditoria; grants development falham em production;
- projetar o entitlement em `users/{uid}/entitlements/premium`, com escrita exclusiva do backend futuro;
- permitir ao cliente somente `get` do próprio documento confirmado pelo servidor. Listagem e toda escrita são negadas;
- manter investimentos acessíveis no development atual. Aplicação de Premium, paywall e experiência de compra pertencem ao SUB-1C ou posterior.

## Consequências

Os contratos locais demonstram a reconciliação segura sem ativar custo, rede ou serviço externo. O aplicativo passa a ter mapper estrito e repositório somente leitura, mas nenhum fluxo atual consome esses providers. Ausência do documento continua significando plano gratuito, sem esconder ou apagar dados.

Antes de uso real serão obrigatórios um runtime backend aprovado, autenticação server-side, Secret Manager/KMS, credenciais de privilégio mínimo, produtos allowlisted, API oficial, App Check, monitoramento sanitizado, limites, política de retenção, custos e deploy específico. Nenhum desses itens foi antecipado pelo SUB-1B.
