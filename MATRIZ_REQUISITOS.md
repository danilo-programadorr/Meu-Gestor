# Matriz de requisitos — Meu Gestor Financeiro

## Convenções

- Fonte EF-n corresponde à seção n de ESPECIFICACAO_FUNCIONAL.md.
- P0: base obrigatória, segurança ou integridade financeira.
- P1: funcionalidade obrigatória do produto.
- P2: requisito obrigatório de acabamento, operação ou evolução.
- E1 a E6 correspondem às seis etapas oficiais de PLANO_DESENVOLVIMENTO.md.
- Prioridade define ordem; nenhum requisito desta matriz é descartado.

| ID e fonte | Requisito | Prioridade | Etapa | Critério de aceite | Testes necessários |
|---|---|---:|---:|---|---|
| OBJ-001 EF-1 | Controlar rendas, contas, despesas, financiamentos, parcelas, dívidas, vencimentos, pagamentos, saldos, reservas e metas | P0 | E3-E4 | Todos os domínios possuem cadastro, consulta, atualização permitida e reflexo correto nos cálculos | Unitários, widgets, integração e regras |
| OBJ-002 EF-1 | Oferecer IA personalizada para prevenir atrasos, endividamento e falta para itens essenciais | P1 | E5 | Orientações usam dados reais, são explicáveis e não substituem cálculo determinístico | Functions, integração, privacidade e falhas |
| TEC-001 EF-2 | Usar Flutter, Dart, arquitetura limpa e modular, Riverpod e go_router | P0 | E1-E2 | Camadas e módulos seguem dependências definidas e navegação/estado têm testes | Análise arquitetural, unitários e widgets |
| TEC-002 EF-2 | Usar Authentication, Firestore, Functions, FCM e App Check | P0 | E2-E6 | Cada serviço está configurado por ambiente e coberto por controle de acesso | Emuladores, integração e segurança |
| TEC-003 EF-2 | Usar Crashlytics sem dados sensíveis | P1 | E2-E6 | Falha controlada é recebida sem PII ou conteúdo financeiro | Integração e inspeção de evento |
| TEC-004 EF-2 | Usar Analytics com governança de privacidade | P1 | E2-E6 | Somente eventos aprovados são enviados conforme consentimento/base legal | Integração, consentimento e teste negativo |
| TEC-005 EF-2 | Usar armazenamento seguro local | P0 | E2 | Dados locais permitidos ficam cifrados; segredos Gemini nunca existem no cliente | Unitário, integração Android e inspeção |
| TEC-006 EF-2 | Usar notificações locais | P1 | E4 | Alertas locais são agendados, atualizados e cancelados corretamente | Unitário de agenda e integração Android |
| TEC-007 EF-2 | Funcionar offline e sincronizar depois | P0 | E3 | Leitura cacheada e gravação pendente são indicadas e sincronizam sem duplicação | Integração offline, conflito e reconexão |
| TEC-008 EF-2 | Entregar Android e preparar Web, Windows e iOS | P0 | E1-E2 | Domínio e aplicação não dependem de Android; build inicial é Android | Revisão de dependências e build Android |
| TEC-009 EF-2 | Aplicar BRL, R$, dd/MM/yyyy, pt-BR e America/Sao_Paulo | P0 | E2 | Valores e datas são exibidos e calculados no padrão aprovado | Unitários de locale, widget e timezone |
| TEC-010 EF-2 | Chamar Gemini somente por Cloud Function | P0 | E5 | Cliente não contém chave nem endpoint Gemini direto | Varredura, análise de tráfego e Functions |
| AUT-001 EF-3 | Criar conta por e-mail e senha | P0 | E2 | Conta válida é criada e erros não expõem informação indevida | Widget e integração Auth |
| AUT-002 EF-3 | Login por e-mail e senha | P0 | E2 | Credenciais válidas iniciam sessão e inválidas falham com mensagem segura | Widget, integração e abuso |
| AUT-003 EF-3 | Login com Google | P0 | E2 | Fluxo conclui, cancela e associa a identidade correta | Integração Android e OAuth |
| AUT-004 EF-3 | Recuperar senha | P0 | E2 | Solicitação válida é processada sem enumerar contas desnecessariamente | Integração Auth e segurança |
| AUT-005 EF-3 | Confirmar e-mail | P0 | E2 | Estado verificado é exigido nas rotas definidas e atualizado corretamente | Integração Auth e rotas |
| AUT-006 EF-3 | Logout | P0 | E2 | Sessão termina e rotas protegidas deixam de ser acessíveis | Integração e navegação |
| AUT-007 EF-3,21 | Excluir conta e dados | P0 | E6 | Fluxo reautenticado remove dados conforme política e registra resultado seguro | Functions, integração, idempotência e retenção |
| AUT-008 EF-3,21 | Aceitar termos, política e consentimentos | P0 | E2 | Versão, data e escolhas são registradas antes dos recursos aplicáveis | Widget, integração e auditoria |
| AUT-009 EF-3 | Isolar dados por usuário | P0 | E2-E6 | Nenhum usuário lê ou altera dados de outro | Security Rules positivas e negativas |
| REN-001 EF-4 | Cadastrar rendas fixas e extras com todos os campos especificados | P0 | E3 | Descrição, categoria, valor, datas, recorrência, status, forma, conta, observação e comprovante persistem com validação | Modelo, widget, integração e regras |
| REN-002 EF-4 | Suportar status previsto, recebido, atrasado e cancelado | P0 | E3 | Transições válidas funcionam e inválidas são negadas | Unitários de estado e regras |
| REN-003 EF-4,24 | Registrar nível de confiança de renda prevista | P0 | E3 | Toda renda prevista tem nível válido usado nos cálculos | Unitário, widget e integração |
| REN-004 EF-4,20 | Gerar renda mensal automaticamente sem duplicação | P0 | E3 | Uma competência gera no máximo uma ocorrência por regra | Functions, idempotência e meses curtos |
| REN-005 EF-4,21 | Proteger comprovante opcional | P1 | E3-E6 | Upload, leitura, remoção e retenção respeitam proprietário e limites | Storage Rules, integração e tipo/tamanho |
| DES-001 EF-5 | Cadastrar contas a pagar nas categorias listadas | P0 | E3 | Usuário cadastra categorias previstas e outras despesas sem perder classificação | Widget, integração e categorias |
| DES-002 EF-5 | Persistir todos os campos de conta especificados | P0 | E3 | Valores, datas, parcelas, prioridade, juros, multa, desconto, pagamento, código, observação e anexo são validados | Modelo, widget, integração e regras |
| DES-003 EF-5 | Suportar status pendente, pago, parcial, atrasado, renegociado e cancelado | P0 | E3 | Transições e saldos restantes são consistentes e auditáveis | Unitários de estado, integração e concorrência |
| DES-004 EF-5 | Suportar prioridades essencial, alta, média, baixa e adiável | P0 | E3 | Prioridade persiste e alimenta risco, IA e plano anticrise | Unitário e integração |
| DES-005 EF-5,20 | Gerar conta recorrente mensal sem duplicação | P0 | E3 | Cada competência tem uma ocorrência única e rastreável | Functions, idempotência e timezone |
| DES-006 EF-5,21 | Tratar código de barras e anexos com segurança | P1 | E3-E6 | Dados são sanitizados, limitados e ausentes de logs | Validação, Storage Rules e inspeção de logs |
| CTA-001 EF-6 | Cadastrar conta corrente, poupança, dinheiro, carteira digital e outras | P0 | E3 | Tipos podem ser criados, editados e arquivados com saldo correto | Unitário, widget, integração e regras |
| CTA-002 EF-6,24 | Manter lançamentos manuais e preparar futura Open Finance | P0 | E1-E3 | Não há integração bancária; contratos permitem adaptador futuro sem alterar domínio | Revisão arquitetural e de dependências |
| CTA-003 EF-24 | Transferir entre contas sem criar receita ou despesa | P0 | E3 | Consolidado não muda e operação é atômica | Unitário, integração, concorrência e regras |
| CAR-001 EF-6 | Cadastrar cartão com limite, fechamento e vencimento | P0 | E4 | Campos válidos geram ciclo e limite corretos | Unitários de calendário, widget e regras |
| CAR-002 EF-6 | Calcular limite total, utilizado e disponível sem tratá-lo como dinheiro | P0 | E4 | Limites conferem com compras/faturas e não entram no saldo | Unitários e integração |
| CAR-003 EF-6 | Registrar compras parceladas e faturas futuras | P0 | E4 | Parcelas são distribuídas nas faturas corretas sem divergência | Unitários, integração e idempotência |
| CAR-004 EF-6 | Permitir pagamento integral e parcial de fatura | P0 | E4 | Pagamentos reduzem obrigação e conta sem duplicar despesa | Unitários, integração e concorrência |
| CAR-005 EF-6 | Calcular juros estimados e melhor dia de compra | P1 | E4 | Resultado segue regra aprovada e expõe premissas | Unitários de ciclo e juros |
| DSH-001 EF-7 | Mostrar os 17 indicadores do painel | P0 | E3-E4 | Cada indicador especificado aparece e é rastreável à origem | Unitários de agregação, widget e integração |
| DSH-002 EF-7 | Exibir risco saudável, atenção, risco e crítico | P1 | E3 | Classificação segue limiares aprovados e explica o motivo | Unitários de risco e widget |
| DSH-003 EF-7 | Não depender somente de cor | P0 | E2-E3 | Indicadores usam texto, ícone e semântica acessível | Widget, contraste e leitor de tela |
| LIN-001 EF-8 | Exibir linha do tempo com saldos e eventos cronológicos | P1 | E3 | Cada evento mostra impacto e saldo posterior em ordem determinística | Unitário de ordenação, widget e integração |
| LIN-002 EF-8 | Identificar antecipadamente primeiro saldo negativo | P1 | E3 | Data negativa confere com a projeção e abre eventos causadores | Unitário de projeção e integração |
| PRJ-001 EF-9 | Projetar 30 dias, 3, 6 e 12 meses | P0 | E3 | Os quatro horizontes são calculados a partir da mesma data-base | Unitários, integração e regressão |
| PRJ-002 EF-9 | Considerar todos os itens listados na projeção | P0 | E3-E4 | Rendas, contas, parcelas, dívidas, reajustes, atrasos, metas, reservas e saldo entram conforme regra | Unitários por componente e integração |
| PRJ-003 EF-9 | Exibir os sete resultados da projeção | P1 | E3 | Menor saldo, riscos, déficits, sobras, comprometimento, capacidade e gasto seguro conferem | Unitário, widget e integração |
| PRJ-004 EF-9 | Informar baixa confiança sem dados suficientes | P0 | E3 | Sistema não inventa valor e explica dados ausentes | Unitários de ausência e widget |
| COM-001 EF-10 | Receber os sete dados de Posso comprar? | P1 | E4 | Formulário valida produto, valores, parcelas, data e prioridade | Widget e validação |
| COM-002 EF-10 | Responder aos oito impactos solicitados | P1 | E4 | Resposta cobre orçamento, sobra, riscos, mês, parcela, espera, data e reserva | Unitários de decisão, widget e integração |
| COM-003 EF-10 | Basear resultado apenas em dados reais | P0 | E4 | Ausência de dados reduz confiança e nenhum dado é inventado | Unitários, integração e teste negativo |
| SIM-001 EF-11 | Simular os onze tipos de cenário listados | P1 | E4 | Cada tipo altera somente premissas do cenário | Unitários por cenário e widget |
| SIM-002 EF-11 | Não alterar dados reais antes da confirmação | P0 | E4 | Simulação isolada não grava em coleções reais | Integração, regras e teste negativo |
| SIM-003 EF-11 | Comparar situação atual, simulada e impactos | P1 | E4 | Comparação mostra diferença mensal, saldo, essenciais e metas | Unitários, widget e integração |
| IAF-001 EF-12 | Integrar Gemini por Function segura | P0 | E5 | Function exige Auth, App Check e payload válido | Functions, segurança e abuso |
| IAF-002 EF-12,21 | Minimizar dados pessoais e financeiros enviados | P0 | E5 | Payload contém somente campos aprovados e estruturados | Privacidade, contrato e integração |
| IAF-003 EF-12 | Analisar os onze grupos de dados listados | P1 | E5 | Análise usa dados disponíveis e declara ausências | Unitário de montagem e integração |
| IAF-004 EF-12 | Gerar as onze categorias de sugestão listadas | P1 | E5 | Resultado estruturado cobre sugestões aplicáveis sem genericidade | Contrato, integração e avaliação |
| IAF-005 EF-12 | Explicar problema, evidências, ação, impacto, urgência, riscos e alternativas | P0 | E5 | Todos os campos obrigatórios existem ou justificam não aplicação | Validação de esquema e integração |
| IAF-006 EF-12 | Nunca inventar receitas, despesas, juros, datas ou saldos | P0 | E5 | Resposta é confrontada com o contexto e rejeitada quando contém fatos não suportados | Avaliação, casos adversariais e fallback |
| IAF-007 EF-12 | Informar dados faltantes e aviso educacional | P0 | E5 | Resposta lista lacunas e contém disclaimer aprovado | Integração e widget |
| CRI-001 EF-13 | Gerar plano anticrise quando faltar dinheiro | P1 | E5 | Déficit elegível dispara plano sem alterar dados reais | Unitário de gatilho e integração |
| CRI-002 EF-13 | Cumprir as dez ações do plano | P1 | E5 | Plano protege essenciais, prioriza riscos e mostra semana, mês e recuperação | Unitários, contrato IA/domínio e widget |
| CRI-003 EF-13 | Explicar efeitos antes de sugerir inadimplência | P0 | E5 | Nenhuma sugestão de não pagamento aparece sem efeitos e alternativas | Avaliação de segurança e conteúdo |
| CRI-004 EF-13 | Não priorizar empréstimo e comparar seis fatores quando analisado | P0 | E5 | Empréstimo não é primeira solução e comparação cobre todos os fatores | Unitários e avaliação de recomendações |
| DIV-001 EF-14 | Implementar avalanche, bola de neve e método personalizado | P1 | E4-E5 | Três estratégias produzem ordem conforme regras aprovadas | Unitários de ordenação e integração |
| DIV-002 EF-14 | Mostrar quitação, juros, mensalidade, ordem, economia e extras | P1 | E4 | Todos os resultados são calculados e rastreáveis | Unitários financeiros e widget |
| DIV-003 EF-14 | Explicar vantagens e desvantagens | P1 | E5 | Comparação apresenta benefícios, limitações e dados ausentes | Conteúdo estruturado e widget |
| NOT-001 EF-15 | Criar os onze tipos de alerta | P1 | E4 | Cada evento elegível gera alerta configurável correto | Unitários por evento e integração |
| NOT-002 EF-15 | Suportar 10, 7, 3 e 1 dias, no dia e após atraso | P1 | E4 | Antecedências respeitam fuso e preferências | Unitários de datas e integração |
| NOT-003 EF-15 | Usar notificações locais e FCM | P1 | E4 | Canais entregam ao dispositivo correto e respeitam permissão | Integração Android, Functions e FCM |
| NOT-004 EF-15,20 | Verificar vencimentos sem notificações duplicadas | P0 | E4 | Chave de deduplicação impede repetição por evento/canal/faixa | Functions, idempotência e concorrência |
| ORC-001 EF-16 | Definir orçamento mensal por categoria | P1 | E4 | Limite é único por categoria/período e validado em centavos | Widget, integração e regras |
| ORC-002 EF-16 | Mostrar definido, usado, disponível, percentual e previsão | P1 | E4 | Valores conferem com despesas válidas do período | Unitários e integração |
| ORC-003 EF-16 | Alertar em 70, 90, 100 e excedente | P1 | E4 | Cada faixa gera no máximo um alerta por período | Unitário, Functions e deduplicação |
| MET-001 EF-17 | Criar metas nos tipos listados com todos os campos | P1 | E4 | Meta persiste nome, valores, prazo, prioridade, contribuição, progresso e conta | Modelo, widget, integração e regras |
| MET-002 EF-17 | Calcular viabilidade | P1 | E4 | Viabilidade usa renda livre e premissas exibidas | Unitários e integração |
| MET-003 EF-17 | Sugerir contribuição compatível | P1 | E4-E5 | Sugestão não excede renda disponível calculada | Unitário, widget e avaliação |
| REL-001 EF-18 | Gerar os treze relatórios listados | P1 | E6 | Cada relatório confere com registros e filtros | Unitários, integração e reconciliação |
| REL-002 EF-18 | Filtrar por dia, semana, mês, ano, categoria, conta e status | P1 | E6 | Combinações suportadas retornam apenas dados elegíveis | Integração, índices e desempenho |
| REL-003 EF-18 | Exportar PDF, CSV e planilha Excel | P1 | E6 | Arquivos completos abrem em leitores compatíveis e conferem com relatório | Testes de formato, integração e segurança |
| DAT-001 EF-19 | Usar as coleções base sugeridas | P0 | E1-E3 | Modelo contém users, accounts, incomes, expenses, cards, invoices, installments, debts, budgets, goals, notifications, analyses, simulations e categories | Revisão de esquema e integração |
| DAT-002 EF-19 | Definir modelo Dart, campos, tipos e obrigatoriedade | P0 | E1-E3 | Cada coleção possui DTO tipado e rejeita documento inválido | Unitários de conversor |
| DAT-003 EF-19 | Definir índices, validações e conversores | P0 | E1-E6 | Consultas aprovadas têm índices e validação cliente/servidor | Emulador, integração e análise |
| DAT-004 EF-19 | Usar timestamps de servidor | P0 | E2-E6 | Campos técnicos protegidos usam servidor e permanecem coerentes | Regras e integração |
| DAT-005 EF-19 | Identificar proprietário e restringir leitura/gravação | P0 | E2-E6 | ownerId é imutável e acesso cruzado é negado | Security Rules |
| FUN-001 EF-20 | Gerar rendas e contas recorrentes | P0 | E3 | Execução repetida não duplica competência | Functions e idempotência |
| FUN-002 EF-20 | Atualizar atrasos, projeções e resumos mensais | P0 | E3-E4 | Resultados são reconstruíveis e possuem watermark/data | Functions, integração e regressão |
| FUN-003 EF-20 | Verificar alertas e enviar notificações | P0 | E4 | Apenas eventos elegíveis são enviados uma vez | Functions, FCM e deduplicação |
| FUN-004 EF-20 | Processar Gemini e limitar solicitações | P0 | E5 | Rate limit, timeout, consentimento e App Check são aplicados | Functions, carga e abuso |
| FUN-005 EF-20 | Registrar auditoria sem dados sensíveis | P0 | E3-E6 | Eventos críticos têm requestId e nenhum dado proibido | Unitário e inspeção de logs |
| FUN-006 EF-20 | Excluir dados do usuário com segurança | P0 | E6 | Processo cobre Auth, Firestore, Storage e tokens e pode retomar | Functions, idempotência e falhas parciais |
| FUN-007 EF-20,29.15 | Reservar extensão futura para exportações grandes | P2 | E6 | Nenhuma Function/Storage é usada na primeira versão; extensão só nasce após nova aprovação | Auditoria de arquitetura e teste negativo de tráfego |
| SEG-001 EF-21 | Aplicar App Check e regras restritivas | P0 | E2-E6 | Requisição inválida é negada e regra começa em deny-all | Integração e Security Rules |
| SEG-002 EF-21 | Validar no aplicativo e servidor e sanitizar entradas | P0 | E2-E6 | Payload inválido é recusado em todas as fronteiras | Unitários, widgets, regras e Functions |
| SEG-003 EF-21 | Proteger chaves e segredos fora do cliente/Git | P0 | E2-E6 | Varredura encontra zero segredos e IAM é mínimo | Secret scan e revisão IAM |
| SEG-004 EF-21 | Limitar requisições e impedir abuso | P0 | E5 | Limites por usuário/dispositivo rejeitam excesso com erro seguro | Carga, rate limit e App Check |
| SEG-005 EF-21 | Manter logs sem dados financeiros sensíveis | P0 | E2-E6 | Logs, Crashlytics e auditoria não contêm campos proibidos | Inspeção automatizada e manual |
| SEG-006 EF-21 | Exportar e excluir conforme retenção | P0 | E6 | Usuário exerce direitos e recebe status do processo | Integração LGPD e Functions |
| SEG-007 EF-21 | Oferecer consentimento e opção sem IA | P0 | E2-E5 | IA não recebe dados quando desativada | Widget, integração e teste negativo |
| SEG-008 EF-21 | Tratar anexos com segurança | P0 | E3-E6 | Arquivo fora de tipo/tamanho ou de outro usuário é negado | Storage Rules e malware policy |
| UX-001 EF-22 | Usar linguagem simples e explicar termos complexos | P1 | E2-E6 | Revisão confirma textos compreensíveis ao público-alvo | Conteúdo, usabilidade e acessibilidade |
| UX-002 EF-22 | Oferecer modo claro/escuro e fonte ajustável | P1 | E2 | Preferências funcionam sem perda de legibilidade | Widget, golden e acessibilidade |
| UX-003 EF-22 | Aplicar máscaras monetárias | P0 | E2-E6 | Entrada e exibição BRL preservam centavos exatos | Unitários e widgets |
| UX-004 EF-22 | Confirmar exclusão e oferecer filtros/pesquisa | P1 | E2-E6 | Ações destrutivas exigem confirmação e consultas respeitam filtros | Widget e integração |
| UX-005 EF-22 | Exibir vazios orientativos e erros compreensíveis | P1 | E2-E6 | Estados vazio/erro orientam próxima ação sem dados fictícios | Widget e conteúdo |
| UX-006 EF-22 | Oferecer tutorial inicial | P2 | E2 | Tutorial pode ser concluído, pulado e revisto | Widget e integração |
| UX-007 EF-22,29 | Oferecer demonstração controlada somente em development/testes | P2 | E2 | Desativada por padrão, sem PII, apagável e tecnicamente impedida de usar Firebase production | Isolamento, configuração, limpeza e teste negativo de produção |
| TEL-001 EF-23 | Implementar as 30 telas mínimas enumeradas | P1 | E2-E6 | Todas as telas existem, são alcançáveis conforme permissão e cobrem estados | Navegação, widgets e integração |
| CAL-001 EF-24 | Centralizar cálculos em serviços próprios | P0 | E1-E3 | Nenhum cálculo financeiro crítico fica em widget ou IA | Unitários e revisão arquitetural |
| CAL-002 EF-24 | Calcular saldo atual pela soma das contas | P0 | E3 | Resultado reconcilia com contas e movimentos | Unitários e integração |
| CAL-003 EF-24 | Calcular saldo projetado pela fórmula oficial | P0 | E3 | Resultado usa saldo, receitas previstas e despesas previstas corretas | Unitários e regressão |
| CAL-004 EF-24 | Calcular dinheiro livre pela fórmula oficial | P0 | E3 | Resultado considera confiança, essenciais, pendências e reservas | Unitários de cenários |
| CAL-005 EF-24 | Calcular renda comprometida pela fórmula oficial | P0 | E3 | Percentual usa obrigatórias e renda confiável sem divisão inválida | Unitários e limites |
| CAL-006 EF-24 | Diferenciar quatro conceitos de saldo/dinheiro | P0 | E3 | Interface e domínio nunca usam os conceitos como sinônimos | Unitários, widgets e conteúdo |
| CAL-007 EF-24,25 | Usar centavos inteiros e evitar erro de ponto flutuante | P0 | E2-E6 | Persistência e cálculo não usam double monetário | Unitários, conversores e varredura |
| TST-001 EF-25 | Criar testes unitários e de cálculos | P0 | E2-E6 | Regras normais, limites e regressões passam | Suíte Dart |
| TST-002 EF-25 | Criar testes de widgets | P0 | E2-E6 | Formulários, estados e acessibilidade passam | Flutter widget tests |
| TST-003 EF-25 | Criar testes de integração | P0 | E2-E6 | Jornadas críticas passam no Android e emuladores | integration_test |
| TST-004 EF-25 | Testar Firestore Rules e Functions | P0 | E2-E6 | Casos permitidos/negados, funções e falhas passam localmente | Emulator Suite |
| TST-005 EF-25 | Testar recorrência e duplicidade | P0 | E3-E4 | Reexecução não duplica renda, conta, parcela ou alerta | Idempotência e concorrência |
| TST-006 EF-25 | Testar fuso, arredondamento e meses de tamanhos diferentes | P0 | E2-E6 | Casos de 28 a 31 dias e viradas preservam valores/datas | Unitários parametrizados |
| PRO-001 EF-26 | Respeitar a ordem oficial das seis etapas | P0 | E1-E6 | Nenhuma etapa posterior é iniciada antes do portão aprovado | Auditoria documental |
| PRO-002 EF-27 | Entregar arquivos completos e informar caminho, finalidade, dependências e comandos | P0 | E2-E6 | Cada entrega contém os quatro itens e não possui marcador incompleto | Revisão de entrega |
| PRO-003 EF-27 | Verificar imports, classes, compatibilidade, regras e pubspec antes de avançar | P0 | E2-E6 | Checklist passa e duplicidade de chave é ausente | Analyze, testes e revisão |
| PRO-004 EF-27 | Usar PowerShell, um comando por linha e sem encadear com && | P0 | E1-E6 | Todos os comandos entregues seguem o padrão | Revisão textual |
| RES-001 EF-28 | Entregar aplicativo funcional, simples, preventivo e seguro | P0 | E6 | Critérios de negócio, segurança, usabilidade e testes estão aprovados | Aceite ponta a ponta e piloto |
| APR-001 EF-29.2 | Modelar contas a receber separadas de rendas | P0 | E3 | Coleção receivables contém campos/status aprovados e recebimento vincula renda exatamente uma vez | Modelo, regras, integração e idempotência |
| APR-002 EF-29.3 | Usar movimentos de meta como fonte da reserva | P0 | E3-E4 | Reserva integra saldo bancário, sai do dinheiro livre e só é liberada com confirmação | Unitários, integração e reconstrução de resumo |
| APR-003 EF-29.4 | Aplicar quatro pesos de confiança centralizados | P0 | E3 | Nominal usa 100% e conservadora usa 100/80/50/20; cancelada/atrasada sem previsão usa zero | Unitários parametrizados e integração |
| APR-004 EF-29.5 | Classificar risco por regras determinísticas aprovadas | P0 | E3 | Nível mais grave prevalece e fatos causadores são exibidos | Unitários por condição, combinações e widget |
| APR-005 EF-29.6 | Ajustar recorrência ao último dia do mês | P0 | E3 | Dias inexistentes geram no último dia em São Paulo com competência/chave únicas | Datas 28-31, leap year e idempotência |
| APR-006 EF-29.7 | Aplicar fechamento de cartão aprovado | P0 | E4 | Antes do fechamento vai à atual; no dia/depois à próxima; melhor dia é o seguinte | Unitários de ciclo, integração e correção auditada |
| APR-007 EF-29.8 | Nunca inferir taxas e usar pontos-base | P0 | E3-E4 | Taxa vem do usuário/regra ou fica desconhecida com aviso de imprecisão | Unitários, widget e persistência |
| APR-008 EF-29.9 | Tornar pagamentos parciais imutáveis | P0 | E3-E4 | Total/restante/status derivam dos registros; correção usa cancelamento/compensação | Unitários, auditoria, integração e concorrência |
| APR-009 EF-29.10 | Alertar gasto acima da média aprovada | P1 | E4 | Usa três meses completos e alerta com aumento mínimo de 20% e R$ 50 | Unitários de histórico, limites e ausência de dados |
| APR-010 EF-29.11 | Perguntar sobre uso de assinatura antes de recomendar | P1 | E4-E5 | Sem resposta, sistema não afirma desuso; após resposta pode orientar | Widget, estado, notificações e avaliação IA |
| APR-011 EF-29.12 | Confirmar operações críticas offline somente no servidor | P0 | E3-E4 | Preparação offline permanece pendente; sincronização valida revisão e conflito é explícito | Offline, concorrência, reconexão e UX de conflito |
| APR-012 EF-29.13 | Aplicar simulação somente após prévia e confirmação | P0 | E4 | Prévia lista criações/alterações e impactos; aplicação é atômica e auditável | Unitário, integração, transação e rollback |
| APR-013 EF-29.14 | Restringir anexos a PDF/JPEG/PNG, 10 MB e cinco | P0 | E3-E6 | Extensão, MIME e assinatura conferem; executável/compactado/URL pública são negados | Storage Rules, assinatura, limite e acesso cruzado |
| APR-014 EF-29.15 | Gerar exportações localmente na primeira versão | P1 | E6 | CSV/Excel são locais; PDF local respeita memória; nenhum upload ocorre só para exportar | Formatos, memória, arquivos e inspeção de tráfego |
| APR-015 EF-29.16 | Aplicar controles Gemini aprovados | P0 | E5 | Auth/App Check, schema, timeout, custo, 10/dia, cerca de 2.000 tokens e minimização funcionam | Functions, carga, abuso, contrato e privacidade |
| APR-016 EF-29.17 | Usar plano anticrise híbrido | P0 | E5 | Domínio decide valores/prioridades; Gemini só explica, organiza, oferece alternativas e pergunta | Unitários sem IA, contrato e testes adversariais |
| APR-017 EF-29.18 | Desativar Analytics até consentimento e separar consentimento IA | P0 | E2-E6 | Retirada interrompe eventos; IA recusada não bloqueia finanças; logs não contêm dados proibidos | Consentimento, Analytics, Crashlytics e teste negativo |
| APR-018 EF-29.19 | Aplicar retenções iniciais aprovadas | P0 | E5-E6 | IA/notificações expiram em 90 dias, auditoria em 180 e órfãos em 30 | TTL/limpeza, relógio, Functions e auditoria |
| APR-019 EF-29.19 | Excluir conta com reautenticação e abrangência aprovada | P0 | E6 | Novas operações param, dados/anexos somem, dispositivos revogam e janela de backup é informada | Functions, falhas parciais, retomada e integração |
| APR-020 EF-29.20 | Planejar backup de produção por 30 dias | P1 | E6 | Restauração documentada/testada, acesso/custo/autorizador definidos antes de ativar | Ensaio de restauração e controle de acesso |
| APR-021 EF-29.21 | Usar notificação genérica na tela bloqueada | P0 | E4 | Payload padrão não contém valor/nome/dívida/saldo/descrição; detalhe exige opção informada | Payload, integração Android e privacidade |
| APR-022 EF-29.22 | Impedir faturamento sem aprovação | P0 | E1-E6 | Nenhum billing é vinculado antes de estimativa, alertas, ambientes e autorização | Auditoria de configuração e checklist |
| APR-023 EF-29.23 | Usar o identificador Android definitivo `br.com.hellenfaro.meugestorfinanceiro` | P0 | E1-E2 | Documentação registra o identificador exato; quando a Etapa 2 for autorizada, o projeto e as configurações Android usam o mesmo applicationId sem variações | Auditoria documental; teste da configuração Android após autorização da Etapa 2 |
| APR-024 EF-30.1 | Usar o nome Dart `meu_gestor_financeiro` e o nome exibido Meu Gestor Financeiro | P0 | E2 | pubspec, pacote, AndroidManifest e aplicação usam os nomes aprovados | Inspeção de configuração, analyze e teste de widget |
| APR-025 EF-30.2 | Calcular saldo exclusivamente pelos movimentos canônicos aprovados | P0 | E3 | Saldo reconcilia saldo inicial, entradas, saídas e transferências confirmadas sem depender de cache | Unitários, integração, reconstrução e concorrência |
| APR-026 EF-30.2 | Tratar saldos calculados e monthlySummaries como caches protegidos e reconstruíveis | P0 | E3-E6 | Apagar e reconstruir caches produz o mesmo resultado canônico e cliente não os altera | Reconstrução, regras, idempotência e regressão |
| APR-027 EF-30.3 | Restringir conta sem e-mail confirmado aos seis fluxos aprovados | P0 | E2-E3 | Nenhuma leitura/escrita financeira ocorre antes de emailVerified=true; Google segue o token Auth | Auth, rotas, regras e integração negativa |
| APR-028 EF-30.4 | Modelar reajuste fixo ou percentual com vigência e entidade | P0 | E3 | Apenas um valor é aceito, vigência e vínculo são obrigatórios e somente ocorrências futuras mudam | Modelo, unitários, regras e recorrência |
| APR-029 EF-30.4 | Exigir confirmação e auditoria para reajuste retroativo | P0 | E3 | Prévia e confirmação precedem operações idempotentes e auditáveis | Integração, auditoria, cancelamento e idempotência |
| APR-030 EF-30.5 | Usar as sete formas iniciais de recebimento aprovadas | P0 | E3 | Somente pix, transferência bancária, dinheiro, cartão, boleto, cheque e outro são aceitos | Enumeração, conversão, widget e regras |
| APR-031 EF-30.6 | Usar as oito formas iniciais de pagamento aprovadas | P0 | E3-E4 | Somente pix, transferência bancária, dinheiro, débito, crédito, boleto, débito automático e outro são aceitos | Enumeração, conversão, widget e regras |
| APR-032 EF-30.7 | Manter decisões adiadas como portões das etapas correspondentes | P0 | E2-E6 | Nenhum módulo ou serviço cruza seu portão sem decisão/autorização registrada | Auditoria documental e checklist de etapa |
| APR-033 EF-30.8 | Limitar este incremento à fundação local autorizada da Etapa 2 | P0 | E2 | Projeto Android executável e testado não contém Firebase, Gemini, serviços pagos, deploy ou funcionalidade financeira | Inspeção de dependências, analyze, testes e auditoria de comandos |

