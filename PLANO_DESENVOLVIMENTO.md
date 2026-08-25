# Plano de desenvolvimento — Meu Gestor Financeiro

## 1. Situação e autoridade

- Especificação oficial integral: ESPECIFICACAO_FUNCIONAL.md.
- Regras permanentes aprovadas: AGENTS.md.
- Modelo detalhado proposto: MODELO_FIRESTORE.md.
- Rastreabilidade: MATRIZ_REQUISITOS.md.
- Data desta revisão: 2 de agosto de 2026.
- Os comandos públicos usam caminhos relativos à raiz do repositório.
- A fundação local autorizada da Etapa 2 foi criada e validada nos limites da seção 16.
- Todas as ações externas de Firebase, Google Cloud e qualquer provedor de IA são exclusivamente manuais pelo solicitante; o agente limita-se a orientar, preparar código autorizado e verificar resultados locais após confirmação. Referências a Gemini nas etapas históricas não representam fornecedor ativo: a ADR-033 exige contrato neutro e nova aprovação antes da escolha.

## 2. Decisões aprovadas

1. Plataforma inicial Android.
2. Arquitetura preparada para Web, Windows e iOS.
3. Uso pessoal e individual na primeira versão.
4. Português do Brasil, moeda BRL, símbolo R$, datas dd/MM/yyyy e fuso America/Sao_Paulo.
5. Flutter, Dart, arquitetura limpa e modular, Riverpod e go_router.
6. Firebase Authentication com e-mail/senha e Google.
7. Cloud Firestore, Cloud Functions, Firebase Cloud Messaging, Firebase App Check, Firebase Crashlytics e Firebase Analytics.
8. IA somente por borda server-side segura e neutra de provedor.
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
32. Um provedor futuro usa Function, Auth, App Check, resposta estruturada e limites configuráveis de uso/saída.
33. Plano anticrise é híbrido: regras decidem e o provedor apenas explica.
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
45. Decisões de provedor de IA, Firebase, serviços pagos, jurídico, dívida, cartão e Analytics são portões das respectivas etapas e não bloqueiam a fundação local.
46. O projeto deve ser operado a partir da raiz do repositório; caminhos absolutos locais não fazem parte da documentação pública.
47. Firebase, Google Cloud e qualquer provedor de IA serão operados manualmente pelo solicitante; o agente não executa autenticação, seleção/criação de projetos, configuração de serviços, credenciais, faturamento ou deploy e nunca solicita segredos no chat.
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
61. O catálogo comercial Google Play aprovado usa somente o produto `meu_gestor_premium`, com planos-base `mensal` e `anual`; não há produtos separados por ciclo.
62. A oferta `teste-3d` é gratuita por três dias/72 horas e existe somente no plano-base mensal; o plano anual não possui teste.
63. O Brasil é o país comercial inicial; R$ 19,90 mensal e R$ 209,90 anual são valores aprovados para configuração no Play Console, nunca preços autoritativos, entitlement ou cobrança local.
64. O cliente somente apresenta preço, moeda, elegibilidade e detalhes retornados pela Play Store; status, token, recibo e relógio do aparelho não concedem Premium.
65. Decisão histórica substituída pelo FREE-1: investimentos manuais e proventos deixaram de ser Premium. B3 e integrações automáticas com corretoras seguem canceladas.
66. Receita ou margem líquida não será estimada a partir do preço bruto: requer taxa Play, impostos, reembolsos e custos Cloud reais.
67. FREE-1 torna gratuitos investimentos, proventos, calculadoras e análises. A infraestrutura de monetização permanece apenas como código inativo e histórico reversível, sem rota, tela, popup, verificação ou chamada no runtime ativo.

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

