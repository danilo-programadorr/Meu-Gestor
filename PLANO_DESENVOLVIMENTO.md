# Plano de desenvolvimento — Meu Gestor Financeiro

## 1. Situação e autoridade

- Especificação oficial integral: ESPECIFICACAO_FUNCIONAL.md.
- Regras permanentes aprovadas: AGENTS.md.
- Modelo detalhado proposto: MODELO_FIRESTORE.md.
- Rastreabilidade: MATRIZ_REQUISITOS.md.
- Data desta revisão: 2 de agosto de 2026.
- Os comandos públicos usam caminhos relativos à raiz do repositório.
- A fundação local autorizada da Etapa 2 foi criada e validada nos limites da seção 16.
- Todas as ações externas de Firebase, Google Cloud e Gemini são exclusivamente manuais pelo solicitante; o agente limita-se a orientar, preparar código autorizado e verificar resultados locais após confirmação.

## 2. Decisões aprovadas

1. Plataforma inicial Android.
2. Arquitetura preparada para Web, Windows e iOS.
3. Uso pessoal e individual na primeira versão.
4. Português do Brasil, moeda BRL, símbolo R$, datas dd/MM/yyyy e fuso America/Sao_Paulo.
5. Flutter, Dart, arquitetura limpa e modular, Riverpod e go_router.
6. Firebase Authentication com e-mail/senha e Google.
7. Cloud Firestore, Cloud Functions, Firebase Cloud Messaging, Firebase App Check, Firebase Crashlytics e Firebase Analytics.
8. Gemini somente por Cloud Function segura.
9. Dinheiro armazenado em centavos inteiros.
10. Ambientes development e production separados.
11. Cadastro financeiro manual e sem integração bancária automática na primeira versão.
12. JBR/OpenJDK 21.0.9 do Android Studio será utilizado.
13. Nenhum outro Java será instalado.
14. safe.directory global do Git não será alterado neste momento.
15. O bloqueio Flutter na sandbox não representa falha confirmada da instalação local.
16. Firebase CLI e FlutterFire CLI não serão instaladas até nova autorização.
17. Dados de demonstração são permitidos somente em development/testes, desativados por padrão e isolados de produção.
18. Contas a receber são entidade própria em receivables e vinculam recebimentos a rendas sem duplicação.
19. Reserva financeira é meta vinculada a conta; movimentos da meta são a fonte de verdade.
20. Confiança das rendas usa 100%, 80%, 50% e 20%, com projeções nominal e conservadora.
21. Risco financeiro usa regras determinísticas críticas, de risco, atenção e saudável, com prevalência do nível mais grave.
22. Recorrência em dia inexistente usa o último dia do mês em America/Sao_Paulo.
23. Compra no fechamento ou depois entra na próxima fatura; melhor dia inicial é o dia seguinte.
24. Taxas nunca são inventadas, usam pontos-base e podem ser desconhecidas.
25. Pagamentos parciais são imutáveis e corrigidos por cancelamento ou compensação auditável.
26. Gasto acima da média usa três meses completos, 20% e diferença mínima de R$ 50,00.
27. Assinaturas apenas geram pergunta de uso; sugestão depende da resposta.
28. Operações críticas offline só confirmam após servidor; conflitos nunca usam last-write-wins silencioso.
29. Aplicação de simulação exige prévia, confirmação, atomicidade e auditoria.
30. Cloud Storage futuro está aprovado com PDF/JPEG/PNG, 10 MB e cinco anexos, mas ativação/faturamento não.
31. CSV, Excel e PDF serão gerados localmente na primeira versão dentro dos limites do dispositivo.
32. Gemini usa Function, Auth, App Check, resposta estruturada, 10 análises/dia e cerca de 2.000 tokens de saída.
33. Plano anticrise é híbrido: regras decidem e Gemini apenas explica.
34. Analytics começa desativado; IA tem consentimento separado; Crashlytics não registra dados sensíveis.
35. Retenção inicial: IA/notificações 90 dias, auditoria 180 dias, órfãos 30 dias.
36. Backups de produção são planejados para 30 dias, sem ativação paga autorizada.
37. Notificação bloqueada usa texto genérico por padrão.
38. Blaze pode ser considerado, mas faturamento não está autorizado.
39. O identificador definitivo do aplicativo Android é `br.com.hellenfaro.meugestorfinanceiro`.
40. O nome interno do projeto Flutter é `meu_gestor_financeiro` e o nome exibido é Meu Gestor Financeiro.
41. O saldo canônico deriva de saldo inicial, entradas e saídas confirmadas e transferências confirmadas; nenhum saldo materializado é canônico.
42. Antes de `emailVerified=true`, somente confirmação, reenvio, atualização, logout, exclusão e documentos jurídicos são permitidos; Google segue o estado do Firebase Authentication.
43. Reajustes são fixos ou percentuais, possuem vigência e entidade relacionada, afetam ocorrências futuras e exigem confirmação/auditoria quando retroativos.
44. Formas iniciais de recebimento e pagamento seguem as enumerações da seção 30 da especificação.
45. Decisões de Gemini, Firebase, serviços pagos, jurídico, dívida, cartão e Analytics são portões das respectivas etapas e não bloqueiam a fundação local.
46. O projeto deve ser operado a partir da raiz do repositório; caminhos absolutos locais não fazem parte da documentação pública.
47. Firebase, Google Cloud e Gemini serão operados manualmente pelo solicitante; o agente não executa autenticação, seleção/criação de projetos, configuração de serviços, credenciais, faturamento ou deploy e nunca solicita segredos no chat.
48. O perfil inicial usa `users/{uid}`, esquema 1, versões jurídicas development `terms-dev-1.0.0` e `privacy-dev-1.0.0` e consentimentos de IA e Analytics separados e desativados por padrão.
49. A Etapa 3C usa regras Firestore com negação por padrão, exige email confirmado no usuário e no token e mantém subcoleções financeiras bloqueadas.
50. Publicação de regras é manual e a validação final/APK só ocorre depois da confirmação literal `REGRAS FIRESTORE PUBLICADAS`.
51. O papel `owner` é associado somente ao UID autenticado por `system_admins/{uid}`, exclusivamente em development, com leitura pontual confirmada pelo servidor e nenhuma escrita pelo cliente.
52. Capabilities owner são centralizadas e incluem acesso a módulos, diagnósticos, experimentos, preferências de desenvolvimento e bypass futuro de assinatura, recursos pagos, IA e limites comerciais comuns.
53. Capabilities comerciais não removem Security Rules, isolamento por UID, validações financeiras, autenticação, concorrência ou limites técnicos contra abuso e consumo acidental.
54. `FIN-5A — Compromissos financeiros` identifica o incremento operacional de contas a pagar e receber e permanece dentro da macroetapa de controle financeiro; não altera a macroetapa 5 de IA.
55. Contas a pagar usam `payables` e contas a receber usam `receivables`; compromissos não alteram saldo antes de gerar lançamento confirmado.
56. Atraso é derivado da data civil atual de `America/Sao_Paulo` e nunca é status persistido.
57. `transactions` esquema 2 adiciona vínculo de origem; documentos esquema 1 continuam compatíveis como manuais, sem migração em massa.
58. Pendência pode terminar `cancelled`; pagamento ou recebimento posteriormente anulado termina `voided` junto com a invalidação atômica do lançamento vinculado.
59. Recorrências, parcelamentos, liquidações parciais, juros, multas, descontos e notificações não pertencem a FIN-5A.
60. A correção do saldo inicial exige proteção no domínio, repositório e Security Rules; bloqueio apenas visual é rejeitado. A proposta técnica permanece pendente de aprovação para implementação.