## Cobertura

- Seções EF-1 a EF-28 estão relacionadas.
- Exemplos de categorias, rendas, despesas, metas e simulações são cobertos pelos requisitos de cadastro correspondentes.
- Campos e enumerações completos são detalhados em ESPECIFICACAO_FUNCIONAL.md e MODELO_FIRESTORE.md.
- Requisitos bloqueados por decisão permanecem na matriz e não podem ser descartados silenciosamente.

## Rastreabilidade do incremento Etapa 3B

| Requisito | Situação | Critério verificado | Testes locais | Dependência externa pendente |
|---|---|---|---|---|
| TEC-002 | parcial autorizado | Core/Auth Android inicializados por configuração development; Firestore sem operações | inicialização sucesso/falha/bloqueio | teste manual no projeto Firebase development |
| AUT-001 | implementado | conta atualiza displayName, envia verificação e bloqueia área protegida | controlador, validação e rotas | conta de teste criada manualmente pelo solicitante |
| AUT-002 | implementado | login possui validação, carregamento, erro seguro e deduplicação | controlador e widgets | teste manual com credencial development |
| AUT-003 | implementado | Google trata sucesso, cancelamento, credencial ausente, rede e falha | controlador com fake e fluxo de widget | teste manual com conta Google escolhida pelo solicitante |
| AUT-004 | implementado | resposta de recuperação não enumera usuário | controlador e widget | entrega de email no Firebase development |
| AUT-005 | implementado | estado `emailVerified` controla rotas; reenvio tem cooldown | rotas, máscara, reenvio e atualização | abertura do link real de confirmação |
| AUT-006 | implementado | logout encerra sessão e retorna ao fluxo público | controlador e rota | validação manual no Android |
| AUT-008 | parcial | aceite obrigatório e textos provisórios development | validação de consentimentos e navegação | textos jurídicos oficiais e persistência de consentimento |
| AUT-009 | parcial | nenhuma área financeira é acessível sem verificação | redirecionamentos | Security Rules em etapa autorizada futura |
| UX-002 | implementado na fundação | temas claro/escuro e escala de texto sem overflow | tema, tela compacta, teclado e fonte 1,6 | validação manual Android aprovada |
| SEG-003 | implementado no incremento | configuração ignorada, sem segredos Dart e sem saída de credenciais | varredura local | revisão antes do primeiro commit |
| SEG-005 | implementado no incremento | mensagens seguras e nenhum log de PII/credenciais | falhas tipadas e inspeção | observabilidade permanece desativada |

