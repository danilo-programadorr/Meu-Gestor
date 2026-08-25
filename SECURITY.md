# Política de segurança

## DATA-1A/PRIV-1A — Reset financeiro e exclusão de conta locais

- O aplicativo não possui exclusão direta de documentos ou Firebase Authentication. As Security Rules continuam negando exclusões. O backend ESM local modela a execução server-side idempotente, com lock de novas escritas, lote conservador e cursor persistido; ele não acessa Firebase Admin nem dados reais.
- Reset financeiro preservará Authentication, perfil, consentimentos, aparência, entitlement/assinatura Premium e owner; removerá somente o manifesto financeiro fechado. Exclusão de conta removerá também perfil, entitlement, referências Premium, diretório/grant de teste fechado e `system_admins/{uid}`, antes da exclusão final do Auth.
- A autorização futura exigirá UID próprio autenticado, App Check, e-mail confirmado, perfil jurídico, frase exata e `auth_time` validado pelo servidor em até cinco minutos. Owner não obtém acesso cruzado e o cliente não informa UID, relógio, cursor ou caminho a apagar.
- A experiência local exige reautenticação por senha ou Google, força token novo e permanece falha-fechada enquanto não existe Function. As Rules locais negam cliente em `privacyOperations`, `privacyLocks` e `privacyReceipts`; lock financeiro nega mutações financeiras e lock de exclusão nega toda mutação do perfil/financeira. Nenhuma dessas Rules foi publicada.
- PRIV-1E-A adiciona apenas a borda local Node 22 das três callables de privacidade. Ela exige Auth, e-mail verificado, App Check, perfil jurídico e UID próprio; `prepare` e `confirm` validam `auth_time` de até cinco minutos no relógio do servidor. A frase de confirmação é comparada e descartada, jamais registrada. A conta runtime é parâmetro não versionado; não há deploy, credencial, Function ativa, Firestore Admin conectado, deleção real ou bypass owner.
- Não há cancelamento de assinatura Google Play. A futura experiência avisará isso e oferecerá o gerenciamento oficial. Após conclusão ficará somente recibo anônimo (ID aleatório, tipo, resultado e instante), planejado para 30 dias; sem UID, e-mail, dados financeiros, cópia permanente ou retenção antifraude antes de cobrança real. Backups continuam bloqueio de auditoria antes de produção.

## SUB-1D/SUB-1E-1 — Google Play Billing local

- Resposta local de compra, debug, owner, e-mail, UID ou `dart-define` nunca concede Premium.
- Tokens são transitórios; não entram em domínio, Firestore legível, Riverpod persistente, diagnóstico ou log. `pending` não libera nem pode ser acknowledged.
- O futuro backend verificará compra e emitirá a identidade ofuscada não reversível antes de acknowledgement/outbox; UID puro não será enviado à Play.
- O gerenciador abre somente a URI HTTPS oficial da Google Play. Não existe cancelamento simulado, endpoint, comando operacional, Firebase real, deploy ou acesso production nesta etapa.
- Auditoria local de grant contém apenas ação, origem, ambiente, plano, contagem de capabilities, revisão e instante; não contém actor, owner, motivo, grant ID, token ou credencial.
- O catálogo local aceita somente `meu_gestor_premium`, planos-base `mensal`/`anual` e oferta `teste-3d` exclusivamente mensal. Preço aprovado, preço de teste, status ou resposta de loja recebidos pelo cliente, relógio do aparelho, cache ou resposta tardia não são autoridade de acesso; a confirmação futura exige verificação server-side independente.
- O preço exibido, a moeda, a elegibilidade e a oferta devem vir da resposta atual da Play Store. R$ 19,90 e R$ 209,90 são apenas parâmetros comerciais da futura configuração Play Brasil; não pertencem a entitlement, Firestore ou decisão local.
- Perda de conexão, restauração sem confirmação, cancelamento, pendência ou falha do verificador permanecem negados até releitura do entitlement canônico. Google Play Developer API e RTDN continuarão atrás de backend autorizado; nesta etapa só existem contratos/fakes sintéticos.