## 3. Estado do ambiente

| Item | Estado |
|---|---|
| Flutter | 3.41.1 stable validado |
| Dart | 3.11.0 stable encontrado no SDK Flutter |
| Git | 2.49.0.windows.1 instalado |
| Android Studio | 2025.3 instalado |
| Java | JBR/OpenJDK 21.0.9 fornecido pelo Android Studio |
| Firebase CLI | launcher standalone oficial baixado; versão não validada por falha `firepit`; fora do PATH |
| FlutterFire CLI | 1.4.0 ativado e validado; diretório Pub adicionado ao PATH do usuário |
| Node.js | 24.18.0 instalado |
| npm | comando com falha e não autorizado para reparo |
| Repositório do aplicativo | Git presente, branch `main` baseada no histórico remoto e sem alteração global de safe.directory |

O diagnóstico detalhado da máquina permanece local em `docs/internal/` e não integra a documentação pública.

## 4. Arquitetura recomendada

### 4.1 Visão geral

~~~text
Aplicativo Flutter Android
  |
  +-- apresentação: telas, widgets, rotas, acessibilidade
  +-- aplicação: casos de uso, orquestração, permissões
  +-- domínio: dinheiro, datas, regras, projeções, decisões
  +-- dados: repositórios, DTOs, cache e sincronização
  |
Firebase SDKs
  +-- Authentication
  +-- Firestore com persistência offline
  +-- Cloud Storage futuro somente para anexos
  +-- Cloud Functions callable e agendadas
  +-- Cloud Messaging
  +-- App Check
  +-- Crashlytics
  +-- Analytics
        |
Cloud Functions seguras
  +-- regras privilegiadas e idempotência
  +-- notificações e recorrências
  +-- projeções e resumos
  +-- exportações
  +-- exclusão LGPD
  +-- Gemini por segredo ou identidade de serviço
~~~

### 4.2 Camadas

- Apresentação: páginas, widgets, controladores Riverpod, navegação go_router, máscaras e semântica acessível.
- Aplicação: casos de uso, políticas de autorização, coordenação de repositórios e estados.
- Domínio: entidades, objetos de valor, cálculos e regras sem dependência de Flutter ou Firebase.
- Dados: DTOs, conversores, repositórios Firestore, armazenamento seguro, anexos e sincronização.
- Backend: Functions com validação, App Check, rate limit, idempotência, auditoria e integrações externas.

### 4.3 Princípios

- Organização por funcionalidade.
- Dependências apontam para o domínio.
- Firestore é acessado por repositórios tipados.
- Cálculos financeiros são determinísticos e centralizados.
- Gemini explica e orienta, mas não substitui cálculos nem grava dados financeiros.
- Estado local seguro guarda somente dados apropriados, nunca chaves Gemini.
- Firestore offline oferece cache e fila para consultas e novos cadastros.
- Transferências, pagamentos, recebimentos, cancelamentos e aplicação de simulações podem ser preparados offline, mas só são confirmados após sincronização, revisão de versão e validação do servidor.
- Conflitos exibem as versões ao usuário; last-write-wins silencioso é proibido.
- Resumos são reconstruíveis; lançamentos canônicos preservam a fonte de verdade.
- Validação ocorre no formulário, domínio, Security Rules e Functions.
- Acessibilidade não depende apenas de cor.

## 5. Tecnologias e bibliotecas planejadas

As versões serão resolvidas e fixadas somente após autorização.

### Aplicativo Flutter

| Pacote ou SDK | Finalidade |
|---|---|
| flutter_riverpod | estado e injeção de dependências |
| go_router | navegação e guardas de autenticação |
| firebase_core | inicialização Firebase |
| firebase_auth | e-mail/senha, Google e sessão |
| cloud_firestore | dados e sincronização offline |
| cloud_functions | chamadas seguras ao backend |
| firebase_messaging | notificações FCM |
| firebase_app_check | redução de abuso |
| firebase_crashlytics | falhas em produção |
| firebase_analytics | métricas sujeitas a privacidade e consentimento |
| firebase_storage | comprovantes e anexos após autorização de Storage/faturamento |
| flutter_secure_storage | armazenamento local seguro |
| flutter_local_notifications | alertas locais |
| timezone | agendamento em America/Sao_Paulo |
| intl | BRL, pt-BR e datas |
| freezed_annotation e json_annotation | modelos imutáveis e serialização |
| file_picker ou image_picker | seleção de comprovantes conforme fluxo aprovado |
| path_provider e share_plus | geração e compartilhamento local de exportações |

### Desenvolvimento e testes

- flutter_lints, riverpod_lint e custom_lint.
- build_runner, freezed e json_serializable.
- flutter_test, integration_test e mocktail.
- Firebase Emulator Suite para Authentication, Firestore, Functions e Storage.
- Ferramentas de teste de Security Rules.