- `DATA-1A/PRIV-1A + DATA-1B/PRIV-1B — Contratos e backend local de reset financeiro e exclusão segura` estão implementados somente localmente (ADR-027): manifesto fechado, estados, cursor, lock lógico, idempotência, fakes de storage/relógio/sessão/Auth, falhas sanitizadas e recibo anônimo. Não há Function, Firebase Admin, Rule, tela, exclusão real ou limpeza de cache.
- O futuro reset financeiro preservará Authentication, perfil, consentimentos, aparência, entitlement/assinatura e owner; removerá contas, categorias, lançamentos, compromissos, investimentos/operações/proventos e cache financeiro após confirmação server-side.
- A futura exclusão de conta exigirá reautenticação recente, App Check, e-mail confirmado, frase de intenção e UID próprio; bloqueará escritas, apagará dados/referências vinculados, revogará sessões e removerá Firebase Authentication por último. Não cancelará assinatura Google Play; a interface deverá fornecer aviso e gerenciamento oficial. O requisito também permanece rastreado por AUT-007.
- A retenção planejada após conclusão é somente um recibo anônimo por 30 dias; não haverá retenção antifraude sem cobrança real. Backups exigem auditoria aprovada antes de produção.
- O backend local executa uma etapa/lote por vez e persiste o lock antes do primeiro lote. Falha/timeout pode retomar pelo cursor; exclusão chama revogação de refresh tokens e Auth somente após todos os dados. Nenhuma operação descoberta, cancelamento Google Play, TTL ou retenção real foi implementada.
- `PRIV-1C/PRIV-1D` adiciona somente UI local em Perfil > Dados e privacidade, reautenticação por provedor suportado, renovação de token e Rules locais de lock privado. Sem Function, a operação falha fechada e não mostra sucesso nem inicia limpeza local; Rules não foram publicadas.
- `PRIV-1E-A` prepara apenas localmente o codebase Gen 2 `privacy`, Node 22, com as callables `preparePrivacyOperation`, `confirmPrivacyOperation` e `getPrivacyOperationStatus`. Auth, e-mail verificado, App Check, perfil jurídico, UID próprio e `auth_time` de até cinco minutos nas mutações são exigidos na borda. A identidade runtime é parâmetro de deploy, sem e-mail ou Project ID versionado. Flutter passa a usar os plugins oficiais de Callables e App Check, mas nenhuma Function foi publicada e a persistência Admin paginada continua falha-fechada até PRIV-1E-B.
- A auditoria `STORAGE-1` constatou persistência Firestore Android no padrão do SDK, limite padrão de 100 MiB, consultas integrais sem paginação e providers financeiros `autoDispose` que mantêm listas completas enquanto observados.
- A proposta futura recomenda limite inicial de 40 MiB, páginas de 50 documentos para históricos, invalidação explícita de estado dependente de UID no logout/troca de usuário e uma opção separada “Limpar dados locais” com bloqueio por operações pendentes e aviso de que nenhum dado remoto será apagado.
- Paginar o histórico não pode tornar saldo e indicadores parciais. A implementação deverá separar páginas visuais das agregações financeiras exatas e aprovar previamente a estratégia de agregação/reconstrução.
- `clearPersistence()` não deve ser chamado no logout comum: exige instância Firestore sem uso, pode eliminar escritas pendentes, não faz sobrescrita segura do disco e requer ciclo de reinicialização controlado.
- Não existem arquivos temporários de runtime nem cache persistente de imagens implementados. A única preferência própria local é `appearance.theme_mode`; a imagem de autenticação é um asset empacotado no APK.
- O tamanho real do banco local não foi medido porque não havia dispositivo Android conectado; essa medição deverá usar apenas diagnóstico autorizado em build debug, sem copiar conteúdo financeiro.

## 29. INV-1A — Carteira de acompanhamento manual

Situação em 09/08/2026: implementação e validações concluídas; Security Rules publicadas exclusivamente em development e APK debug development aprovado manualmente. O checkpoint Git foi autorizado em conjunto com a UI-INV-1B.