## Rastreabilidade do incremento Etapa 3C

| ID | Requisito | Prioridade | Etapa | Critério de aceite | Testes necessários | Dependências | Impacto de segurança | Impacto de custo |
|---|---|---:|---:|---|---|---|---|---|
| AUT-008-3C | Persistir versões aceitas de Termos e Política | P0 | E3C | Aceite afirmativo registra versões atuais e timestamps do servidor; versão antiga bloqueia a home | domínio, controlador, widget, rotas e regras | Auth verificado e Firestore development | alto: base do acesso e rastreabilidade | baixo: uma gravação por novo aceite |
| AUT-009-3C | Exigir email confirmado também no token | P0 | E3C | Nenhuma leitura ocorre antes de recarregar Auth e obter `email_verified=true` | gate, token pendente e regras | Firebase Authentication | alto: impede acesso pré-verificação | baixo: atualização de token e leitura de perfil |
| PERF-001-3C | Criar perfil mínimo em `users/{uid}` | P0 | E3C | Documento possui exatamente 17 campos autorizados e `schemaVersion` 1 | modelo, mapper, criação e regras | Cloud Firestore | alto: minimização e isolamento | baixo: um documento por usuário |
| PERF-002-3C | Criar perfil de forma idempotente | P0 | E3C | Transação cria somente se ausente e preserva perfil/consentimentos existentes | controlador, concorrência e futuro emulador | transações Firestore | alto: evita sobrescrita de aceite | baixo: transação e leitura de confirmação |
| PERF-003-3C | Ler e atualizar somente o próprio perfil | P0 | E3C | `get` próprio permitido; listagem, acesso cruzado e exclusão negados | matriz de regras pendente de emulador | Security Rules | crítico: isolamento por usuário | neutro |
| PERF-004-3C | Validar nome e espelhar no Authentication | P0 | E3C | Nome normalizado de 2 a 80; Firestore grava primeiro; falha Auth parcial é informada | validação, controlador e falha parcial | Auth e Firestore sem transação conjunta | médio: evita inconsistência silenciosa | baixo: uma escrita por alteração |
| CONS-001-3C | Manter consentimentos IA e Analytics separados | P0 | E3C | Ambos começam falsos e cada alteração muda somente booleano/timestamp correspondente | domínio, controlador, widget e regras | perfil Firestore | alto: escolha livre e minimização | baixo: uma escrita por salvamento |
| CONS-002-3C | Registrar `analyticsConsentUpdatedAt` | P0 | E3C | Campo obrigatório usa timestamp do servidor e só muda com Analytics | mapper, controlador e regras | Firestore | alto: auditoria simétrica | baixo: campo adicional no perfil |
| SEG-009-3C | Negar Firestore por padrão | P0 | E3C | caminhos desconhecidos, subcoleções, listagem e exclusão permanecem bloqueados | matriz completa; emulador pendente | regras publicadas em development | crítico | neutro |
| OFF-001-3C | Não confiar em cache para o primeiro perfil | P0 | E3C | configuração e alterações só concluem após confirmação do servidor | gate, fake de cache e pendência | conexão com Firestore | alto: não contorna autorização | leituras adicionais de confirmação |