### Backend

- Runtime Node.js suportado pelo Firebase na data de implementação.
- firebase-functions e firebase-admin.
- SDK oficial Gemini ou Vertex AI escolhido após decisão de provedor.
- Bibliotecas de PDF, CSV e planilha serão escolhidas para geração local; Function de exportação grande fica para decisão futura.

## 6. Estrutura de pastas

~~~text
meu_gestor_financeiro/
+-- android/
+-- lib/
|   +-- app/
|   |   +-- bootstrap/
|   |   +-- routing/
|   |   +-- theme/
|   |   +-- l10n/
|   |   +-- app.dart
|   +-- core/
|   |   +-- analytics/
|   |   +-- crash_reporting/
|   |   +-- errors/
|   |   +-- money/
|   |   +-- security/
|   |   +-- storage/
|   |   +-- sync/
|   |   +-- time/
|   |   +-- validation/
|   |   +-- widgets/
|   +-- features/
|   |   +-- onboarding/
|   |   +-- authentication/
|   |   +-- consent/
|   |   +-- dashboard/
|   |   +-- calendar/
|   |   +-- accounts/
|   |   +-- categories/
|   |   +-- commitments/
|   |   +-- incomes/
|   |   +-- expenses/
|   |   +-- recurring_entries/
|   |   +-- timeline/
|   |   +-- forecasts/
|   |   +-- credit_cards/
|   |   +-- invoices/
|   |   +-- installments/
|   |   +-- debts/
|   |   +-- budgets/
|   |   +-- goals/
|   |   +-- purchase_assessment/
|   |   +-- simulations/
|   |   +-- debt_strategies/
|   |   +-- crisis_plan/
|   |   +-- ai_assistant/
|   |   +-- recommendations/
|   |   +-- reports/
|   |   +-- exports/
|   |   +-- notifications/
|   |   +-- attachments/
|   |   +-- profile/
|   |   +-- privacy/
|   |   +-- settings/
|   +-- main.dart
+-- functions/
|   +-- src/
|   |   +-- ai/
|   |   +-- alerts/
|   |   +-- audit/
|   |   +-- projections/
|   |   +-- recurrence/
|   |   +-- summaries/
|   |   +-- users/
|   +-- test/
+-- firebase/
|   +-- firestore.rules
|   +-- firestore.indexes.json
|   +-- storage.rules
+-- test/
+-- integration_test/
+-- docs/
|   +-- adr/
+-- AGENTS.md
+-- DIAGNOSTICO_AMBIENTE.md
+-- ESPECIFICACAO_FUNCIONAL.md
+-- MATRIZ_REQUISITOS.md
+-- MODELO_FIRESTORE.md
+-- PLANO_DESENVOLVIMENTO.md
~~~

Web, Windows e iOS não serão gerados na primeira versão, mas domínio, aplicação e contratos não dependerão do Android.

## 7. Entidades e modelo de dados

Entidades centrais:

- perfil, consentimento e dispositivo;
- conta, categoria, renda, conta a receber, despesa, pagamento e transferência;
- recorrência e ocorrência idempotente;
- cartão, fatura, parcela e dívida;
- orçamento, meta e movimento de meta;
- projeções nominal/conservadora, resumo mensal, simulação e avaliação de compra;
- estratégia de dívida e plano anticrise;
- notificação local/remota;
- análise financeira por IA;
- anexo, exportação e auditoria.

O modelo completo com caminhos, modelos Dart, campos, tipos, obrigatoriedade, índices, validações, conversores e matriz de acesso está em MODELO_FIRESTORE.md. Ele segue as coleções sugeridas na especificação e adiciona somente estruturas necessárias a recorrência, transferências, dispositivos, anexos, exportações, resumos e auditoria.

## 8. Telas e navegação

As 30 telas mínimas da especificação serão mantidas:

1. abertura;
2. apresentação inicial;
3. login;
4. cadastro;
5. recuperação de senha;
6. dashboard;
7. calendário financeiro;
8. linha do tempo do saldo;
9. lista de receitas;
10. cadastro de receita;
11. lista de despesas;
12. cadastro de despesa;
13. contas vencidas;
14. contas e carteiras;
15. cartões;
16. faturas;
17. dívidas;
18. parcelamentos;
19. orçamentos;
20. metas;
21. simulador;
22. Posso comprar?;
23. assistente financeiro com IA;
24. recomendações;
25. plano anticrise;
26. relatórios;
27. notificações;
28. configurações;
29. perfil;
30. privacidade e consentimentos.

Fluxo principal:

~~~text
Abertura
  -> apresentação e termos
  -> cadastro ou login
  -> confirmação de e-mail quando aplicável
  -> configuração inicial de conta, renda e despesas
  -> dashboard
       -> calendário e linha do tempo
       -> receitas, despesas, contas e cartões
       -> dívidas, orçamento e metas
       -> projeções, Posso comprar? e simulador
       -> IA, recomendações e plano anticrise
       -> relatórios e exportações
       -> notificações, perfil, privacidade e configurações
~~~

Rotas sensíveis exigem sessão válida. IA exige consentimento específico. Exclusão de conta exige reautenticação e confirmação.

## 9. Regras de negócio e cálculos

### 9.1 Fórmulas oficiais

- saldo atual = soma dos saldos das contas;
- saldo projetado = saldo atual + receitas previstas - despesas previstas;
- dinheiro livre = receitas recebidas e previstas confiáveis - despesas essenciais - contas pendentes - compromissos reservados;
- percentual comprometido = despesas obrigatórias dividido pela renda mensal confiável, multiplicado por 100.

### 9.2 Invariantes

- Valores persistidos em centavos inteiros.
- Limite de cartão não é dinheiro disponível.
- Transferência não é receita nem despesa.
- Renda prevista não é garantida e possui nível de confiança.
- Pesos de confiança: confirmada 100%, alta 80%, média 50% e baixa 20%; cancelada ou atrasada sem nova previsão vale 0%.
- Saldo bancário, saldo projetado, dinheiro reservado e dinheiro livre são conceitos distintos.
- Pagamento de fatura não duplica despesa.
- Pagamento parcial preserva histórico e saldo restante.
- Recorrências e parcelas usam chave idempotente.
- Juros desconhecidos não são inventados.
- Simulação não altera dados reais sem confirmação.
- Projeção sem dados suficientes mostra baixa confiança.
- Cálculos não dependem do Gemini.
- Reserva é meta vinculada a conta; movimentos da meta são canônicos e o resumo da conta é derivado.