- Carteiras podem ser criadas, editadas, arquivadas e restauradas; ativos aceitam ação ou FII, ticker brasileiro maiúsculo, nome, BRL e carteira própria.
- INV-UX-3 permite excluir somente carteira nova do esquema 2 que nunca teve histórico. `hasHistory` nasce falso, torna-se verdadeiro atomicamente no primeiro ativo e nunca regride; esquema 1 e qualquer carteira histórica permanecem apenas arquiváveis.
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
- Resumo, Ativos e Lançamentos eram as abas aprovadas na UI-INV-1B; o INV-PROV-1 acrescenta somente a quarta aba Proventos. Rentabilidade, rankings, notícias, integrações, paywall e cotação não aparecem como recursos disponíveis. A antiga proposta de integração B3/corretoras foi cancelada e não integra o planejamento.
- O cartão principal apresenta somente custo acompanhado, ativos cadastrados, posições abertas, resultado realizado e carteira selecionada.
- O gráfico nativo de evolução agrega compras e vendas efetivamente registradas. A rosca usa custo atual das posições abertas e alterna entre classes e ativos, com legenda textual e privacidade conjunta.
- A lista de ativos possui busca por ticker/nome, filtro Ações/FIIs e ordenação determinística. Lançamentos usam cartões responsivos com filtros por operação, ativo e período, sem tabela horizontal obrigatória.
- A prévia de operação reutiliza tipos escalados e `InvestmentArithmetic` do domínio para valor bruto, taxas, valor final, impacto na quantidade e possível novo preço médio de compra.
- Domínio, dados, controllers de persistência, Firestore, Security Rules, rotas funcionais e separação do saldo permanecem fora do redesign e devem conservar os hashes registrados antes da implementação.
- Referências visuais privadas permanecem em `.codex-tmp/`, ignoradas pelo Git, e não fornecem marca, logo, textos, imagens ou ativos ao aplicativo.

## 31. INV-PROV-1 — Proventos manuais

Situação em 10/08/2026: implementação e validações concluídas; Security Rules compiladas e publicadas exclusivamente no Firebase development, sem acesso a production, com SHA-256 `8B689BA72FE05B1C04409E00083644D83B2EEACFDDA67A7C8D003B843E102FBE`; APK debug development gerado e aprovado manualmente. Commit e push permaneciam pendentes no momento desta atualização documental.

- Ações aceitam dividendos e JCP; FIIs aceitam rendimentos de FII. O registro pertence a carteira e ativo próprios e usa origem exclusivamente manual.
- O evento nasce previsto, pode ser recebido ou cancelado e, depois de recebido, pode somente ser anulado. Cancelado e anulado preservam o documento e nunca restauram.
- Valores aceitam total em centavos ou quantidade escala 8 vezes valor unitário escala 6, com intermediário `BigInt`, half-up, imposto retido informado e líquido derivado.
- Data-com é opcional; previsão pode ser futura; recebimento efetivo usa data civil de São Paulo e não pode estar no futuro.
- A coleção `investmentIncomeEvents` possui mapper fechado, referências ativas, revisões, mutations idempotentes, timestamps do servidor e confirmação por releitura server-only.
- A quarta aba apresenta resumo líquido, filtros, colunas de 12 meses, distribuição por ativo, lista e histórico mensal/anual somente com dados persistidos. Privacidade, temas, 320 px e fonte a 180% são preservados.
- Proventos não criam receita no núcleo financeiro, não referenciam conta e não alteram saldo, compromissos, posição ou resumo mensal.
- Agenda automática de proventos, amortização, eventos corporativos, cálculo tributário, DARF, notificações, assinatura e integrações permanecem fora deste incremento. A integração B3 e as integrações automáticas com corretoras foram canceladas por decisão do responsável pelo projeto: não constituem requisito, limitação pendente ou incremento futuro, e nenhuma implementação, pesquisa técnica ou preparação arquitetural deve ser iniciada. A futura cotação de mercado com atraso por provedor de dados independente permanece separada dessa decisão.

## 32. SUB-1A — Domínio e contrato de entitlement Premium

Situação em 10/08/2026: domínio puro, contrato, testes e documentação implementados localmente; sem cobrança, persistência, Security Rules, paywall, commit ou push.