## Rastreabilidade do incremento Etapa 4A

| ID | Requisito | Prioridade | Etapa | Critério de aceite | Testes necessários | Dependências | Impacto de segurança | Impacto de custo |
|---|---|---:|---:|---|---|---|---|---|
| ACC-001-4A | Persistir contas na subcoleção própria com esquema exato | P0 | E4A | Documento possui somente os 11 campos aprovados; ID não é duplicado | modelo, mapper, campos ausentes/extras, regras | Firestore e perfil válido | crítico: isolamento e minimização | baixo: um documento por conta |
| ACC-002-4A | Aceitar somente os seis tipos aprovados | P0 | E4A | checking, savings, cash, digitalWallet, investment e other são aceitos; cartão é rejeitado | enum, conversão, widget e regras | nenhuma nova dependência | médio | neutro |
| ACC-003-4A | Normalizar e validar nome | P0 | E4A | nome final tem 2 a 60 caracteres, espaços normalizados e nenhum controle | domínio, mapper, formulário e regras | nenhuma | médio: sanitização | neutro |
| ACC-004-4A | Armazenar saldo inicial em centavos inteiros BRL | P0 | E4A | positivos, zero, negativos e limites funcionam sem double | parser, limites, mapper, widget e regras | Money e intl existentes | crítico: integridade monetária | neutro |
| ACC-005-4A | Calcular total somente de contas ativas incluídas | P0 | E4A | soma local ignora arquivadas e includeInTotal=false | unitários, lista vazia e limites | lista própria confirmada | alto: evita total enganoso | neutro |
| ACC-006-4A | Criar conta de forma idempotente | P0 | E4A | um ID é reutilizado por tentativa, toques repetidos são bloqueados e sucesso exige releitura servidor | controller, fake, retry incerto e futuro emulador | transação Firestore | crítico: evita duplicação | baixo: transação e leitura de confirmação |
| ACC-007-4A | Editar somente campos autorizados | P0 | E4A | name, type, openingBalanceCents e includeInTotal mudam; campos fixos permanecem | controller, mapper, widget e regras | documento existente | alto: protege propriedade e auditoria | baixo: escrita e confirmação |
| ACC-008-4A | Arquivar e restaurar sem excluir | P0 | E4A | estado e archivedAt transitam pareados com timestamp servidor; documento permanece | domínio, controller, widget e regras | documento existente | alto: evita perda de dados | baixo: escrita e confirmação |
| ACC-009-4A | Exigir Auth verificado, perfil e termos atuais | P0 | E4A | rota digitada e operações são bloqueadas antes do acesso financeiro quando o gate não é válido | rota, controller, widget e regras | Auth e perfil da Etapa 3C | crítico | baixo: regras podem avaliar leitura dependente do perfil |
| ACC-010-4A | Consultar somente users/{uid}/accounts | P0 | E4A | nenhuma collectionGroup ou consulta global; ordenação e filtros são locais | inspeção arquitetural, repository e matriz | Firestore | crítico: isolamento | proporcional ao número de contas próprias lidas |
| ACC-011-4A | Exigir confirmação do servidor | P0 | E4A | primeira lista e mutações não exibem confirmação a partir de cache ou escrita pendente | controller, cache fake, erro e retry | conexão de rede | alto | leituras adicionais de confirmação |
| ACC-012-4A | Manter interface acessível e sem dados fictícios | P1 | E4A | telas vazia/lista/formulário/detalhes/arquivadas funcionam em temas, fonte ampliada e tela pequena | widgets, semântica, navegação e overflow | sistema visual existente | baixo | neutro |
| SEG-010-4A | Aplicar regras Firestore estritas às contas | P0 | E4A | campos, tipos, limites, UID, email, timestamps e transições são validados; delete/subcoleções/desconhecidos negados | matriz completa; Emulator Suite pendente | regras publicadas em development | crítico | neutro |