### 9.3 Projeções e risco

Horizontes: 30 dias, 3 meses, 6 meses e 12 meses.

Entradas: saldo, rendas, confiança, despesas, atrasos, parcelas, faturas, dívidas, reajustes, metas e reservas.

Saídas: projeção nominal, projeção conservadora, menor saldo, primeiro dia negativo, dias de risco, meses com déficit/sobra, comprometimento, capacidade de pagamento e valor seguro para gastos não essenciais.

Níveis de risco: saudável, atenção, risco e crítico, com as condições determinísticas da seção 29.5 da especificação. Prevalece o nível mais grave e cada classificação lista os fatos causadores.

## 10. Cloud Functions planejadas

1. gerar rendas recorrentes;
2. gerar contas recorrentes;
3. gerar parcelas e faturas sem duplicação;
4. atualizar atrasos;
5. calcular projeções protegidas;
6. gerar resumos mensais;
7. verificar alertas;
8. enviar FCM;
9. processar Gemini;
10. aplicar rate limit e prevenção de abuso;
11. registrar auditoria sem dados sensíveis;
12. reservar extensão futura para exportações grandes, somente após nova aprovação;
13. excluir conta e dados;
14. manter campos derivados de cartões, faturas, dívidas, orçamento e metas.

Toda função terá autenticação, App Check quando aplicável, validação de esquema, idempotência, timeout, limite, código de erro seguro e testes.

## 11. Segurança, privacidade, offline e observabilidade

- Firestore e Storage negam acesso por padrão.
- Cada usuário acessa somente o próprio caminho.
- Admin SDK não confia no cliente e revalida proprietário.
- Segredos Gemini ficam no Secret Manager ou identidade de serviço.
- Anexos têm tipo, tamanho, caminho, hash, retenção e acesso controlados.
- Logs, Crashlytics e Analytics não recebem valores, descrições, anexos, tokens ou prompts.
- Analytics e IA respeitam consentimento e opção de desativação.
- Armazenamento seguro local não é fonte canônica de dados financeiros.
- Cache offline informa estado de sincronização e possíveis pendências.
- Operações críticas concorrentes usam transação, lote ou Function.
- Exclusão de conta cobre Auth, Firestore, Storage, tokens, análises e exportações.
- Exportações têm prazo, acesso temporário e aviso de sensibilidade.

## 12. Etapas de desenvolvimento

A ordem oficial de seis etapas será preservada. Cada etapa só começa após autorização.

### Etapa 1 — Planejamento

- especificação, matriz e decisões;
- arquitetura, pastas, entidades e navegação;
- modelo Firestore e Storage;
- regras de cálculo;
- dependências, custos, segurança e testes;
- critérios de aceite por requisito.
- ADRs das decisões aprovadas.

Situação: documentação atualizada; conflitos remanescentes estão na seção 15.

### Etapa 2 — Projeto base

- uso do identificador Android aprovado `br.com.hellenfaro.meugestorfinanceiro` quando a criação do projeto for autorizada;
- nome Dart `meu_gestor_financeiro` e nome exibido Meu Gestor Financeiro;
- confirmação do Flutter local;
- projeto Android e configuração development;
- temas claro/escuro, pt-BR, rotas, Riverpod e erros;
- objetos de valor iniciais de dinheiro e moeda, análise estática rigorosa e testes unitários;
- estrutura preparada para ambientes development e production, sem conexão externa.

Situação: fundação local criada e validada com `flutter analyze` e `flutter test`. A validação visual Android foi adiada por decisão do solicitante e permanece pendente, sem representar falha. Firebase, autenticação no aplicativo, App Check, emuladores, armazenamento seguro, Crashlytics, Analytics e dados de demonstração não fizeram parte deste incremento.

### Etapa 3 — Controle financeiro principal

- contas, carteiras e categorias;
- rendas, contas a receber, despesas, pagamentos e recorrências;
- comprovantes;
- dashboard, calendário e linha do tempo;
- reserva por meta vinculada, projeções nominal/conservadora e risco explicável;
- offline, versões, conflitos explícitos, sincronização e testes centrais.

### Etapa 4 — Recursos avançados

- cartões, faturas, parcelas e dívidas;
- regras aprovadas de fechamento, último dia do mês, taxas em pontos-base e pagamentos imutáveis;
- orçamento e metas;
- Posso comprar? e simulador;
- gasto acima da média e revisão de assinaturas;
- avalanche, bola de neve e método personalizado;
- alertas locais, FCM e Functions agendadas.

### Etapa 5 — Inteligência artificial

- consentimento e opção sem IA;
- Function segura para Gemini;
- modelo configurável, 10 análises/dia, timeout, custo e saída estruturada de aproximadamente 2.000 tokens;
- análises estruturadas e histórico;
- recomendações explicáveis;
- plano anticrise semanal e mensal;
- limites de uso, custo, privacidade e testes de abuso.

### Etapa 6 — Relatórios e segurança

- relatórios e filtros;
- PDF, CSV e planilha compatível com Excel gerados localmente;
- regras finais Firestore e Storage;
- App Check aplicado;
- exclusão, retenção, exportação LGPD e auditoria;
- documentação e teste de restauração de backup, sem ativação paga automática;
- testes completos, documentação, desempenho e preparação Android.

## 13. Estratégia de testes

- Unitários: dinheiro, saldos, confiança, recorrência, parcelas, faturas, juros, projeções, risco, orçamento, metas, estratégias e plano anticrise.
- Widget: formulários, máscaras, estados, acessibilidade, confirmação e telas vazias.
- Integração: autenticação, confirmação de e-mail, jornadas financeiras, offline/sincronização, anexos, notificações e exportações.
- Security Rules: acesso próprio, acesso cruzado negado, campos protegidos, tipos e transições.
- Functions: autenticação, App Check, idempotência, rate limit, recorrência, alertas, Gemini, exclusão e exportações.
- Datas: fuso São Paulo, meses de 28 a 31 dias, virada de ano e meses curtos.
- Monetários: arredondamento e ausência de double persistido.
- Regressão: lançamentos e notificações duplicadas.
- Operacionais: Crashlytics sem PII, Analytics conforme consentimento e custos monitorados.