- Planos `free`, `monthly` e `annual` não armazenam preço; mensal e anual compartilham as capabilities iniciais. Plano gratuito corresponde à ausência explícita de entitlement.
- O entitlement canônico usa `pending`, `trialing`, `active`, `gracePeriod`, `accountHold`, `paused`, `cancelled`, `expired`, `revoked` e `refunded`, com datas UTC, revisão e esquema validados.
- Fontes são limitadas a Google Play, concessão administrativa e concessão development. Grants serão futuramente emitidos somente pelo backend, com validade, ambiente e auditoria; owner continua restrito ao próprio UID.
- A política recebe capability, intenção e instante confiável injetado e retorna acesso integral, somente leitura ou negado com motivo, validade, carência, cancelamento pendente e necessidade de releitura. A entidade não usa relógio do aparelho.
- Carteiras, ativos, operações e proventos são preservados após perda do Premium. A leitura futura permanece disponível; mutações e cotações são bloqueadas. Nenhum dado é apagado, nenhum preço médio é alterado e contas, saldo e resumo mensal permanecem intactos.
- A política de transições rejeita revisão antiga/repetida, verificação e período regressivos, ambiente/owner divergentes, troca de fonte dentro do mesmo ciclo e restauração de estados terminais. Renovação e nova assinatura após expiração exigem período coerente.
- O contrato cliente oferece somente leitura, observação confirmada, releitura de servidor e diagnóstico sanitizado. Não há métodos para ativar, renovar, revogar, reembolsar ou conceder.
- Não existe produto configurado, compra, Google Play Billing, backend verificador, entitlement Firestore, regra Premium ou paywall. Investimentos continuam acessíveis em development e nenhuma funcionalidade atual passou a exigir Premium.
- A futura proposta `users/{uid}/entitlements/premium` é apenas documental e depende de incremento próprio para backend, persistência, regras, Emulator Suite, custos e autorização.
- A integração B3 e integrações automáticas com corretoras permanecem canceladas e não autorizam pesquisa ou preparação. Cotações atrasadas por provedor independente continuam bloqueadas por licenciamento e pela conclusão segura de SUB-1.

## 33. SUB-1B — Backend development do entitlement Premium

Situação em 10/08/2026: implementação e 717 validações concluídas; Security Rules compiladas e publicadas exclusivamente no Firebase development, sem acesso a production, com SHA-256 `F01E52545F2CE88896A48B28B957BF45F8AE79B0173DF2E20449929FF21532B4`. Backend real, Google Play, produto, cobrança, APK, enforcement, commit e push permanecem ausentes ou pendentes.

- Backend ESM compatível com Node 20+, isolado em `backend/subscriptions/`, sem dependências externas, endpoint ou runtime de nuvem.
- Gateway Google Play abstrato, DTO estrito, fake determinístico e fixtures exclusivamente sintéticas. Pacote, produto, ambiente, conta ofuscada, estados e períodos falham fechados.
- Purchase token permanece transitório; persistência usa impressão digital HMAC versionada e referência de cofre. O cofre recuperável em memória existe somente nos testes; produção exigirá KMS/Secret Manager.
- Processamento transacional protege repetição, concorrência, evento antigo, token vinculado, conflito de UID/ambiente/pacote/produto e timeout antes/depois do commit.
- RTDN local é somente sinal e sempre reconsulta o gateway. Acknowledgement usa outbox idempotente. Não há Pub/Sub, chamada HTTP ou autenticação Google.
- Grants administrativos/development são contratos backend-only, auditados, limitados ao próprio UID, validade, ambiente e capabilities; development nunca atua em production.
- `users/{uid}/entitlements/premium` tem mapper estrito e repositório Flutter somente leitura confirmada pelo servidor. Ausência é explícita e diagnósticos são sanitizados.
- Security Rules locais permitem apenas `get` do próprio `premium` com autenticação, e-mail confirmado e perfil jurídico; negam listagem, escrita, acesso cruzado, subcoleções e coleções internas.
- Investimentos continuam acessíveis no development atual. Paywall, compra, Google Play Billing e aplicação das policies aos módulos permanecem fora do SUB-1B.

## 34. SUB-1C — Enforcement Premium local e modo somente leitura

Situação em 10/08/2026: implementado e validado somente no worktree local com 655 testes Flutter, 27 testes backend e 68 testes do Emulator (750 validações). `firestore.rules` foi alterado localmente, mas não foi publicado; nenhum Firebase real, Google Play, APK, commit ou push foi executado e nenhum usuário development real foi bloqueado.