## Incremento Etapa 4B

| ID | Requisito | Prioridade | Etapa | Critério de aceite | Testes necessários | Dependências | Impacto de segurança | Impacto de custo |
|---|---|---:|---:|---|---|---|---|---|
| CAT-001-4B | Persistir categorias com esquema exato e tipo imutável | P0 | E4B | Documento contém somente os 10 campos aprovados e `kind` não muda | domínio, mapper, controller, widget e regras | Firestore e perfil válido | alto | baixo |
| CAT-002-4B | Validar nome, ícone e cor em catálogos fechados | P0 | E4B | Nome normalizado 2–40; somente 14 ícones e 10 cores | limites, conversão, formulário e regras | tokens visuais | médio | neutro |
| CAT-003-4B | Arquivar/restaurar sem excluir | P0 | E4B | `isArchived` e `archivedAt` transitam coerentemente; histórico permanece | domínio, controller e regras | documento existente | alto | baixo |
| TRX-001-4B | Persistir receita/despesa ocorrida com esquema exato | P0 | E4B | Documento contém somente 13 campos; valor é inteiro positivo | mapper, tipos, limites e regras | conta e categoria ativas | crítico | baixo |
| TRX-002-4B | Validar referências próprias e tipo compatível | P0 | E4B | conta/categoria inexistente, arquivada, de outro UID ou incompatível é recusada | repositório, regras e futuro emulador | leituras dependentes | crítico | leituras adicionais em transação/regras |
| TRX-003-4B | Impedir datas futuras e respeitar São Paulo | P0 | E4B | hoje é aceito e amanhã recusado pela data civil de São Paulo | virada do dia, mês e fuso | relógio injetável | alto | neutro |
| TRX-004-4B | Editar somente campos descritivos | P0 | E4B | somente categoria compatível, descrição, data e notas mudam | mapper, controller e regras | lançamento ativo | crítico | baixo |
| TRX-005-4B | Cancelar irreversivelmente sem exclusão | P0 | E4B | cancelado deixa saldo, preserva documento e não pode ser restaurado/editado | domínio, controller, saldo e regras | timestamp servidor | crítico | baixo |
| TRX-006-4B | Criar de forma idempotente e bloquear múltiplos toques | P0 | E4B | retry incerto reutiliza ID e não duplica | fake, controller e futuro emulador | transação Firestore | crítico | transação e confirmação |
| BAL-001-4B | Derivar saldo atual sem campo materializado | P0 | E4B | inicial + receitas ativas − despesas ativas reconcilia por conta | unitários, cancelados e contas excluídas | contas e lançamentos confirmados | crítico | leitura integral inicial |
| BAL-002-4B | Calcular resumo mensal em centavos seguros | P0 | E4B | receitas, despesas e diferença do mês são exatas, sem `double` | BigInt, centavos, mês/fuso | Money | alto | neutro |
| UX-001-4B | Oferecer telas, filtros e estados acessíveis sem dados fictícios | P1 | E4B | fluxos vazios/erro/sucesso, fontes ampliadas e temas funcionam | widgets, navegação e overflow | sistema visual | médio | neutro |
| SEG-011-4B | Aplicar regras estritas a categorias e lançamentos | P0 | E4B | UID/email/perfil/campos/referências/transições são validados; delete e desconhecidos negados | matriz; Emulator Suite pendente | regras publicadas em development | crítico | neutro |

