# SUB-1A/SUB-1B/SUB-1C/SUB-1D/SUB-1E-1/SUB-1E-2/SUB-1E-3A — Entitlement Premium

## Fronteira atual

O SUB-1A criou tipos de domínio e contratos. O SUB-1B acrescentou uma referência de backend exclusivamente local, persistência transacional em memória para testes e mapper/repositório Flutter somente leitura; suas regras de leitura foram publicadas anteriormente apenas em development com SHA-256 `F01E52545F2CE88896A48B28B957BF45F8AE79B0173DF2E20449929FF21532B4`. O SUB-1C aplica localmente o entitlement aos investimentos em regras, repositório, controllers, rotas e interface. O SUB-1D preparou a experiência e o SUB-1E-1 remodela seu catálogo local para um produto único com planos-base. As regras SUB-1C e SUB-1E continuam não publicadas e nenhum usuário development real foi bloqueado por elas. Há somente três callables Premium de bootstrap em development, republicadas com Node 22; não há cobrança, loja real, entitlement real, paywall, produto criado no Play Console ou endpoint comercial habilitado.

O domínio vive em `lib/features/subscriptions/domain/` e não importa Flutter, Firebase, Riverpod, Google Play Billing nem biblioteca de pagamento. A referência local vive em `backend/subscriptions/`, usa ESM e APIs nativas do Node, sem dependências externas. Preços e moeda não fazem parte do modelo.

## Planos, fontes e ambiente

| Conceito | Valores atuais | Regra |
|---|---|---|
| plano | `free`, `monthly`, `annual` | mensal e anual têm as mesmas capabilities; não existe vitalício |
| fonte | `googlePlay`, `administrativeGrant`, `developmentGrant`, `closedTestGrant` | concessões nunca serão escritas pelo aplicativo |
| ambiente | `development`, `production` | grant de development é inválido em production |

Plano gratuito é representado pela ausência explícita de entitlement. Entitlements são Premium e possuem owner, fonte, ambiente, revisão e esquema. Uma concessão administrativa ou de development precisa de validade e será criada futuramente somente por backend auditável. Owner poderá receber concessão para o próprio UID, mas nunca acesso cruzado.

O SUB-1F-1 atualiza `closedTestGrant` somente para o teste fechado: validade individual de quinze dias, iniciada por relógio UTC confiável do servidor para cada UID autorizado em `development` e track `closed`, com as cinco capabilities Premium. Não é assinatura, compra, preço, oferta Play ou direito de production. O diretório `_premiumClosedTestTesters/{uid}` é privado, não contém e-mail e só é alterado por serviço administrativo server-side; a callable de ativação recebe payload vazio e só considera o próprio chamador autenticado, verificado, com App Check e perfil jurídico atual. O app não cria, restaura, reutiliza nem mede o prazo por relógio próprio; ao expirar, o backend remove as capabilities e a experiência segue o fluxo comercial normal sem popup modal. Production só aceitará entitlement verificado da Google Play depois do lançamento oficial.

## Entidade e invariantes

`PremiumEntitlement` contém plano, estado, fonte, ambiente, capabilities, início do entitlement, período atual, carência e eventos de cancelamento/expiração/revogação/reembolso, além da última verificação, revisão e versão de esquema.

- todos os instantes são UTC e chegam prontos ao domínio;
- `revision >= 1` e `schemaVersion == 1`;
- períodos são completos, crescentes e obrigatórios fora de `pending`;
- capabilities duplicadas, owner vazio, datas locais e campos de estado incompatíveis são rejeitados;
- `graceUntil` existe somente na carência e estende o período original;
- `cancelled` mantém o fim pago e exige cancelamento programado;
- expiração, revogação e reembolso exigem seus próprios instantes exclusivos;
- recibo, purchase token, cartão, payload Google, preço e credenciais não existem na entidade.

## Máquina de estados