## 14. Custos e riscos

- Cloud Functions, Cloud Storage, Gemini, exportações e tarefas agendadas podem exigir Blaze.
- Firestore cobra operações, índices, armazenamento e tráfego acima das cotas.
- Anexos e exportações elevam armazenamento e saída.
- Projeções e dashboard podem causar leituras excessivas sem resumos e paginação.
- FCM não tem custo direto relevante, mas Functions e Firestore usados para disparo podem cobrar.
- Crashlytics e Analytics exigem governança de privacidade.
- Gemini exige limites por usuário, tokens máximos e alertas de faturamento.
- Alertas de orçamento não interrompem cobrança.
- Dados financeiros e anexos elevam impacto LGPD e de incidente.
- Sincronização offline pode gerar conflito; transições financeiras precisam de política explícita.

## 15. Requisitos indefinidos ou conflitantes

1. O modelo Gemini definitivo será decidido na Etapa 5.
2. As regiões e os identificadores dos projetos Firebase development e production serão decididos antes da configuração Firebase.
3. Cloud Storage, plano Blaze e qualquer faturamento continuam dependendo de estimativa e autorização separada.
4. Backups pagos, responsável por autorizar restauração e procedimento operacional final ainda precisam de aprovação.
5. Textos jurídicos, versões de termos, política de privacidade e revisão jurídica final devem ser concluídos antes da publicação.
6. O método personalizado de dívidas precisa de pesos entre juros, risco de corte, atraso e essencialidade antes desse módulo.
7. A regra de juros estimados/rotativo de cartão precisa de fórmula operacional antes do módulo de cartões.
8. O limiar que caracteriza juros elevados precisa ser definido antes do plano de dívidas.
9. O catálogo permitido de eventos Analytics e a base legal final precisam ser aprovados antes da ativação do Analytics.
10. As prioridades de contas a receber ainda precisam ser aprovadas antes desse módulo.
11. A implementação da imutabilidade do saldo inicial e da futura operação de ajuste auditável depende de aprovação específica posterior a FIN-5A-1.
12. A infraestrutura executável do Emulator Suite exige decisão separada sobre ferramentas e dependências locais; nenhuma matriz pode ser declarada executada antes disso.

## 16. Portão para implementação

A fundação local autorizada da Etapa 2 foi concluída. Toda ação externa de Firebase, Google Cloud e Gemini é manual pelo solicitante. O agente pode orientar e verificar arquivos gerados, mas não autenticar, selecionar/criar projetos, configurar serviços, criar credenciais, ativar faturamento ou executar deploy. Operações Git exigem autorização específica.

## 17. Etapa 3A — Ferramentas e descoberta do Firebase

- Situação em 29/07/2026: encerrada no limite autorizado; nenhuma correção ou reinstalação da Firebase CLI será tentada pelo agente.
- Firebase CLI: launcher oficial baixado em `%LOCALAPPDATA%\FirebaseCLI\firebase.exe`, porém `firebase --version` falha na preparação `firepit`; versão não validada e pasta não adicionada ao PATH.
- FlutterFire CLI: versão `1.4.0` ativada e validada; `%LOCALAPPDATA%\Pub\Cache\bin` foi acrescentado ao PATH do usuário.
- Autenticação Google: não executada porque a Firebase CLI não está funcional.
- Projetos Firebase: não listados, selecionados, criados ou modificados.
- Validação Android: pendente por decisão, não falha; nenhum APK ou AVD foi criado.
- Código e configuração do aplicativo: inalterados.
- Próximo portão: o solicitante executará manualmente qualquer ação externa e confirmará o resultado; o agente poderá então verificar os arquivos gerados sem receber segredos.

## 18. Etapa 3B — Integração Firebase Android, autenticação e sistema visual

Situação em 30/07/2026: implementação local concluída e sujeita à validação final por análise, testes e APK debug ao término do incremento.

- O solicitante configurou manualmente o projeto Firebase development, registrou o aplicativo Android, habilitou email/senha e Google, criou Firestore em modo produção e forneceu `android/app/google-services.json`.
- A inspeção local confirmou uma única entrada Android com package exato `br.com.hellenfaro.meugestorfinanceiro` e configuração correspondente ao ambiente development; o conteúdo do arquivo não foi exibido e permanece ignorado pelo Git.
- O plugin Gradle `com.google.gms.google-services` 4.5.0 foi aplicado com Kotlin DSL.
- Dependências limitadas a `firebase_core` 4.12.1, `firebase_auth` 6.5.6, `cloud_firestore` 6.7.1 e `google_sign_in` 7.2.0, todas BSD-3-Clause.
- Firebase é inicializado sem `firebase_options.dart`, usando a configuração Android oficial somente em `APP_ENV=development`.
- `APP_ENV=production` não inicializa Firebase, não usa fallback development e exibe indisponibilidade segura.
- Build release com `APP_ENV=production` também é bloqueado enquanto `LEGAL_DOCUMENTS_STATUS=official` não for informado.
- A autenticação segue camadas `domain`, `data` e `presentation`; widgets não chamam Firebase diretamente.
- Foram implementados login email/senha, criação de conta com displayName e verificação, Google, recuperação genérica, verificação com cooldown, atualização, logout e guardas de rota.
- Usuário não verificado acessa somente confirmação, reenvio, atualização, logout e documentos legais. Exclusão não foi exposta porque reautenticação e exclusão integral segura pertencem a incremento posterior.
- A página autenticada é técnica e não contém dashboard ou dados financeiros fictícios.
- `cloud_firestore` foi adicionado, mas não há leitura, gravação, listener, perfil, coleção, documento, consentimento, regra ou índice criado.
- O sistema visual e o hero fotográfico isolado estão documentados em `docs/design/SISTEMA_VISUAL.md`.
- Os documentos legais existentes são provisórios, exclusivos de development e não podem ser apresentados como versão final.
- Web, Windows e iOS exigirão configuração Firebase oficial específica quando forem adicionados.
- A validação manual Android aprovou e-mail/senha, cadastro, recuperação, confirmação, navegação, interface e o login Google após a correção local.