## Incremento Etapa 4C

| ID | Requisito | Prioridade | Etapa | Critério de aceite | Testes necessários | Dependências | Impacto de segurança | Impacto de custo |
|---|---|---:|---:|---|---|---|---|---|
| OWN-001-4C | Autorizar owner somente por `system_admins/{uid}` | P0 | E4C | UID vem da sessão; documento exato, ativo e development é confirmado pelo servidor | modelo, mapper, repositório e controller | Auth, ProfileGate e Firestore | crítico | uma leitura pontual por validação |
| OWN-002-4C | Falhar fechado | P0 | E4C | cache, timeout, erro, documento ausente/inválido ou revogado nunca concedem owner | cache, timeout, falhas e revogação | conexão do servidor | crítico | retries manuais podem gerar leituras |
| OWN-003-4C | Centralizar capabilities | P0 | E4C | owner recebe todas; comum e identificador desconhecido não recebem | domínio e segurança estática | nenhuma nova dependência | alto | neutro |
| OWN-004-4C | Preparar bypass comercial do owner | P1 | E4C | capabilities de assinatura, recursos pagos, IA e limites comerciais existem sem cobrança real | domínio e interface | módulos comerciais futuros | médio | nenhum custo atual |
| OWN-005-4C | Preservar limites técnicos e financeiros | P0 | E4C | owner não ignora regras, UID, integridade, autenticação, concorrência ou segurança técnica | regras e regressão | módulos existentes | crítico | neutro |
| OWN-006-4C | Proteger `/proprietario` | P0 | E4C | somente owner confirmado vê conteúdo; loading e acesso direto negado não expõem a página | rota, gate e widgets | go_router e estado controlado | crítico | neutro |
| OWN-007-4C | Revalidar e revogar | P0 | E4C | login, troca, retorno, atualização e revogação atualizam o estado sem callback antigo | controller, concorrência e ciclo de vida | Firestore | alto | uma leitura por revalidação |
| OWN-008-4C | Não expor identidade ou dados | P0 | E4C | UI/logs não exibem UID, e-mail, documento, segredos, saldos ou terceiros | interface, diagnóstico e busca estática | nenhuma | crítico | neutro |
| OWN-009-4C | Restringir regras administrativas | P0 | E4C | somente get próprio verificado; list/create/update/delete negados | matriz local; emulador pendente | regras publicadas e documento validado em development | crítico | neutro |
| OWN-010-4C | Manter produção bloqueada | P0 | E4C | documento e código aceitam somente development | mapper, provider, regra e teste estático | ambientes separados | crítico | neutro |

## Incremento FIN-5A — Compromissos financeiros

| ID | Requisito | Prioridade | Incremento | Critério de aceite | Situação atual | Dependências | Impacto de segurança | Impacto de custo |
|---|---|---:|---:|---|---|---|---|---|
| CMT-001-5A | Modelar contas a pagar e receber separadamente | P0 | FIN-5A-1 | domínio diferencia payable/receivable, estados e invariantes sem Flutter ou Firebase | implementado no domínio | Money, categorias e data civil | alto | neutro |
| CMT-002-5A | Persistir em `payables` e `receivables` | P0 | FIN-5A-2 | caminhos próprios sob `users/{uid}` usam esquema fechado e owner imutável | implementado localmente com mappers estritos e repositório | Firestore e perfil válido | crítico | baixo |
| CMT-003-5A | Separar vencimento de movimentação | P0 | FIN-5A-1 | vencimento aceita passado/presente/futuro; movimento nunca é futuro e não substitui vencimento | implementado no domínio | objeto de data civil | alto | neutro |
| CMT-004-5A | Derivar atraso sem persistência | P0 | FIN-5A-1 | somente pendência com vencimento anterior ao hoje de São Paulo é atrasada | implementado e coberto unitariamente | relógio injetável futuro | alto | neutro |
| CMT-005-5A | Não alterar saldo com pendência | P0 | FIN-5A-1/2 | compromisso declara não contribuir para saldo; apenas lançamento ativo vinculado entra no cálculo | implementado; pendência não cria transaction | transactions e cálculo de saldo | crítico | neutro |
| CMT-006-5A | Confirmar exatamente uma vez | P0 | FIN-5A-2 | pagamento/recebimento cria um lançamento e vínculo bidirecional na mesma transação atômica; retry retorna o vínculo existente | implementado e testado para repetição, timeout semântico e concorrência | transação Firestore e revisão | crítico | leituras e escrita atômica adicionais |
| CMT-007-5A | Cancelar pendência preservando histórico | P0 | FIN-5A-1/2 | `pending -> cancelled`, sem lançamento, exclusão ou restauração | implementado com timestamp de servidor e exclusão negada | timestamp servidor | alto | baixo |
| CMT-008-5A | Anular compromisso liquidado atomicamente | P0 | FIN-5A-1/2 | `paid/received -> voided` preserva vínculo e invalida o lançamento na mesma operação | implementado e validado atomicamente nas regras | transactions esquema 2 | crítico | escrita atômica adicional |
| CMT-009-5A | Isolar compromissos por UID | P0 | FIN-5A-2 | cliente acessa apenas subcoleções do próprio UID verificado e perfil atual | regras implementadas, testadas e publicadas anteriormente somente em development | Auth, perfil e Security Rules | crítico | neutro |
| TRX-007-5A | Suportar lançamento esquema 2 vinculado | P0 | FIN-5A-1/2 | esquema 2 aceita origem manual/payable/receivable; esquema 1 continua manual sem migração | mapper, repositórios e regras compatíveis com esquemas 1/2 | transactions atual | crítico | neutro |
| DAT-001-5A | Centralizar data civil de São Paulo | P0 | FIN-5A-1 | objeto válido converte calendário/instante, compara datas e preserva convenção 03:00 UTC | implementado e coberto unitariamente | nenhuma dependência nova | alto | neutro |
| ACC-013-5A | Proteger correção do saldo inicial além da interface | P0 | FIN-5A-0 | proposta cobre domínio, mapas de atualização e regras; correção futura usa movimento auditável | estratégia documentada; implementação não autorizada | accounts, transactions e decisão futura | crítico | neutro |
| TST-005-5A | Testar regras de compromissos no Emulator Suite | P0 | FIN-5A-2/2B | casos positivos, negativos, atômicos e regressão passam em projeto demo isolado; log não contém limite de expressões, excesso de leituras, avaliação interrompida, valor nulo ou falha interna | infraestrutura e auditoria local implementadas; suíte consolidada anterior com 27 testes | Node, Java existente e Firebase CLI local | crítico | somente custo local de execução |

## Incremento UI-2 — Design system, temas e dashboard analítico

| ID | Requisito | Prioridade | Incremento | Critério de aceite | Situação atual | Dependências | Impacto de segurança | Impacto de custo |
|---|---|---:|---:|---|---|---|---|---|
| UI-201 | Oferecer Sistema, Claro e Escuro | P0 | UI-2 | padrão segue sistema; troca preserva rota e possui semântica | implementado e aprovado visualmente no celular em 04/08/2026 | ThemeData e Riverpod | baixo | neutro |
| UI-202 | Persistir aparência no aparelho | P0 | UI-2 | escolha reaparece após nova inicialização sem flash | implementado com uma chave não sensível | shared_preferences 2.5.5 | baixo; nenhum dado financeiro | armazenamento local mínimo |
| UI-203 | Aplicar paletas globalmente | P0 | UI-2 | telas e componentes Material usam ColorScheme/ThemeExtension sem aqua em grandes superfícies | implementado; validação visual pendente | sistema visual | baixo | neutro |
| UI-204 | Filtrar dashboard com dados reais | P0 | UI-2 | conta e período atualizam indicadores, gráficos, categorias e lançamentos sem escrita | implementado localmente sobre listas confirmadas | providers atuais | alto: não altera fonte canônica | CPU local proporcional à lista |
| UI-205 | Exibir gráficos móveis acessíveis | P0 | UI-2 | comparação e rosca possuem vazio, texto, semântica, privacidade e ausência de overflow | implementado com CustomPainter | nenhuma biblioteca gráfica | médio | neutro |
| UI-206 | Exibir contas em carrossel | P1 | UI-2 | monograma, tipo, saldo, sinal textual, detalhes e adição funcionam | implementado sem inferir instituição | modelo de contas atual | baixo | neutro |
| ACC-2 | Criar catálogo de instituições | P2 | futuro | bancos, digitais, fintechs, carteiras, dinheiro e outro aceitam múltiplas contas sem credenciais | não implementado; decisão futura registrada | revisão de schema e marcas | alto se houver inferência indevida | a estimar |
| UI-207 | Postergar análises inexistentes | P0 | futuro | reserva, metas, previsão e anual avançado não usam dados fictícios | fora do UI-2 e documentado | módulos futuros | alto: evita informação enganosa | neutro atual |