| Estado | Acesso comercial | Observação |
|---|---|---|
| `pending` | negado | aguarda confirmação do servidor |
| `trialing` | integral até o fim exclusivo | teste confirmado |
| `active` | integral até o fim exclusivo | assinatura confirmada |
| `gracePeriod` | integral até `graceUntil` exclusivo | sinaliza carência e releitura |
| `accountHold` | negado | leitura histórica preservada |
| `paused` | negado | leitura histórica preservada |
| `cancelled` | integral até o fim pago exclusivo | cancelamento não expira imediatamente |
| `expired` | negado | leitura histórica preservada |
| `revoked` | negação imediata | terminal, mesmo com período futuro |
| `refunded` | negação imediata | terminal, mesmo com período futuro |

Transições aceitas incluem pendente para teste/ativa, ativa para cancelada/carência/hold/pausada, carência para ativa/hold, cancelada para expirada e renovação com período novo. Revogação é possível a partir de qualquer estado não terminal; reembolso somente em estados aplicáveis. Eventos com revisão antiga ou repetida, verificação regressiva, owner ou origem divergente (ambiente, projeto ou pacote), troca de fonte dentro do mesmo ciclo ou período reduzido são negados deterministicamente.

Uma nova assinatura depois de `expired` precisa começar no ou depois do instante de expiração. `revoked` e `refunded` não são restaurados; um novo ciclo deverá ser representado por novo estado autoritativo do backend.

## Capabilities e modo somente leitura

As capabilities iniciais são:

- `investmentsManual`;
- `investmentIncome`;
- `investmentQuotes`;
- `investmentCalculators`;
- `investmentAnalysis`.

A solicitação também informa a intenção `read`, `mutate` ou `consumeService`. Isso evita transformar leitura histórica em permissão de edição. Carteiras, ativos, operações e proventos são dados preserváveis: após perda de acesso, leitura recebe `readOnly`, enquanto criação, edição, operações e proventos são negados. Cotações, calculadoras e análises não são dados históricos preservados; cotações deixam de ser fornecidas para evitar custo recorrente.

No SUB-1C, `investmentsManual` e `investmentIncome` são aplicadas separadamente em profundidade. As demais capabilities apenas reservam significado estável e não habilitam funcionalidade.

## Decisão de acesso

`PremiumEntitlementPolicy` recebe o ambiente esperado e decide usando:

1. entitlement presente ou ausente;
2. capability solicitada;
3. intenção de leitura, mutação ou consumo;
4. instante UTC confiável injetado.

O resultado informa modo, motivo estável, capability, intenção, validade, carência, cancelamento pendente e necessidade de nova verificação. O domínio nunca chama `DateTime.now()`. Uma janela máxima de verificação pode ser injetada pela futura aplicação; o SUB-1A não fixa prazo comercial.

A decisão cliente serve à experiência e falha de maneira explicável. Ela não substitui backend, validação da compra nem Security Rules.

## Backend local e contrato de leitura

`PremiumEntitlementRepository` oferece somente leitura atual, observação de snapshots confirmados, releitura do servidor e diagnóstico sanitizado. A implementação Firebase lê com `Source.server`, ignora snapshots de cache ou com escrita pendente e usa mapper de campos exatos. Entitlement ausente é resultado explícito. Não existem métodos cliente para criar, ativar, renovar, revogar, reembolsar ou conceder.

O contrato local usa o documento fixo `users/{uid}/entitlements/premium`, escrito exclusivamente pelo backend futuro. A leitura do entitlement permite apenas `get` próprio com autenticação, e-mail confirmado e perfil jurídico válido; listagem e toda escrita cliente são negadas. Localmente, as coleções de investimentos também exigem entitlement, capability e estado temporal coerentes. Token, recibo bruto, identidade de pagamento e auditoria confidencial ficam fora do documento legível.

O processador local recebe ator autenticado e token transitório; ambiente, package Android e catálogo são configuração fechada do processador, nunca campos confiados ao cliente. Ele calcula uma impressão digital HMAC, consulta um gateway fake, valida o DTO, reconcilia em armazenamento transacional e devolve somente confirmação sanitizada que exige releitura do servidor. App Check é um pré-requisito futuro de borda. Eventos repetidos, concorrentes, antigos e timeouts pós-commit são idempotentes. RTDN é apenas sinal e nunca autoridade. A outbox de acknowledgement é repetível sem confirmação duplicada.