- `InvestmentPremiumAccessController` relê o entitlement do servidor, rejeita cache/escrita pendente e produz acesso integral, somente leitura, negado ou erro recuperável.
- `investmentsManual` protege carteiras, ativos e operações; `investmentIncome` protege proventos. Cotações, calculadoras e análises continuam sem funcionalidade.
- `PremiumGuardedInvestmentRepository`, controllers e gates de rota impedem contorno por widget ou deep link, bloqueiam resposta tardia/múltiplos toques e não consomem ID quando a autorização falha.
- Regras locais exigem UID próprio, e-mail confirmado, perfil jurídico, entitlement válido, capability e `request.time`; owner não possui bypass. Invariantes financeiras e operações atômicas permanecem intactas.
- Perda de Premium não grava nem apaga dados. Consulta, filtros, privacidade, temas e navegação permanecem; ações mutáveis desaparecem. Ausência nunca é expiração e não carrega dados Premium.
- A tela negada não possui preço, compra ou botão funcional de assinatura. Confirmação indisponível falha fechada e oferece retry com texto sanitizado.
- Publicação depende primeiro de um método backend/administrativo autorizado para emitir entitlements development seguros. SUB-1D/SUB-1E-1 cuidam da preparação local de Google Play, compra e experiência comercial; qualquer configuração externa continua a exigir autorização própria.

## 35. SUB-1D — Interface e preparação Google Play Billing

> Histórico substituído pelo FREE-1. As seções 35 a 40 registram trabalho reversível já realizado, mas não constituem fluxo, bloqueio ou planejamento comercial ativo do aplicativo.

Concluído localmente: contratos de catálogo, compra, restauração, atualizações, verificação, disponibilidade e gerenciamento; página Premium, rota, entradas de Menu/Perfil, gateway Flutter e testes determinísticos. A cobrança continua bloqueada por ausência de produtos Play, backend seguro, identificação ofuscada emitida pelo servidor, App Check, grant development real e publicação autorizada das regras SUB-1C.

O modelo inicial de dois produtos distintos foi substituído pelo catálogo único aprovado no SUB-1E-1. Integração B3/corretoras permanece cancelada. Cotações atrasadas por provedor independente continuam tema separado e não foram iniciadas.

## 36. SUB-1E-1 — Preparação local de cobrança Google Play

Situação em 10/08/2026: autorizado exclusivamente para remodelagem e validação locais. Nenhum produto, preço, oferta, teste, testador, AAB, backend Cloud, Function, App Check, regra, recurso Firebase ou recurso Google Play foi criado ou alterado.

- O catálogo local passa a representar um único produto, `meu_gestor_premium`, com planos-base `mensal` e `anual`; a oferta `teste-3d` é exclusiva do mensal e dura três dias/72 horas. Brasil é o país inicial previsto.
- R$ 19,90 mensal e R$ 209,90 anual são preços aprovados somente para futura configuração no Play Console. O aplicativo não usa preço fixo como autoridade e só apresenta detalhes localizados retornados pela loja.
- Contratos de catálogo, compra, restauração, verificação, gerenciamento e disponibilidade distinguem produto, plano-base e oferta. Resposta da loja, cache, relógio do aparelho, falha de rede, compra pendente, cancelamento ou timeout nunca concedem entitlement.
- O cliente permanece abstrato e testável. O backend local usa fakes/fixtures sintéticas para a futura verificação por Google Play Developer API e RTDN; token continua transitório e nenhum backend Cloud, segredo, endpoint ou chamada externa existe.
- A decisão comercial desta etapa foi substituída pelo FREE-1: investimentos manuais, proventos, calculadoras e análises são gratuitos. Não há B3, corretora, dados fictícios ou integração financeira.
- A margem líquida é indeterminada até a operação real: depende de taxa Play, tributos, reembolsos e custos Cloud. Não há projeção ou promessa de margem de 16–20%.

## 37. SUB-1E-2 — Concessão segura de teste fechado

Situação: preparada e validada somente localmente. Nenhuma concessão foi emitida, nenhum testador foi cadastrado e nenhum recurso Firebase, Google Cloud ou Google Play foi acessado.

- `closedTestGrant` representa validade individual de quinze dias do teste fechado, iniciada pelo relógio UTC confiável do servidor em `development` e track `closed`; não é assinatura, compra, preço, oferta Play ou direito de production.
- O diretório privado de testadores é autorizado e revogado somente por caminho administrativo server-side, sem e-mail no registro. A callable de ativação aceita somente o próprio UID autenticado, e-mail verificado, App Check e perfil jurídico atual; ela não recebe prazo, capability, track ou UID alvo. Não há relógio do aparelho, escrita direta, restauração ou reutilização depois da expiração.
- A concessão e suas capabilities permanecem apenas na infraestrutura histórica. O aplicativo FREE-1 não a solicita, não mede validade e não altera a experiência quando ela expira.
- Production nunca aceitará `closedTestGrant`; após lançamento oficial, somente entitlement verificado da Google Play libera Premium em production.