## Incremento UI-3 — Dashboard 3.0 e contas visuais

| ID | Requisito | Prioridade | Incremento | Critério de aceite | Situação atual | Dependências | Impacto de segurança | Impacto de custo |
|---|---|---:|---:|---|---|---|---|---|
| UI-301 | Compactar hierarquia financeira | P0 | UI-3 | saldo oficial e resultado compartilham uma superfície; receitas e despesas são equivalentes; não existe KPI de resultado duplicado | implementado e aprovado visualmente no celular em 04/08/2026 | dados e temas UI-2 | baixo | neutro |
| UI-302 | Oferecer filtros móveis completos | P0 | UI-3 | conta, mês atual/anterior, ano, mês/ano, intervalo e limpar atualizam análises sem escrita | implementado localmente | listas confirmadas e data civil | alto: preserva fonte canônica | CPU local proporcional à lista |
| UI-303 | Refinar gráficos com dados reais | P0 | UI-3 | barras possuem escala e valores; rosca mostra quatro categorias e agrupa o restante como Outras | implementado sem biblioteca externa | transações e categorias existentes | médio | neutro |
| UI-304 | Refinar contas visuais | P0 | UI-3 | carrossel e lista usam monograma, tipo, saldo, estado textual e detalhe; nenhuma instituição é inferida | implementado; ACC-2 permanece futuro | contas atuais | médio | neutro |
| UI-305 | Preservar acessibilidade responsiva | P0 | UI-3 | temas, privacidade, sem dados, muitas contas/categorias, 320 px, fonte 180%, valores grandes e semântica não geram overflow | coberto por testes de widget; aprovação manual pendente | sistema visual | médio | neutro |

## Incremento UI-3A — Menu e ações contextuais

| ID | Requisito | Prioridade | Incremento | Critério de aceite | Situação atual | Dependências | Impacto de segurança | Impacto de custo |
|---|---|---:|---:|---|---|---|---|---|
| UI-3A-01 | Agrupar a navegação secundária | P0 | UI-3A | um botão Menu abre bottom sheet rolável com Organização, Planejamento e Conta e aplicativo, preservando rotas e Voltar | implementado localmente | rotas existentes | baixo | neutro |
| UI-3A-02 | Expor ações administrativas corretas | P0 | UI-3A | contas/categorias ativas exibem editar e arquivar lado a lado; arquivadas exibem restaurar; alvos têm ao menos 44 dp, tooltip, semântica e confirmação | implementado e coberto por widgets | controllers existentes | médio: evita toque e exclusão acidentais | neutro |
| UI-3A-03 | Expor ações financeiras somente nos detalhes | P0 | UI-3A | lançamento manual ativo oferece edição descritiva/cancelamento; compromisso pendente oferece edição/cancelamento; liquidado oferece vínculo/anulação com impacto explicado | implementado e coberto por widgets | detalhes e operações existentes | alto: preserva histórico e saldo | neutro |
| UI-3A-04 | Não sugerir exclusão inexistente | P0 | UI-3A | dashboard não recebe ações destrutivas e nenhuma lixeira aparece enquanto não houver exclusão permanente segura | implementado e coberto por regressão | DATA-1 futuro | alto | neutro |

## Incremento UI-3B — Cabeçalho e gráfico agrupado

| ID | Requisito | Prioridade | Incremento | Critério de aceite | Situação atual | Dependências | Impacto de segurança | Impacto de custo |
|---|---|---:|---:|---|---|---|---|---|
| UI-3B-01 | Reduzir densidade da Home | P0 | UI-3B | remover seção Contas e carteiras, carrossel, Ver todas e Adicionar conta sem remover o filtro compacto de conta | implementado localmente e coberto por widget | dashboard UI-3 | baixo | reduz widgets; neutro em leituras |
| UI-3B-02 | Mover Menu para o cabeçalho | P0 | UI-3B | canto superior direito abre os mesmos grupos e rotas; privacidade e tema permanecem; Perfil existe somente no painel | implementado localmente e coberto por navegação, semântica e temas | UI-3A | baixo | neutro |
| UI-3B-03 | Comparar receitas e despesas por colunas | P0 | UI-3B | duas colunas agrupadas usam escala e base comuns, profundidade discreta, valores, legenda, período, resultado, privacidade e semântica | implementado nativamente e coberto por widgets responsivos | dados reais e filtros atuais | médio: não pode distorcer proporções | CPU local neutra |

## Incremento INV-1A — Carteira de acompanhamento manual

| ID | Requisito | Prioridade | Incremento | Critério de aceite | Situação atual | Dependências | Impacto de segurança | Impacto de custo |
|---|---|---:|---:|---|---|---|---|---|
| INV-001-1A | Manter carteiras manuais | P0 | INV-1A | criar, editar, arquivar e restaurar preserva ativos e histórico; exclusão é negada | implementado localmente | perfil válido e Firestore | alto | baixo por documento |
| INV-002-1A | Cadastrar ação e FII em BRL | P0 | INV-1A | ticker maiúsculo e ID determinístico impedem duplicata na carteira; nome e tipo são fechados | implementado localmente | carteira ativa | alto | baixo |
| INV-003-1A | Representar valores sem ponto flutuante | P0 | INV-1A | dinheiro usa centavos, quantidade escala 8, preço escala 6 e intermediários `BigInt` com half-up | implementado e coberto unitariamente | nenhuma dependência nova | crítico | neutro |
| INV-004-1A | Reconstruir custo médio e resultado | P0 | INV-1A | taxa de compra entra no custo; venda baixa custo proporcional e taxa reduz resultado; posição zerada permanece | implementado e coberto unitariamente | operações imutáveis | crítico | CPU local proporcional ao histórico |
| INV-005-1A | Impedir impacto no saldo | P0 | INV-1A | operação de acompanhamento não cria lançamento nem referencia conta, receita, despesa ou compromisso | implementado por separação de contratos/coleções | núcleo financeiro existente | crítico | neutro |
| INV-006-1A | Preservar e corrigir histórico | P0 | INV-1A | operação confirmada não edita/exclui/restaura; correção anula o topo e exige nova operação | implementado com cadeia anterior | Firestore transacional | crítico | escrita atômica adicional |
| INV-007-1A | Bloquear venda excedente e concorrência | P0 | INV-1A | ativo e operação mudam atomicamente; quantidade nunca negativa; revisão concorrente tem um vencedor | implementado em repositório e regras | transações e getAfter | crítico | leituras transacionais |
| INV-008-1A | Confirmar e reconciliar com servidor | P0 | INV-1A | leitura server-only confirma estado; timeout/indisponibilidade reutilizam ID sem duplicar | implementado em repositório/controller | conectividade Firestore | alto | releituras adicionais |
| INV-009-1A | Isolar por UID e perfil jurídico | P0 | INV-1A | anônimo, e-mail não confirmado, outro UID e owner cruzado são negados; campos são exatos | regras testadas e publicadas exclusivamente em development | Auth, perfil e Security Rules | crítico | neutro |
| INV-010-1A | Apresentar somente dados reais disponíveis | P0 | INV-1A | tela mostra quantidade, custo, média e realizado; não mostra cotação, valor atual ou rentabilidade fictícia | implementado com aviso explícito | operações próprias | alto: evita indução financeira | neutro |
| INV-011-1A | Preservar experiência acessível | P1 | INV-1A | Menu > Patrimônio, privacidade global, temas, vazio/erro/retry, 320 px e fonte 180% funcionam sem overflow | implementado e coberto por widgets | sistema visual | médio | neutro |
| INV-012-1A | Validar Security Rules localmente | P0 | INV-1A | casos válidos/negados e regressões passam em projeto `demo-*`; log não possui diagnósticos proibidos | implementado localmente; 40 testes totais de regras após INV-1A | Java existente e CLI local | crítico | somente execução local |

## Incremento UI-INV-1B — Redesign visual de investimentos

| ID | Requisito | Prioridade | Incremento | Critério de aceite | Situação atual | Dependências | Impacto de segurança | Impacto de custo |
|---|---|---:|---:|---|---|---|---|---|
| UI-INV-001-1B | Navegar no módulo de investimentos | P0 | UI-INV-1B | seletor de carteira e abas autorizadas funcionam com retorno seguro e sem abas vazias; INV-PROV-1 acrescenta Proventos | implementado localmente | apresentação INV-1A | baixo | neutro |
| UI-INV-002-1B | Resumir somente dados reais | P0 | UI-INV-1B | custo, contagens e resultado realizado não são confundidos com patrimônio, cotação ou rentabilidade | implementado localmente | projeção INV-1A | alto: evita indução financeira | CPU local |
| UI-INV-003-1B | Visualizar evolução e alocação | P0 | UI-INV-1B | gráficos nativos usam operações e custo das posições, possuem legenda, vazio, semântica e privacidade | implementado localmente | `CustomPainter` e operações locais | médio | CPU local proporcional ao histórico |
| UI-INV-004-1B | Localizar ativos e operações | P1 | UI-INV-1B | busca, tipo, operação, ativo e período filtram localmente com ordenação determinística | implementado localmente | workspace confirmado | baixo | neutro |
| UI-INV-005-1B | Revisar operação antes de confirmar | P0 | UI-INV-1B | prévia usa aritmética canônica e diálogo confirma valor final e impacto estimado | implementado localmente | domínio escalado existente | alto | neutro |
| UI-INV-006-1B | Preservar acessibilidade móvel | P0 | UI-INV-1B | 320 px, fonte 180%, temas, teclado, rolagem, privacidade, semântica e alvos de toque não geram overflow | implementado e coberto por widgets | sistema visual | médio | neutro |