As coleções conceituais `_premiumBillingEvents`, `_premiumPurchaseBindings`, `_premiumRtdnInbox`, `_premiumAcknowledgementOutbox` e `_premiumAdministrativeGrants` são integralmente negadas ao cliente. Não existem em Firebase real nesta etapa. A referência de cofre em memória e a chave sintética servem somente aos testes; produção exigirá KMS/Secret Manager, retenção e runtime aprovados.

## Preservação e experiência

Perder Premium nunca apaga carteira, ativos, operações ou proventos, nunca recalcula preço médio e nunca modifica conta, saldo ou resumo mensal. A renovação recupera mutações sem migração dos dados históricos. O SUB-1C apresenta o estado, mantém leitura e oculta ações mutáveis; ausência não carrega listas e falha de confirmação oferece retry sem sucesso falso. Compra, preço, restauração comercial e ação de renovação pertencem ao SUB-1D/SUB-1E-1.

## Enforcement local SUB-1C

O coordenador relê o entitlement do servidor e produz estados explícitos. Cache e escrita pendente não autorizam. Um decorator protege o repositório e os controllers verificam acesso antes e depois de cada operação, preservando IDs e descartando respostas tardias. Gates protegem inclusive deep links para formulários e detalhes. A interface somente leitura preserva seleção, filtros, privacidade, tema e navegação, mas não apresenta criar, editar, arquivar, restaurar, comprar, vender, anular ou alterar provento.

As regras SUB-1C permanecem somente locais. A publicação depende de um mecanismo backend/administrativo autorizado para criar entitlements development com validade e auditoria; publicá-las antes disso bloquearia usuários development reais. O detalhamento está no ADR-021 e na matriz `docs/security/PREMIUM_ENFORCEMENT_MATRIX.md`.

O adaptador local de Google Play Billing foi preparado no SUB-1D; a integração comercial real exige um gate posterior com produtos, backend, verificação, regras e autorizações externas. A integração B3/corretoras permanece cancelada. Cotação atrasada por provedor independente permanece bloqueada por licenciamento e pela implementação segura de SUB-1.

## SUB-1D/SUB-1E-1 — experiência e catálogo Google Play preparados localmente

O SUB-1D adiciona contratos distintos para catálogo, compra, restauração, atualizações do ciclo, verificação, disponibilidade e gerenciamento. O SUB-1E-1 substitui o modelo local anterior de dois produtos pelo produto único `meu_gestor_premium`, com plano-base `mensal`, plano-base `anual` e a oferta `teste-3d` exclusiva do mensal. `in_app_purchase` 3.3.0 é o adaptador Flutter oficial adequado, e `in_app_purchase_android` 0.5.0 é declarado diretamente para selecionar o `basePlanId` e o `offerToken` retornados pela Play; ambos são mantidos pelo Flutter, já estavam resolvidos localmente e não exigem dependência Gradle manual. O projeto atual já atende seu mínimo Android (o adaptador Android resolve `minSdk 21`). `url_launcher` 6.3.2 abre a URI pública oficial de assinaturas, com deep link específico somente quando package e produto configurados passam na validação; caso contrário usa a Central geral.

O Brasil é o país comercial inicial. R$ 19,90 mensal e R$ 209,90 anual são preços aprovados para configuração futura no Play Console, não valores confiáveis ou persistidos pelo aplicativo. O cliente consulta somente o produto único; plano-base, oferta elegível, título, descrição, preço localizado e moeda vêm da resposta atual da Play Store. Sem catálogo real, backend verificador e App Check preparado, a página informa **Assinaturas em preparação**, não consulta a loja e não permite iniciar cobrança.