## SUB-1E-2 — Teste fechado local

- `closedTestGrant` não é assinatura, compra, preço, oferta Play nem direito de production. É uma concessão backend-only para o teste fechado em `development`, track `closed` e validade individual de quinze dias calculada pelo servidor.
- A borda de ativação exige que o ambiente runtime seja declarado explicitamente como `development`; ausência, valor divergente ou `production` falham fechados antes de qualquer leitura ou escrita.
- A borda de ativação exige que o ambiente runtime seja declarado explicitamente como `development`; ausência, valor divergente ou `production` falham fechados antes de qualquer leitura ou escrita.
- A lista privada não armazena e-mail e só pode ser autorizada/revogada por serviço administrativo futuro. A callable de ativação aceita payload vazio do próprio usuário autenticado, com e-mail verificado, App Check e perfil jurídico atual; o app não possui escrita, restauração ou reutilização, e owner continua sem acesso cruzado.
- A concessão ativa tem exatamente as cinco capabilities Premium; a expiração é materializada por relógio confiável do backend e remove capabilities. Não há cálculo pelo relógio do aparelho, primeiro login, popup modal de expiração ou alteração do núcleo gratuito.
- Regras locais mantêm escrita cliente negada e rejeitam a fonte fora da forma ativa/expirada prevista. Production não aceitará essa fonte; entitlement verificado da Google Play será obrigatório depois do lançamento.
- `_premiumClosedTestTesters` e `_premiumClosedTestGrants` são explicitamente negadas nas Rules locais para get, list e todas as escritas. A lista e a auditoria não podem ser usadas pelo aplicativo para enumerar testadores ou obter dados de outro UID.

## SUB-1E-3A — Borda Premium Gen 2 local

- A estrutura em `backend/functions/premium` é uma composição local por injeção, sem SDK Firebase, credential, chamada HTTP, Function publicada ou acesso externo. Ela reutiliza o núcleo transacional único e não replica decisão financeira/comercial.
- Verificação, restauração e leitura confirmada serão callables novas com App Check individual; RTDN e administração de teste fechado não são chamadas do aplicativo e exigem perímetro/identidade server-side futuros. Nenhum bypass owner é aceito.
- IAM futuro será mínimo e separado por função/ambiente. Segredos, caso necessários, permanecem em Secret Manager/runtime autorizado e nunca em `.env`, JSON, logs, diagnóstico ou Git.
- Rollback futuro não exclui entitlement, eventos, vínculos, outbox ou auditoria; a resposta a timeout, repetição e concorrência continua idempotente e falha fechada.

## SUB-1E-3B-1 — Bootstrap Premium em development

- Somente três callables Gen 2 Premium foram publicadas e republicadas com Node 22 em development, com região fixa sul-americana, identidade runtime dedicada e limites mínimos. App Check é exigido apenas nessas callables; não houve enforcement global.
- Leitura exige UID do token autenticado, e-mail confirmado pelo token e perfil jurídico atual. O documento retornado é sanitizado e deve pertencer ao próprio UID.
- Verificação e restauração de compra retornam falha fechada e não aceitam token, não escrevem Firestore e não concedem Premium. RTDN, grants, Secret Manager e Play Developer API não foram publicados.
- Regras SUB-1E, Authentication, dados Firestore, App Check global e production não foram alterados. A limpeza automática do Artifact Registry foi configurada separadamente para reter somente artefatos de deploy de até 14 dias na região das Functions, sem remoção manual de imagens, revisões ou Functions.
- A configuração local de entrega das Functions Premium usa Node 22 e omite dependências opcionais. Firestore permanece dependência direta necessária; Cloud Storage, `uuid`, `gaxios`, `teeny-request` e `retry-request` não podem ser importados pelo runtime Premium e a árvore efetiva de produção auditada sem opcionais não possui vulnerabilidades. O lockfile com opcionais não é prova de conteúdo publicado.