## Incremento INV-PROV-1 — Proventos manuais

| ID | Requisito | Prioridade | Incremento | Critério de aceite | Situação atual | Dependências | Impacto de segurança | Impacto de custo |
|---|---|---:|---:|---|---|---|---|---|
| INV-PROV-001 | Registrar tipos compatíveis | P0 | INV-PROV-1 | ação aceita dividendo/JCP e FII aceita rendimento; carteira e ativo próprios e ativos são obrigatórios | implementado localmente | INV-1A | alto | uma escrita por evento |
| INV-PROV-002 | Preservar estados e histórico | P0 | INV-PROV-1 | previsto vai a recebido/cancelado; recebido vai a anulado; terminais não restauram nem excluem | implementado e coberto | revisão e timestamps servidor | crítico | uma escrita por transição |
| INV-PROV-003 | Calcular valores exatamente | P0 | INV-PROV-1 | total usa centavos; por unidade usa escalas 8/6, `BigInt` e half-up; líquido é bruto menos imposto | implementado e coberto unitariamente | tipos escalados | crítico | neutro |
| INV-PROV-004 | Tratar datas civis | P0 | INV-PROV-1 | data-com opcional e previsão usam São Paulo; recebido efetivo não pode ser futuro | implementado | objeto de data civil | alto | neutro |
| INV-PROV-005 | Impedir impacto financeiro | P0 | INV-PROV-1 | nenhuma mutação cria lançamento ou altera conta, saldo, compromisso, posição ou resumo mensal | implementado por coleção/contrato separado e testado | núcleo financeiro | crítico | neutro |
| INV-PROV-006 | Confirmar e reconciliar | P0 | INV-PROV-1 | server-only confirma mutação; timeout/indisponibilidade/aborto reutilizam IDs e não duplicam | implementado em repositório/controller | Firestore | alto | releitura por mutação |
| INV-PROV-007 | Proteger acesso e contrato | P0 | INV-PROV-1 | UID, email, perfil, owner cruzado, campos exatos, referências, revisão e exclusão são validados | 50/50 no Emulator; regras compiladas e publicadas exclusivamente em development, sem acesso a production; SHA-256 `8B689BA72FE05B1C04409E00083644D83B2EEACFDDA67A7C8D003B843E102FBE` | Emulator `demo-*` e publicação development autorizada | crítico | leituras de referências |
| INV-PROV-008 | Apresentar dados reais | P0 | INV-PROV-1 | resumo, filtros, gráficos, cartões e histórico usam somente eventos persistidos; nenhum provento é simulado | implementado | workspace confirmado | alto | CPU local proporcional ao histórico |
| INV-PROV-009 | Preservar UX acessível | P0 | INV-PROV-1 | quarta aba, privacidade, temas, 320 px, fonte 180%, teclado e semântica funcionam sem overflow | implementado e coberto por widgets | sistema visual | médio | neutro |
| INV-PROV-010 | Manter fronteiras do escopo | P0 | INV-PROV-1 | sem agenda automática, amortização, cálculo tributário, notificação, paywall ou integração financeira; integração B3 e integrações automáticas com corretoras canceladas e fora do planejamento | confirmado por auditoria de código e decisão do responsável | nenhuma dependência nova | alto | nenhum serviço externo |

## Incremento SUB-1A — Domínio e contrato de entitlement Premium

| ID | Requisito | Prioridade | Incremento | Critério de aceite | Situação atual | Dependências | Impacto de segurança | Impacto de custo |
|---|---|---:|---:|---|---|---|---|---|
| SUB-001-1A | Modelar planos e entitlement puro | P0 | SUB-1A | gratuito é ausência; mensal/anual não têm preço e compartilham capabilities; entidade não importa Flutter/Firebase/pagamentos | implementado e coberto unitariamente | nenhuma dependência nova | alto | neutro |
| SUB-002-1A | Representar ciclo completo | P0 | SUB-1A | dez estados canônicos validam período, carência, cancelamento, expiração, revogação e reembolso | implementado e coberto | instante UTC injetado | crítico | neutro |
| SUB-003-1A | Decidir acesso explicitamente | P0 | SUB-1A | resultado informa integral/somente leitura/negado, motivo, validade, carência, cancelamento e releitura | implementado e coberto nos limites exatos | entidade válida | crítico | neutro |
| SUB-004-1A | Preservar dados após expiração | P0 | SUB-1A | carteira, ativos, operações e proventos permanecem legíveis; mutações e cotação são negadas; nenhum saldo muda | política de domínio implementada; aplicação futura não conectada | SUB-1B e regras futuras | crítico | reduz consumo de cotação |
| SUB-005-1A | Reconciliar eventos determinísticos | P0 | SUB-1A | revisão antiga/repetida, período regressivo, owner/ambiente divergente e restauração terminal são negados | implementado em política de transição | backend futuro | crítico | neutro |
| SUB-006-1A | Restringir contrato cliente | P0 | SUB-1A | repositório prevê somente leitura, observação confirmada, releitura e diagnóstico sanitizado; nenhuma mutação | interface pura criada, sem implementação | backend/persistência futuros | crítico | neutro |
| SUB-007-1A | Manter fronteiras operacionais | P0 | SUB-1A | sem Billing, produto, backend, persistência, regras, paywall, grant owner ou bloqueio atual | confirmado por auditoria e hash das regras | autorização futura | crítico | nenhum serviço externo |

## Incremento SUB-1B — Backend development do entitlement Premium

| ID | Requisito | Prioridade | Incremento | Critério de aceite | Situação atual | Dependências | Impacto de segurança | Impacto de custo |
|---|---|---:|---:|---|---|---|---|---|
| SUB-001-1B | Validar compra autoritativamente | P0 | SUB-1B | gateway/DTO/mapper validam identidade, ambiente, allowlist, estado e período; desconhecido nega | implementado com fake local | SUB-1A | crítico | zero externo |
| SUB-002-1B | Proteger token e identidade | P0 | SUB-1B | token não aparece em projeção/log/retorno; fingerprint é HMAC versionado; vínculo não cruza UID | implementado e coberto sinteticamente | cofre real futuro | crítico | zero externo |
| SUB-003-1B | Reconciliar atomicamente | P0 | SUB-1B | repetição, concorrência, evento antigo e timeout pré/pós-commit não duplicam nem regridem | implementado em armazenamento local transacional | persistência real futura | crítico | zero externo |
| SUB-004-1B | Modelar RTDN e acknowledgement | P0 | SUB-1B | RTDN reconsulta gateway; inbox/outbox são idempotentes e sanitizadas | contrato/processador local | infraestrutura futura | alto | zero externo |
| SUB-005-1B | Restringir grants | P0 | SUB-1B | próprio UID, motivo, validade, ambiente, revisão, capabilities e revogação; dev nega production | implementado localmente | autorização backend futura | crítico | zero externo |
| SUB-006-1B | Ler projeção confirmada | P0 | SUB-1B | mapper exato, `Source.server`, ausência explícita, watch sem cache/pending e diagnóstico sanitizado | implementado sem conexão à UI | Firestore SDK existente | alto | uma leitura futura |
| SUB-007-1B | Proteger Firestore | P0 | SUB-1B | próprio `get`; list/write/cross UID/owner/subcoleção/internos negados | 57/57 no Emulator; regras publicadas somente em development, sem production; SHA-256 `F01E52545F2CE88896A48B28B957BF45F8AE79B0173DF2E20449929FF21532B4` | backend real e enforcement futuros | crítico | leituras de perfil |
| SUB-008-1B | Preservar escopo e UX | P0 | SUB-1B | sem paywall/bloqueio/compra; investimentos atuais seguem acessíveis e nenhum dado é apagado | confirmado | SUB-1C futuro | alto | neutro |

## Incrementos futuros de dados, privacidade e armazenamento

| ID | Requisito | Prioridade | Incremento | Critério de aceite | Situação atual | Dependências | Impacto de segurança | Impacto de custo |
|---|---|---:|---:|---|---|---|---|---|
| DATA-1 | Excluir com segurança itens nunca utilizados | P1 | futuro | somente contas sem lançamentos/compromissos e categorias sem referências podem ser excluídas após validação server-side concorrente, regras e auditoria | registrado; não implementado | domínio, repositórios, regras e Emulator Suite | crítico | leituras adicionais a estimar |
| PRIV-1 | Excluir a conta e os dados do usuário | P0 | futuro | reautenticação e operação server-side idempotente aplicam retenção e confirmam o resultado sem vazamento entre UIDs | registrado; não implementado; relacionado a AUT-007 | política LGPD, Functions e regras | crítico | Functions/armazenamento a estimar |
| STORAGE-1 | Limitar crescimento local sem perder exatidão | P0 | futuro | cache possui limite aprovado, históricos são paginados, estado por UID é descartado no logout e limpeza local nunca apaga remoto nem escrita pendente | auditoria concluída; implementação não autorizada | estratégia de agregação exata, repositórios e testes Android | crítico | reduz leituras/memória; índices a estimar |