Em uma ativação futura, a sequência obrigatória será: catálogo da Play, confirmação explícita do usuário, atualização `pending`/`purchased`/`restored`, verificação de servidor, releitura `Source.server` do entitlement, e só então acknowledgement por backend/outbox. O Flutter não faz acknowledgement nem retém o token após encaminhar a evidência transitória ao verificador. `pending`, cancelamento, falha, timeout, backend indisponível, resposta tardia ou entitlement ausente nunca liberam capability. O token é transitório, não é persistido pelo Flutter e não compõe logs, Riverpod ou diagnósticos. O `obfuscatedAccountId` será emitido por mecanismo não reversível aprovado no backend, específico por ambiente; UID puro não será enviado.

Restauração encaminha cada compra relevante ao verificador e relê o servidor; ausência, assinatura expirada, conta Google diferente e erro não criam entitlement. A página mantém acesso oficial para gerenciamento/cancelamento na Google Play e não simula cancelamento no aplicativo. A tela negada e o modo somente leitura oferecem a página Premium sem carregar listas protegidas nem alterar o enforcement SUB-1C.

O backend futuro verificará o produto, plano-base e oferta por Google Play Developer API; RTDN continuará apenas um sinal que aciona reconciliação autoritativa. Nesta etapa há somente abstrações, fakes e fixtures sintéticas. Testes reais exigirão produtos configurados, backend, regras publicadas e license testers da Play Console. License testers permitem testar fluxo com métodos de teste, inclusive compras pendentes; acknowledgement só pode ocorrer depois de `PURCHASED`. Nada disso foi configurado ou acessado neste checkpoint.

## SUB-1E-3A — borda Functions Gen 2 local

`backend/functions/premium` prepara factories compatíveis com Functions Gen 2 e, no bootstrap development, compõe três callables com os SDKs oficiais Admin e Functions. Os handlers estritos reutilizam o processador, mapper, transições, outbox e RTDN de `backend/subscriptions`; identificadores específicos de ambiente, inclusive identidade runtime, são parâmetros de deploy e não código versionado. Verificação e restauração permanecem indisponíveis para o Flutter: as callables publicadas falham fechadas e a borda local continua coberta por fakes.

As callables futuras são verificação, restauração, leitura de entitlement confirmado e ativação do teste fechado. Todas exigirão App Check individualmente, sem enforcement global. RTDN e autorização administrativa da lista são caminhos distintos: RTDN precisa de perímetro autenticado e reconsulta a fonte autoritativa; a lista exige identidade administrativa server-side. A ativação só trata o próprio UID validado e nunca recebe prazo, capability, track ou UID alvo. O aplicativo, owner e qualquer UID não obtêm escrita direta de entitlement, grant ou diretório.

O adapter transacional Firestore é injetável e a composição development usa Admin SDK apenas para a leitura confirmada do entitlement próprio. O codebase Premium foi republicado com Node 22, mantém `firebase-admin` 14.2.0 e `firebase-functions` 7.3.2 e declara `@google-cloud/firestore` 8.7.1 diretamente; a instalação de produção omite dependências opcionais, portanto não carrega Cloud Storage ou o `uuid` transitivo. Uma verificação estrutural bloqueia importações desses caminhos, e a árvore efetivamente instalada sem opcionais passou na auditoria sem vulnerabilidades; o lockfile completo é apenas informativo. A futura implementação usará transação para entitlement, evento, binding e outbox, com identidade de runtime de menor privilégio por ambiente. Segredos serão obtidos no runtime autorizado, sem chave JSON no repositório; Play Developer API, Pub/Sub/RTDN, Secret Manager e IAM adicional permanecem dependências externas não configuradas. Rollback não apaga dados: desativa novas rotas ou retorna o código anterior, preservando eventos e outbox idempotentes. A limpeza do Artifact Registry development retém artefatos de deploy por 14 dias na região das Functions, sem exclusões manuais. As regras SUB-1E continuam exclusivamente locais e não foram publicadas.

Investimentos manuais e proventos permanecem Premium, enquanto o núcleo financeiro continua gratuito. A integração B3 e integrações com corretoras seguem canceladas; cotação atrasada por provedor independente não é implementada nem preparada por este incremento. A margem líquida não pode ser inferida do preço: dependerá de taxa Play, impostos, reembolsos e custos Cloud reais.