## INV-2C — Cotações atrasadas globais locais

- `marketQuoteSnapshots` não contém dados de usuário. As Rules locais permitem somente `get` de um ticker conhecido para usuário autenticado, e-mail confirmado, perfil jurídico atual e capability `investmentQuotes` com Premium integral vigente; `list`, toda escrita, subcoleções e owner cruzado são negados.
- `_marketQuoteLeases`, `_marketQuoteRefreshRequests` e `_marketQuoteCircuitBreakers` são internos e negados integralmente ao cliente. Não persistem UID, carteira, posição, preço médio, token do provedor ou resposta bruta.
- A borda Gen 2 futura usa segredo de Scheduler e token de provedor exclusivamente por parâmetro Secret Manager. Sem ambos, ela responde indisponível antes de chamar gateway ou alterar Firestore. Segredo, URL autenticada, payload bruto e valor de cotação não entram nos logs; a observabilidade registra somente evento, requestId sanitizado, contagem e código seguro.
- Nenhuma Rule ou Function foi publicada nesta etapa. BRAPI é adaptador local provider-neutral, não contrato comercial aprovado, e B3/corretoras permanecem canceladas como integração.

## Versões suportadas

O projeto está em desenvolvimento e ainda não possui versão de produção. Somente o código mais recente da branch `main` recebe correções de segurança neste momento.

## Como reportar uma vulnerabilidade

Use a opção privada **Report a vulnerability** na aba **Security** do repositório. Não abra issue pública contendo vulnerabilidade explorável, credencial, token, configuração Firebase, dado pessoal ou informação financeira.

Se o canal privado não estiver disponível, abra uma issue sem detalhes técnicos solicitando que um mantenedor disponibilize um canal privado. Não anexe evidências sensíveis à issue.

Inclua no relato privado, quando possível:

- componente e versão afetados;
- impacto observado;
- passos mínimos para reprodução sem dados reais;
- mitigação sugerida;
- confirmação de que nenhuma credencial real foi publicada.

Os mantenedores farão triagem e responderão conforme disponibilidade e gravidade, sem promessa de prazo incompatível com a natureza voluntária do projeto. A correção será publicada depois de reduzir o risco de exploração e revisar possíveis impactos.

## Escopo de dados

Nunca envie senhas, tokens, chaves privadas, contas de serviço, arquivos `google-services.json`, dados financeiros reais ou informações pessoais em um relatório. Se uma credencial tiver sido exposta, revogue-a e faça a rotação no provedor correspondente.

## Dados financeiros implementados

Perfil, contas, categorias, lançamentos, compromissos, investimentos e proventos manuais usam caminhos subordinados ao UID. Acesso financeiro exige email verificado e perfil jurídico atual. Documentos financeiros usam campos fechados, timestamps do servidor e exclusão negada. Operações de investimento não afetam o saldo, são encadeadas, imutáveis e alteram a projeção do ativo somente em mutação atômica. Proventos usam coleção própria, referências ativas, revisão e transições terminais; não criam lançamento nem alteram conta, posição ou resumo mensal. Logs locais de diagnóstico registram somente operação, etapa, duração, categoria técnica, tipo/código sanitizado e estado final; nunca registram valores, descrições, notas, IDs de documentos, email ou tokens.

As regras são validadas localmente no Emulator Suite com projeto `demo-*`. Perfil, núcleo financeiro, compromissos, investimentos, proventos e owner foram publicados somente no projeto development mediante autorizações específicas. As regras do INV-PROV-1 foram compiladas e publicadas com sucesso exclusivamente em development, sem acesso a production, com SHA-256 `8B689BA72FE05B1C04409E00083644D83B2EEACFDDA67A7C8D003B843E102FBE`; o APK debug development foi gerado e aprovado manualmente, enquanto commit e push permaneciam pendentes nesta atualização. Não flexibilize regras para contornar erros de configuração ou publicação.

## Acesso proprietário