## 19. Etapa 3C — Segurança inicial, perfil e consentimentos

Situação em 01/08/2026: concluída e aprovada manualmente, incluindo regras publicadas, perfil, consentimentos, correção do ProfileGate e teste Android.

- `users/{uid}` contém somente o perfil básico autorizado, sem email, telefone, identificadores externos, aparelho ou dados financeiros.
- O portão recarrega o usuário e força o token antes de qualquer acesso ao Firestore.
- Perfil inexistente exige configuração e aceite explícito; perfil jurídico desatualizado exige novo aceite; perfil incompatível bloqueia a área autenticada.
- Criação é transacional e idempotente. Perfil existente é validado e preservado.
- Leituras e confirmações de escrita exigem origem servidor; cache não prova autorização.
- Firestore é a fonte do nome interno depois da criação; Authentication continua sendo a identidade e recebe tentativa posterior de espelhamento do nome.
- IA e Analytics permanecem desativados; os booleanos são apenas preferências futuras separadas.
- `firestore.rules` do perfil foi publicado manualmente pelo proprietário e validado no fluxo real.
- Testes de regras no Emulator Suite permanecem pendentes porque CLI e emulador não estão autorizados.

## 20. Etapa 4A — Contas, carteiras e saldo inicial

Situação em 01/08/2026: concluída após publicação manual das regras pelo proprietário e validação local do Ponto de Controle 2.

- Escopo limitado a contas, carteiras, saldo inicial, total local, criação, leitura, edição, arquivamento e restauração.
- Persistência exata em `users/{uid}/accounts/{accountId}`, sem `accountId` duplicado, `currentBalanceCents`, transações ou exclusão definitiva.
- Tipos autorizados: `checking`, `savings`, `cash`, `digitalWallet`, `investment` e `other`.
- Saldos individuais permanecem entre -9.999.999.999 e 9.999.999.999 centavos; nenhuma operação usa ponto flutuante.
- Na entrega original da etapa, o saldo exibido era igual ao saldo inicial. A Etapa 4B passou a derivar o saldo atual dos lançamentos ativos confirmados.
- Criação reutiliza o ID gerado durante a tentativa, bloqueia toques repetidos e só informa sucesso após releitura do servidor.
- Leituras de lista e documento exigem confirmação do servidor; cache não é prova de autorização e a estratégia offline financeira completa permanece futura.
- Regras locais preservam o perfil, isolam dados por UID, exigem email verificado, validam campos/transições e negam exclusão, subcoleções e caminhos desconhecidos.
- Consultas usam apenas a subcoleção própria, sem `collectionGroup` ou índice composto; separação, ordenação e total são locais.
- As regras de contas foram publicadas manualmente pelo proprietário; o agente não executou Firebase CLI ou deploy.
- A validação posterior confirmou formatação, análise, testes e build debug development antes do início da Etapa 4B.

## 21. Etapa 4B — Categorias, receitas, despesas e saldo atual

Situação em 01/08/2026: concluída e validada manualmente após publicação das regras e correções finais de resumo, navegação, edição e data da movimentação.

- Categorias próprias em `users/{uid}/categories/{categoryId}`, separadas entre receita e despesa, com ícones/cores fechados, tipo imutável e arquivamento sem exclusão.
- Lançamentos próprios em `users/{uid}/transactions/{transactionId}`, limitados a receitas e despesas ocorridas, valor positivo em centavos e sinal derivado pelo tipo.
- Criação exige conta e categoria ativas do mesmo usuário, com tipo compatível; edição não altera conta, tipo ou valor.
- Cancelamento é irreversível, auditável por timestamps e não apaga o documento.
- Saldo atual deriva do saldo inicial mais receitas ativas menos despesas ativas; nenhum saldo materializado é canônico.
- Resumo do mês respeita a data civil de `America/Sao_Paulo`; datas futuras são recusadas.
- Leitura e confirmação de mutações exigem servidor; filtros, ordenação e totais são locais neste volume inicial.
- Interface inclui listas, formulários, detalhes, categorias arquivadas, filtros, resumo mensal e integração com home/contas.
- Regras preservam perfil e contas, negam exclusões e caminhos desconhecidos e validam referências críticas.
- O campo `occurredAt` representa somente o dia em que o dinheiro entrou ou saiu, abre calendário diário e bloqueia datas futuras pela convenção civil de São Paulo.
- O APK final da etapa foi validado manualmente; Emulator Suite permanece pendente.

## 22. Etapa 4C — Acesso proprietário seguro

Situação em 01/08/2026: concluída e aprovada manualmente. As regras foram publicadas em development, o documento owner foi criado manualmente e o acesso foi validado no APK debug.

- Domínio isolado com `AppRole`, `AppCapability`, `AccessContext`, `MasterAccess`, falhas e contrato de repositório.
- Consulta exclusiva a `system_admins/{uid}` com UID recebido em tempo de execução, `Source.server` e timeout de 12 segundos.
- Estados `idle`, `loading`, `regularUser`, `activeOwner`, `revoked`, `invalidDocument` e `recoverableError` falham fechados.
- Owner recebe todas as capabilities registradas, incluindo preparação para ignorar futuros bloqueios comerciais, de assinatura e de IA destinados a usuários comuns.
- Controles financeiros, isolamento por UID, regras, autenticação, concorrência e limites técnicos permanecem obrigatórios.
- Área `/proprietario`, selo no perfil, atualização manual e revalidação no retorno ao aplicativo foram implementados.
- Regras publicadas em development permitem somente `get` do próprio documento administrativo por usuário verificado e negam listagem e toda escrita.
- Nenhum plano, cobrança, pagamento, loja, limite comercial real ou consumo de IA foi implementado.
- O teste manual confirmou o selo, a Área do proprietário e a autorização server-only. Testes reais das regras no Emulator Suite permanecem pendentes.

## 23. FIN-5A — Compromissos financeiros

