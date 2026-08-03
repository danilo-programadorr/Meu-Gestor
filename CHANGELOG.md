# Changelog

Todas as mudanças relevantes deste projeto serão documentadas neste arquivo.

O formato segue [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/) e o projeto pretende adotar [Versionamento Semântico](https://semver.org/lang/pt-BR/) quando iniciar lançamentos versionados.

## [Unreleased]

### Adicionado

- fundação Flutter Android com arquitetura modular;
- temas claro e escuro e sistema visual acessível;
- objetos de valor para dinheiro em centavos e moeda BRL;
- autenticação Firebase por e-mail, senha e Google;
- criação de conta, confirmação de e-mail e recuperação de senha;
- rotas protegidas conforme autenticação e confirmação de e-mail;
- diagnóstico sanitizado do login Google em desenvolvimento;
- testes automatizados de inicialização, autenticação, navegação, responsividade, acessibilidade e dinheiro;
- workflow de qualidade para formatação, análise estática e testes;
- documentação pública de contribuição, segurança e configuração Firebase local.
- perfil básico tipado em `users/{uid}`, com criação transacional idempotente;
- portões de perfil, confirmação do token e atualização jurídica;
- telas de configuração inicial, perfil e consentimentos;
- consentimentos opcionais e separados para IA e Analytics;
- regras Firestore locais com negação por padrão e matriz de casos pendentes de emulador;
- documentação de publicação manual das regras development.
- módulo local de contas e carteiras com domínio tipado, repositório Firestore, Riverpod e rotas protegidas;
- criação idempotente, leitura confirmada pelo servidor, edição, arquivamento e restauração de contas;
- saldo inicial e total em centavos inteiros, com valores negativos e BRL formatado em pt-BR;
- telas de lista, formulário, detalhes e contas arquivadas, sem dados de demonstração;
- regras locais estritas para `users/{uid}/accounts/{accountId}` e matriz de publicação/testes;
- testes automatizados do modelo, dinheiro, mapper, erros, controllers, navegação, responsividade e acessibilidade.
- categorias de receita/despesa com catálogos fechados, edição, arquivamento e restauração;
- lançamentos manuais de receitas e despesas ocorridas, edição descritiva e cancelamento sem exclusão;
- saldo atual e resumo mensal derivados exclusivamente de contas e lançamentos ativos em centavos inteiros;
- telas e rotas de categorias e lançamentos com filtros locais e estados acessíveis;
- regras locais estritas para categorias e lançamentos, matriz de testes e guia de publicação manual;
- testes de datas de São Paulo, mappers, idempotência, múltiplos toques, cancelamento e cálculo de saldo.
- correções de navegação, resumo mensal, edição descritiva e seleção da data real da movimentação;
- acesso proprietário seguro em development por documento `system_admins/{uid}` confirmado pelo servidor;
- capabilities centralizadas para módulos, diagnósticos, experimentos e bypass comercial futuro do owner;
- rota `/proprietario`, Área do proprietário, selo acessível no perfil e revalidação manual/no retorno ao aplicativo;
- 60 testes automatizados do modelo, repositório, concorrência, capabilities, interface e segurança do owner;
- documentação de arquitetura, matriz de regras e configuração manual do owner.
- regras Firestore de perfil, contas, categorias, lançamentos e owner publicadas manualmente em development.
- decisões FIN-5A para compromissos em `payables` e `receivables`, com atraso derivado e estados terminais `cancelled`/`voided`;
- objeto de data civil de São Paulo e domínio puro de contas a pagar/receber, ainda sem persistência, regras ou interface;
- contrato futuro de confirmação/anulação atômica e suporte de domínio ao vínculo de lançamentos esquema 2, preservando compatibilidade com esquema 1.
- persistência local de compromissos com mappers estritos e `FirebaseCommitmentRepository`;
- confirmação e anulação atômicas com vínculo bidirecional, revisão e recuperação idempotente após falhas incertas;
- lançamentos esquema 2 para origens manual, payable e receivable, mantendo leitura e mutação de documentos esquema 1;
- Security Rules locais para payables/receivables e harness isolado do Firestore Emulator com Project ID `demo-*`.
- endurecimento FIN-5A-2B das Security Rules, com despacho determinístico de estados/origens, referências pós-gravação protegidas e auditoria automática dos diagnósticos do Emulator.

### Segurança

- separação entre ambientes development e production;
- configuração Firebase local excluída do versionamento;
- bloqueio de inicialização Firebase production sem configuração própria;
- bloqueio de release production enquanto documentos jurídicos oficiais estiverem pendentes.
- validação do token `email_verified` antes do primeiro acesso ao Firestore;
- confirmação de gravações do perfil por leitura do servidor;
- subcoleções financeiras, listagem e exclusão do perfil negadas nesta etapa.
- contas isoladas por UID, confirmação de email e perfil jurídico válido antes do acesso;
- exclusão permanente e subcoleções de conta negadas; logs financeiros sanitizados.
- leitura administrativa limitada ao próprio documento; listagem e toda escrita pelo cliente negadas;
- owner não ignora isolamento por UID, regras financeiras, autenticação ou limites técnicos de segurança.
- lançamentos exigem conta/categoria próprias e ativas, tipo compatível e confirmação do servidor;
- campos financeiros imutáveis após criação; cancelamento irreversível e exclusão negada.
- compromissos isolados por UID, esquema fechado, referências próprias e liquidação obrigatoriamente atômica;
- lançamentos vinculados não aceitam edição, anulação isolada, restauração ou exclusão.