O papel `owner` é concedido somente por um documento administrativo criado manualmente em `system_admins/{uid}`. O aplicativo usa o UID da sessão, lê somente o próprio documento diretamente do servidor e não possui API para criar, editar, excluir ou listar administradores.

E-mail, senha, UID hardcoded, parâmetro de rota, preferência ou armazenamento local nunca autorizam owner. O documento é válido somente em development e a decisão falha fechada diante de cache, timeout, erro ou incompatibilidade.

Capabilities owner liberam funcionalidades do produto e futuros recursos comerciais, mas não ignoram Security Rules, isolamento por UID, autenticação, validações financeiras, concorrência, integridade ou limites técnicos contra abuso. Diagnósticos omitem identidade, conteúdo administrativo, tokens, project ID e dados financeiros.

## Assistente Financeiro Pessoal — ASSIST-0

O contrato local exige Auth, App Check, e-mail verificado, perfil jurídico atual, UID próprio e consentimento IA vigente confirmado pelo servidor. Owner não contorna nenhuma dessas condições. O cliente envia somente a pergunta; UID e contexto são derivados server-side.

O provedor futuro receberá somente fatos tipados e minimizados com aliases efêmeros. UID, e-mail, nome pessoal, IDs persistidos, tokens, segredos, entitlement, grants, owner, locks e operações de privacidade são proibidos. Perguntas com indício de segredo ou dado pessoal de terceiro falham antes do provedor. Toda afirmação factual deve citar evidência do contexto, e fontes inexistentes são declaradas ausentes.

ASSIST-0 não possui API de IA, segredo, memória persistente ou executor. Uma saída pode explicar e propor uma prévia, mas nunca altera dados. Mutações futuras exigirão confirmação explícita e revalidação pelo domínio; reset, exclusão de conta, Auth, owner e entitlement permanecem sempre fora do assistente.

## Entitlement Premium — SUB-1A/SUB-1B/SUB-1C

O backend de referência SUB-1B permanece exclusivamente local, sem rede, com armazenamento em memória para testes e mapper/repositório Flutter somente leitura. Suas Security Rules foram publicadas anteriormente somente em development, com SHA-256 `F01E52545F2CE88896A48B28B957BF45F8AE79B0173DF2E20449929FF21532B4`. O SUB-1C aplica enforcement apenas no código e nas regras locais; não houve nova publicação, Firebase real ou bloqueio de usuário development. Não existe entitlement real, backend implantado, produto de loja, compra ou paywall.

O modelo legível não contém purchase token, recibo completo, payload Google, dados de cartão, preço, credencial ou identificador externo usado como autorização. O backend local usa token apenas transitoriamente, impressão digital HMAC versionada e referência abstrata de cofre; chaves sintéticas e cofre em memória são restritos aos testes. Runtime real exigirá KMS/Secret Manager e credenciais mínimas.

Concessões administrativas e de development têm contrato local de validade, motivo, auditoria, capabilities, ambiente e revogação. São backend-only, limitadas ao próprio UID e development nunca atua em production. Owner não obtém acesso cruzado. A decisão local é projeção de experiência e nunca substitui autorização de backend e Security Rules.

As regras SUB-1C locais aplicam entitlement às quatro coleções de investimentos. Leituras exigem documento integralmente válido, UID próprio, perfil jurídico e capability; mutações exigem acesso integral por `request.time`. Listagem/escrita de entitlements, subcoleções, billing interno e owner cruzado continuam negados. Repositório, controller e rotas reforçam a decisão, mas não substituem as regras.

Após perda de Premium, dados patrimoniais não são apagados nem alterados: leitura histórica é preservada, mutações são bloqueadas e cotações deixam de ser fornecidas. Esse comportamento está conectado localmente aos repositórios, controllers, rotas e interface. Publicar as regras exige antes concessão development segura e auditável; Google Play e experiência comercial pertencem ao SUB-1D/SUB-1E-1. A integração B3/corretoras permanece cancelada.