## 38. SUB-1E-3A — Backend Premium Gen 2 preparado localmente

Situação: borda testável localmente, sem Function, Firebase Admin, App Check, IAM, segredo, Pub/Sub, RTDN real ou acesso externo.

- Factories compatíveis com Functions Gen 2 delegam aos contratos e à persistência transacional já existentes: verificar/restaurar compra futura, consultar entitlement confirmado, receber RTDN como sinal e administrar teste fechado por caminho server-side separado.
- App Check é preparado apenas para as três callables Premium novas. Não há enforcement global nem bloqueio de usuário development atual.
- Firestore, Play Developer API, Pub/Sub, Secret Manager e IAM são adaptadores futuros injetados. A identidade de runtime deverá obedecer menor privilégio e ser separada por development/production; nenhuma chave JSON será usada.
- A recuperação futura faz rollback de rota/código sem apagar entitlement, evento, binding, outbox ou auditoria. Purchase, restauração e grant real continuam bloqueados até autorizações próprias e SUB-1E-3B.

## 39. SUB-1E-3B-1 — Bootstrap Functions Premium development

Situação: publicado exclusivamente em development e republicado com Node 22. O codebase contém três callables Gen 2 em `southamerica-east1`, memória de 256 MiB, timeout de 15 segundos, concorrência 1 e no máximo uma instância. Cada callable usa a identidade runtime Premium já aprovisionada, exige autenticação, token com e-mail confirmado, App Check individual e perfil jurídico atual.

- `getConfirmedEntitlement` devolve apenas o entitlement próprio sanitizado, diretamente de leitura confirmada do servidor.
- `verifyGooglePlayPurchase` e `restoreGooglePlayPurchase` existem apenas como bootstrap e falham fechadas antes de receber token, criar dado ou liberar capability; a implementação comercial permanece no incremento posterior autorizado.
- RTDN, Pub/Sub operacional, Secret Manager, Google Play Developer API, grants administrativos e emissão do teste fechado continuam ausentes. As regras SUB-1E não foram publicadas nem alteradas remotamente.
- O primeiro deploy habilitou apenas APIs de infraestrutura necessárias ao Gen 2. A política de limpeza do Artifact Registry foi posteriormente configurada, por autorização própria, para remover automaticamente apenas imagens de deploy com mais de 14 dias na região das Functions; não foi usado `--force` nem houve exclusão manual.
- O artefato de produção das Functions Premium usa Node 22, `firebase-admin` 14.2.0 e `firebase-functions` 7.3.2. `@google-cloud/firestore` 8.7.1 é dependência direta necessária à leitura Admin; dependências opcionais, incluindo Cloud Storage e `uuid`, são omitidas na instalação de produção. A auditoria da árvore efetivamente instalada com opcionais omitidas não encontrou vulnerabilidades. O lockfile conserva a resolução opcional completa apenas para reprodutibilidade e sua auditoria é informativa.

## 40. SUB-1F-1 — Ativação segura para testadores fechados

Situação: implementada e validada somente localmente. Não houve deploy, publicação de Rules, lista real, concessão real, Firebase, Google Cloud, Play Console, APK, commit ou push.

- `_premiumClosedTestTesters/{uid}` é diretório interno sem e-mail, acessível apenas a serviço administrativo futuro; `_premiumClosedTestGrants` guarda somente a projeção/auditoria sanitizada. As Rules locais negam integralmente leitura, listagem e escrita cliente, inclusive owner cruzado.
- `activateClosedTestPremium` é preparada como callable development que exige autenticação, e-mail verificado, App Check e perfil jurídico atual. O payload é vazio e a ativação só pode tratar o próprio UID, nunca conceder ou consultar dados de outro usuário.
- A primeira ativação autorizada cria `closedTestGrant` de quinze dias individuais no relógio de servidor. A transação é idempotente e concorrente; expiração materializa estado `expired`, remove capabilities sem apagar dados e bloqueia restauração/reutilização.
- Não há compra, cobrança, preço, teste Play de quinze dias, trial comercial de 72 horas, API Play, RTDN, Secret Manager ou produção. O catálogo futuro continua com `meu_gestor_premium`, planos `mensal`/`anual` e `teste-3d` somente mensal.