Situação em 04/08/2026: FIN-5A concluído, validado e consolidado. Regras do incremento foram publicadas anteriormente somente em development por autorização específica.

- FIN-5A-0 registra coleções `payables` e `receivables`, estados terminais `cancelled` e `voided`, atraso derivado, vínculo bidirecional e compatibilidade de lançamentos esquema 1/2.
- A estratégia recomendada para saldo inicial torna o campo imutável no domínio, repositório e regras e posterga correções para movimento auditável; nenhuma parte dessa estratégia foi implementada sem nova aprovação.
- FIN-5A-1 introduz objeto de data civil de São Paulo, entidades de contas a pagar/receber, invariantes, comandos de liquidação e contratos de repositório sem dependência Firebase.
- FIN-5A-2 implementa mappers estritos, repositório Firestore, liquidação/anulação atômicas, transações esquema 2, regras locais e harness do Emulator Suite em projeto `demo-*`.
- FIN-5A-2B simplifica a avaliação das regras sem mudar o modelo: autenticação/perfil são centralizados, estados e origens usam despacho determinístico, referências usam uma única leitura pós-gravação e os logs locais passam por auditoria contra limite de expressões, excesso de leituras, avaliação interrompida, valores nulos e falhas internas.
- Compromissos pendentes, cancelados ou anulados nunca são somados ao saldo; somente o lançamento ativo vinculado é canônico.
- FIN-5A-3 implementou controllers, providers, páginas, rotas, estados completos e integração ao dashboard, preservando privacidade, retorno seguro e telas pequenas.
- A imutabilidade de `openingBalanceCents` e a operação auditável de ajuste pertencem a incremento futuro separado; nenhuma alteração desse saldo foi feita no FIN-5A-2.

## 24. UI-2 — Design system, temas e dashboard analítico

Situação em 04/08/2026: implementação concluída, validações automatizadas aprovadas e experiência visual aprovada manualmente no celular após a UI-3B.

- Temas claro e escuro completos usam `ColorScheme` e `AppThemeColors`; a preferência Sistema/Claro/Escuro é local e carregada antes de `runApp`.
- O dashboard mantém o saldo atual canônico e deriva indicadores do período sobre lançamentos próprios confirmados, sem escrita ou projeção paralela.
- Filtros móveis cobrem conta, mês atual, mês anterior, ano e intervalo civil; gráficos e listas são atualizados de forma consistente.
- A comparação de receitas/despesas e a rosca por categoria usam `CustomPainter`, exibem texto equivalente e ocultam valores/percentuais quando a privacidade está ativa.
- Contas usam carrossel com monogramas e ícones genéricos. Instituições pertencem ao futuro `ACC-2`, sem Open Finance, logos ou credenciais.
- Reserva de emergência, metas, previsão financeira e comparação anual avançada continuam futuras e não recebem dados fictícios.
- Nenhum domínio financeiro, documento Firestore, Security Rule ou ambiente Firebase faz parte deste incremento.

## 25. UI-3 — Dashboard 3.0 e contas visuais

Situação em 04/08/2026: implementação concluída, aprovada visualmente e publicada na `main` no checkpoint da UI acumulada.

- A direção aprovada é sofisticada e minimalista, com detalhes tecnológicos discretos e sem reprodução literal das referências externas.
- O resumo principal concentra saldo oficial e resultado do período; receitas e despesas ficam em dois indicadores compactos, sem grade 2+1 ou KPI duplicado.
- Filtros móveis incluem conta, mês atual/anterior, ano atual, mês/ano, intervalo personalizado e limpeza explícita. Nenhum filtro grava dados ou recalcula o saldo oficial pelo período.
- A comparação associa valores a duas barras de escala comum. A rosca usa paleta controlada, ranking de quatro categorias e agrupamento real “Outras”.
- Contas no dashboard respeitam 80% da largura, máximo de 280 px e 176 px de altura normal; monogramas substituem instituições ainda inexistentes.
- A tela Contas e carteiras elimina a grande superfície ciano, reduz ações persistentes e apresenta cada conta como cartão financeiro com estado textual e acesso aos detalhes.
- Reserva, metas, previsão, evolução anual não garantida, orçamentos, Open Finance, logos e IA permanecem fora do incremento e não recebem simulação.
- Domínio, repositórios, Firestore, Security Rules, compromissos, saldo inicial, dependências e preferência de tema permanecem inalterados.

## 26. UI-3A — Menu agrupado e ações contextuais

Situação em 04/08/2026: refinamento concluído e publicado na `main` no checkpoint da UI acumulada.

- O cartão Organizar foi substituído por um único botão Menu, que abre bottom sheet rolável com os grupos Organização, Planejamento e Conta e aplicativo.
- Contas e carteiras, Categorias, Lançamentos, Contas a pagar, Contas a receber, Perfil e Aparência preservam as rotas e o retorno seguro existentes; Aparência continua dentro de Perfil.
- Contas e categorias ativas apresentam edição e arquivamento lado a lado; itens arquivados apresentam restauração. Arquivamento exige confirmação e nunca apaga o documento.
- Lançamentos manuais ativos apresentam edição descritiva e cancelamento lado a lado somente nos detalhes. Compromissos pendentes apresentam edição e cancelamento; liquidados apresentam lançamento vinculado e anulação.
- Cancelamento e anulação explicam o impacto no saldo e no histórico. Nenhuma ação destrutiva foi adicionada aos lançamentos recentes do dashboard e nenhuma lixeira é exibida.
- Domínio, repositórios, Firestore, Security Rules, documentos financeiros, saldo, temas, gráficos, filtros e dependências permanecem inalterados.

## 27. UI-3B — Cabeçalho, densidade e comparação por colunas

Situação em 04/08/2026: implementação e APK debug aprovados manualmente no celular; checkpoint Git e publicação da UI acumulada autorizados.

