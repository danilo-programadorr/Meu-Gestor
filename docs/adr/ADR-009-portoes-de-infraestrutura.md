# ADR-009 — Portões de infraestrutura

- Status: aceito
- Data: 22/07/2026

## Contexto

Projeto Flutter, Firebase, Storage, backup e Blaze produzem identificadores, recursos externos e custos.

## Decisão

- O identificador Android definitivo é `br.com.hellenfaro.meugestorfinanceiro`.
- O nome interno Flutter é `meu_gestor_financeiro` e o nome exibido é Meu Gestor Financeiro.
- A fundação local da Etapa 2 está autorizada, limitada ao projeto Android, estrutura modular, dependências fundamentais, configurações locais e testes definidos.
- Não instalar Firebase CLI ou FlutterFire CLI nesta etapa.
- Não configurar Firebase nem ativar Storage, backups pagos ou Blaze.
- Antes de billing: estimar custos, criar alertas, separar ambientes e obter autorização.
- Usar JBR/OpenJDK 21.0.9 existente e não alterar safe.directory global.
- Adiar Gemini para a Etapa 5; Firebase para decisão anterior à configuração; jurídico para antes da publicação; dívidas, cartões e Analytics para seus portões específicos.

## Consequências

- A documentação pode avançar sem mutação externa.
- Cada ativação exige autorização específica.
- O bloqueio Flutter da sandbox não é falha local confirmada.

## Adendo de 29/07/2026 — Etapa 3A

- A validação visual Android foi adiada por decisão do solicitante e permanece pendente, sem caracterizar falha.
- Foi autorizada somente a instalação das ferramentas, autenticação Google e descoberta de projetos, sem seleção ou configuração.
- O launcher standalone oficial da Firebase CLI foi baixado para `%LOCALAPPDATA%\FirebaseCLI\firebase.exe`, mas falhou na preparação `firepit`; sua versão não foi validada e seu diretório não entrou no PATH.
- FlutterFire CLI `1.4.0` foi ativado pelo Dart Pub e validado; somente o diretório de executáveis Pub foi acrescentado ao PATH do usuário.
- Como a Firebase CLI não ficou funcional, login e listagem de projetos não foram executados.
- Permanecem proibidos init, configure, use, deploy, criação/seleção de projeto, serviços Firebase, alterações Flutter/Android, commit e push.

### Consequência do adendo

- A Etapa 3A está parcialmente concluída, com bloqueio técnico na Firebase CLI standalone.
- A seleção ou criação de projeto development/production continua sujeita a autorização explícita.

## Adendo de 29/07/2026 — Operação externa exclusivamente manual

### Decisão

- Todas as ações em Firebase, Google Cloud e Gemini serão realizadas manualmente pelo solicitante, seguindo orientações passo a passo.
- O agente não pode criar ou excluir projetos, autenticar contas, selecionar projetos, executar `firebase init`, `firebase use`, `flutterfire configure` ou deploy.
- O agente não pode habilitar Authentication, Firestore, Storage, Functions, App Check, Analytics ou Crashlytics.
- O agente não pode criar chaves, credenciais, contas de serviço ou segredos, nem ativar faturamento ou plano Blaze.
- O agente não pode alterar configurações no Firebase Console ou Google Cloud Console.
- O agente pode analisar o projeto, preparar código dependente de configurações já autorizadas, explicar configurações externas e fornecer comandos para execução manual pelo solicitante.
- Depois de cada ação manual, o agente pode verificar somente os arquivos e resultados que o solicitante disponibilizar no workspace.
- O agente deve aguardar confirmação antes de continuar e nunca solicitar senhas, tokens, chaves privadas ou arquivos de conta de serviço no chat.
- A Firebase CLI não será corrigida ou reinstalada neste momento.

### Consequências

- Autenticação, descoberta, seleção, criação e configuração de projetos deixam de ser ações executáveis pelo agente.
- Orientações futuras devem separar claramente comandos manuais do usuário e verificações locais permitidas ao agente.
- Firebase continua não configurado no aplicativo.
- Commit, push e deploy permanecem proibidos.

## Adendo de 30/07/2026 — Etapa 3B local autorizada

### Contexto

O solicitante realizou manualmente a configuração development no Firebase Console e disponibilizou o arquivo Android oficial no workspace. O agente recebeu autorização somente para integração local Android, autenticação e sistema visual.

### Decisão

- Validar localmente o package do `google-services.json` sem exibir seu conteúdo.
- Aplicar Google Services Gradle plugin 4.5.0 e somente os plugins Flutter `firebase_core`, `firebase_auth`, `cloud_firestore` e `google_sign_in`.
- Inicializar Firebase Android apenas em development; production é bloqueado sem fallback.
- Bloquear release production enquanto documentos jurídicos oficiais não forem declarados por `LEGAL_DOCUMENTS_STATUS=official`.
- Manter Firestore totalmente sem operações e suas regras externas inalteradas.
- Implementar autenticação por repositório, Riverpod e guardas de go_router.
- Manter exclusão de conta fora da interface até existir fluxo integral com reautenticação e exclusão segura.
- Usar somente recorte fotográfico isolado como asset; toda interface é composta por widgets Flutter.
- Manter CLI, console, deploy, commit e push fora do escopo do agente.

### Consequências

- A autenticação pode ser testada no projeto development configurado pelo solicitante.
- O aplicativo não pode conectar produção ao projeto development.
- Textos provisórios não habilitam publicação.
- Web, Windows e iOS continuam dependentes de configuração oficial por plataforma.
- A validação manual Android aprovou a interface e os fluxos de autenticação por e-mail; o login Google corrigido aguarda novo teste do APK atualizado.

## Adendo de 31/07/2026 — Etapa 3C em dois pontos de controle

- O login Google foi aprovado em novo teste manual.
- O Ponto de Controle 1 autoriza somente código, regras, documentação e testes locais de perfil e consentimentos.
- `firestore.rules` não pode ser publicado pelo agente. A publicação development é manual pelo solicitante.
- O Ponto de Controle 2, incluindo APK debug, depende da confirmação literal `REGRAS FIRESTORE PUBLICADAS`.
- Firebase CLI, Emulator Suite, Console, deploy, commit e push continuam proibidos para o agente.

## Adendo de 01/08/2026 — Estado validado até a Etapa 4C

- O proprietário publicou manualmente em development as regras de perfil, contas, categorias, lançamentos e owner.
- Perfil, consentimentos, núcleo financeiro manual e acesso owner foram validados no Android.
- O documento `system_admins/{uid}` foi criado manualmente, sem identidade administrativa no código ou na documentação.
- Ações futuras no Firebase, Google Cloud e Gemini continuam exclusivamente manuais pelo proprietário.
- Testes diretos das Security Rules no Emulator Suite permanecem pendentes de autorização específica.