### ACCESS-INV-DEV-1 — Integração Flutter da concessão fechada

Situação histórica: integração retirada do runtime ativo pelo FREE-1. O código permanece isolado e reversível, sem chamada pelo aplicativo.

- Quando uma releitura server-only confirma ausência de entitlement, somente em `development`, o aplicativo chama `activateClosedTestPremium` uma vez por UID e por processo, com payload estritamente vazio. Production nunca executa essa ativação.
- O cliente não envia UID, ambiente, duração, track, capabilities ou identificador de grant. Auth, e-mail confirmado, App Check, perfil jurídico, autorização privada e relógio permanecem responsabilidades do backend.
- Sucesso da callable não concede acesso local: o entitlement precisa ser relido novamente do servidor, sem cache ou escrita pendente, e passar pela política Premium antes de liberar qualquer rota ou repositório de investimentos.
- A tentativa única é compartilhada no processo para evitar loops, recriações do controller e múltiplos toques. Timeout, App Check inválido, usuário não autorizado, resposta tardia ou entitlement ainda ausente falham fechados e não liberam dados.

## 41. INV-2A — Calculadoras e análises manuais

Situação: implementado localmente, sem API, cotação, Firebase ou escrita na carteira.

- As calculadoras usam somente entradas manuais: primeiro milhão, juros simples e compostos, porcentagem, Graham e Bazin. Valores monetários permanecem em centavos inteiros; percentuais usam pontos-base e as fórmulas/arredondamentos são determinísticos.
- Análises de ações e FIIs, checklist Buy and Hold e comparação exibem somente pontos positivos, atenção ou dados insuficientes conforme marcações manuais. Não há cotação, indicador inventado nem recomendação de compra, venda ou manutenção.
- O módulo é gratuito pelo FREE-1, não salva entradas e nunca altera carteira, posição, provento, conta, saldo, lançamento ou resumo mensal. Resultados são apresentados em modal acessível e detalhado.

## 42. INV-2B — Cotações atrasadas e rentabilidade estimada

Situação: implementação local preparada, sem provedor escolhido, API, chave, Firebase, Scheduler, Function, coleção ou cotação real.

- Cotações são snapshots globais de ação/FII em BRL por ticker, com preço escalado, horário da fonte, captura, atraso e validade declarados. Estados indisponível, inválido, mercado fechado, atrasado e possível evento corporativo são explícitos; resposta sem horário, preço não positivo ou mais antiga é recusada.
- O gateway local é independente de provedor e trabalha em lotes deduplicados, cache global, lease, retry idempotente e circuit breaker. Não há consulta por usuário, chamada de API nem dado fictício no aplicativo.
- Valor estimado, não realizado, realizado e proventos recebidos aparecem separados. Total econômico somente é calculado quando todas as posições abertas têm snapshot compatível; cobertura parcial não simula total nem evolução histórica.
- A experiência usa rota autenticada gratuita e estados honestos de indisponibilidade. Preços, operações, quantidade, preço médio, proventos, contas e saldo nunca são modificados.
- A ativação externa depende de aprovação comercial e técnica separada de provedor de dados atrasados, licença, orçamento/limites, segredo server-side, persistência global de snapshots e job backend. B3 e corretoras permanecem canceladas.

## 43. INV-2C-A + INV-2C-B — Implementação local de cotações atrasadas

Situação: preparada localmente, sem deploy, publicação de Rules, Function, Scheduler, Secret Manager, API, IAM, provedor contratado ou chamada real.