- A Home não apresenta mais a seção Contas e carteiras, o carrossel, Ver todas ou o cartão Adicionar conta. O filtro compacto de conta permanece no topo e continua controlando todos os dados analíticos.
- O Menu agrupado foi movido para o canto superior direito do cabeçalho. Privacidade e troca rápida de tema permanecem visíveis; Perfil e Aparência continuam dentro do painel, sem controle de perfil duplicado.
- Receitas x despesas usa colunas agrupadas de mesma escala e linha de base. Gradiente, topo, face lateral e sombra discretos criam profundidade 2.5D sem perspectiva ou alteração da proporção dos valores.
- Período, valores reais, legenda, resultado textual e descrição acessível acompanham o gráfico. Privacidade, temas e comportamento responsivo continuam obrigatórios.
- Domínio, repositórios, Firestore, Security Rules, Firebase, rotas, filtros e dependências permanecem inalterados.

## 28. DATA-1, PRIV-1 e STORAGE-1 — Incrementos futuros

Situação em 04/08/2026: decisões registradas; somente a auditoria local de STORAGE-1 foi autorizada. Nenhum dos três incrementos foi implementado.

- `DATA-1 — Exclusão segura de itens nunca utilizados` deverá considerar contas sem lançamentos ou compromissos, categorias sem referências, validação segura no servidor, concorrência, Security Rules, histórico e auditoria. Arquivamento/restauração permanecem o único fluxo atual.
- `PRIV-1 — Excluir minha conta e meus dados` deverá exigir reautenticação, coordenação server-side, política de retenção, idempotência, isolamento por UID e confirmação segura. O requisito também permanece rastreado por AUT-007.
- A auditoria `STORAGE-1` constatou persistência Firestore Android no padrão do SDK, limite padrão de 100 MiB, consultas integrais sem paginação e providers financeiros `autoDispose` que mantêm listas completas enquanto observados.
- A proposta futura recomenda limite inicial de 40 MiB, páginas de 50 documentos para históricos, invalidação explícita de estado dependente de UID no logout/troca de usuário e uma opção separada “Limpar dados locais” com bloqueio por operações pendentes e aviso de que nenhum dado remoto será apagado.
- Paginar o histórico não pode tornar saldo e indicadores parciais. A implementação deverá separar páginas visuais das agregações financeiras exatas e aprovar previamente a estratégia de agregação/reconstrução.
- `clearPersistence()` não deve ser chamado no logout comum: exige instância Firestore sem uso, pode eliminar escritas pendentes, não faz sobrescrita segura do disco e requer ciclo de reinicialização controlado.
- Não existem arquivos temporários de runtime nem cache persistente de imagens implementados. A única preferência própria local é `appearance.theme_mode`; a imagem de autenticação é um asset empacotado no APK.
- O tamanho real do banco local não foi medido porque não havia dispositivo Android conectado; essa medição deverá usar apenas diagnóstico autorizado em build debug, sem copiar conteúdo financeiro.

## 29. INV-1A — Carteira de acompanhamento manual

Situação em 09/08/2026: implementação e validações concluídas; Security Rules publicadas exclusivamente em development e APK debug development aprovado manualmente. O checkpoint Git foi autorizado em conjunto com a UI-INV-1B.

- Carteiras podem ser criadas, editadas, arquivadas e restauradas; ativos aceitam ação ou FII, ticker brasileiro maiúsculo, nome, BRL e carteira própria.
- Compras e vendas usam data civil de São Paulo, quantidade em escala 8, preço em escala 6, taxas em centavos e observação opcional. Operações confirmadas são imutáveis e nunca excluídas.
- Custo, preço médio e resultado realizado são reconstruídos deterministicamente com `BigInt`; taxas de compra integram custo e taxas de venda reduzem resultado. Posições zeradas permanecem visíveis.
- Operações são registradas da mais antiga para a mais recente. Cada uma referencia o topo anterior; somente o topo pode ser anulado, restaurando atomicamente o elo e a quantidade anteriores.
- A projeção mínima do ativo (`currentQuantityScaled`, topo e revisão) existe para permitir que Security Rules bloqueiem venda excedente, escrita isolada, repetição e concorrência sem backend agregador.
- O módulo não referencia contas ou lançamentos e não altera saldo, receitas, despesas, compromissos, saldo inicial ou resumo mensal.
- A interface fica em Menu > Patrimônio > Investimentos, compartilha privacidade com a Home e não mostra cotação, valor atual ou rentabilidade não realizada.
- Security Rules foram validadas no Emulator Suite com Project ID `demo-*` e depois publicadas exclusivamente no Firebase development mediante autorização controlada. Nenhuma produção ou dependência nova foi adicionada.
- Cotações, corretoras, Open Finance, dividendos, impostos, eventos corporativos, recomendações, backend e dados fictícios permanecem fora da INV-1A.

## 30. UI-INV-1B — Redesign visual de investimentos

Situação em 09/08/2026: implementação visual concluída sobre a INV-1A; 532 testes Flutter e 40 testes de regras aprovados, logs auditados e APK debug development aprovado manualmente. O checkpoint Git conjunto foi autorizado.

- O cabeçalho preserva retorno seguro, privacidade e ação compacta de criação. O seletor de carteira permanece antes das abas e o gerenciamento reúne criação, edição, arquivamento e restauração.
- Resumo, Ativos e Lançamentos são as únicas abas. Proventos, rentabilidade, rankings, notícias, B3, corretoras, integrações, paywall e cotação não aparecem como recursos disponíveis.
- O cartão principal apresenta somente custo acompanhado, ativos cadastrados, posições abertas, resultado realizado e carteira selecionada.
- O gráfico nativo de evolução agrega compras e vendas efetivamente registradas. A rosca usa custo atual das posições abertas e alterna entre classes e ativos, com legenda textual e privacidade conjunta.
- A lista de ativos possui busca por ticker/nome, filtro Ações/FIIs e ordenação determinística. Lançamentos usam cartões responsivos com filtros por operação, ativo e período, sem tabela horizontal obrigatória.
- A prévia de operação reutiliza tipos escalados e `InvestmentArithmetic` do domínio para valor bruto, taxas, valor final, impacto na quantidade e possível novo preço médio de compra.
- Domínio, dados, controllers de persistência, Firestore, Security Rules, rotas funcionais e separação do saldo permanecem fora do redesign e devem conservar os hashes registrados antes da implementação.
- Referências visuais privadas permanecem em `.codex-tmp/`, ignoradas pelo Git, e não fornecem marca, logo, textos, imagens ou ativos ao aplicativo.