- `backend/quotes` mantém o contrato provider-neutral, o gateway BRAPI opcional e o processador de lote global. O adaptador usa somente `fetch` nativo Node 22, converte preço/variação para inteiros escalados e falha fechada sem token de runtime.
- `backend/functions/quotes` prepara uma Function Gen 2 interna com região `southamerica-east1`, Node 22, 256 MiB, timeout de 30 segundos, concorrência 1, mínimo 0 e máximo 1 instância. A identidade runtime e os segredos são parâmetros não versionados; o endpoint não é chamado pelo aplicativo.
- Os documentos globais `marketQuoteSnapshots/{ticker}` e internos de lease/request/circuit não incluem usuário, carteira, posição, operação, custo, preço médio ou token. Requisições internas usam lote máximo de 50, idempotência, lease e monotonicidade por horário observado.
- Rules locais permitem somente `get` por ticker a usuário autenticado, com e-mail confirmado e perfil jurídico atual; listagem, escrita e acesso a internos são negados, inclusive para owner. Nenhuma capability comercial é consultada. Não há índice composto porque a consulta atual é por ID; qualquer índice futuro será guiado por consulta aprovada.
- A tela recebe somente snapshots server-only já confirmados e preserva estados atrasado, fechado, indisponível, inválido, possível evento corporativo e cobertura parcial. Patrimônio/resultado estimados não substituem custo, operação, provento, conta, saldo ou resumo mensal.
- Antes de ativar: aprovar licença/cobertura e limite do provedor, criar segredo no cofre, configurar identidade runtime e Scheduler interno, revisar custos, publicar Function/Rules em autorização independente e validar com dados não pessoais. B3 e corretoras seguem canceladas como integração.

## 44. CRUD-AUDIT-1 + INV-CALC-2 — ações completas e calculadoras inequívocas

Situação: implementado e validado somente localmente; Rules não publicadas e nenhuma ação externa executada.

- A matriz de ações cobre autenticação, perfil, consentimentos, aparência, núcleo financeiro, compromissos, investimentos, cotações, privacidade e infraestruturas internas. Exclusão, arquivamento, cancelamento e anulação permanecem conceitos distintos.
- Ações somente com ícone usam lápis, lixeira, arquivar e restaurar canônicos, com tooltip, rótulo semântico específico e bloqueio durante processamento. A lixeira não representa cancelamento ou anulação.
- Ativos novos usam schema 2 e `hasHistory=false`. A primeira operação ou provento eleva o marcador atomicamente; documentos schema 1 são históricos por compatibilidade. Nome sempre pode ser corrigido após restauração, tipo só antes do histórico e ticker segue imutável.
- Excluir ativo exige ausência monotônica de histórico, trava por arquivamento, consultas server-only de operações/proventos e transação com revisão. Ativo histórico explica o bloqueio e oferece correção ou arquivamento.
- Primeiro milhão oferece “Descobrir prazo” e “Descobrir aporte”, com prazo desejado em anos e meses. Todos os resultados de calculadoras exibem entradas, unidade da taxa, prazo, fórmula/premissas e decomposição do resultado.
- Juros simples usam taxa anual e dias; compostos usam taxa mensal e meses. Porcentagem de aumento/desconto e variação entre valores são operações separadas. Graham e Bazin identificam LPA, VPA, dividendo anual e yield desejado sem produzir recomendação.

## 45. ASSIST-0 — auditoria e contrato seguro do Assistente Financeiro Pessoal

Situação: domínio, contrato server-side neutro, documentação e testes implementados somente localmente. Não há API de IA, Function, segredo, memória, interface, Rules ou recurso externo.

- O inventário distingue fontes próprias disponíveis, agregados derivados, cotação global atrasada e módulos futuros ausentes. Nenhum dado inexistente pode ser simulado.
- O uso futuro exige Auth, App Check, e-mail verificado, perfil jurídico atual, UID próprio e consentimento IA na versão vigente, confirmado pelo servidor. Owner não possui bypass.
- O cliente envia somente a pergunta. O servidor monta fatos tipados, troca IDs por aliases efêmeros e bloqueia identidade, segredos, dados de terceiro e informações administrativas.
- Memória começa desativada. Persistência futura exigirá consentimento separado, retenção máxima de 90 dias e exclusão/invalidação compatível com retirada, reset e exclusão de conta.
- O assistente pode ler, explicar, comparar e sugerir. Mutações são apenas propostas e dependerão de confirmação exata, recente e revalidação em executor separado. Ações de privacidade, Auth, owner, entitlement e segurança são proibidas.
- Uma etapa conectada dependerá de seleção aprovada de provedor, texto jurídico, Function/IAM/App Check, orçamento, limites, exclusão no provedor e testes adversariais, todos sob autorização própria.
