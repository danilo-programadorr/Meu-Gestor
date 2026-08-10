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
- UI-2 com temas Sistema/Claro/Escuro, preferência local persistente e cobertura global por `ColorScheme`/`ThemeExtension`;
- dashboard analítico com filtros locais de conta e período, comparação de receitas/despesas, distribuição por categoria e carrossel de contas usando somente dados reais;
- adaptação para privacidade, semântica, 320 px, fonte 180% e valores financeiros máximos, sem biblioteca externa de gráficos.
- UI-3 com Dashboard 3.0 sofisticado e compacto, resumo sem KPI duplicado, ações horizontais, comparação com valores, ranking de categorias e carrossel proporcional;
- filtros móveis com conta informativa, seleção de mês/ano e limpeza explícita, sem alterar saldo ou documentos;
- tela de Contas e carteiras refinada com total petróleo/claro, monogramas, estado textual do saldo e ações de menor peso visual.
- UI-3A com Menu compacto agrupado em Organização, Planejamento e Conta e aplicativo, preservando as rotas existentes;
- ações contextuais lado a lado com edição, arquivamento, restauração, cancelamento e anulação semanticamente corretos, sem lixeira ou exclusão permanente;
- registro dos incrementos futuros `DATA-1`, para exclusão segura de itens nunca utilizados, e `PRIV-1`, para exclusão da conta e dos dados;
- auditoria `STORAGE-1` do cache local, consultas, paginação, providers e logout, sem alterar comportamento ou configuração de armazenamento.
- UI-3B com remoção da seção de contas da Home, preservando o filtro compacto de conta no topo;
- Menu agrupado transferido para o canto superior direito do cabeçalho, sem duplicar o acesso a Perfil;
- comparação de receitas e despesas substituída por colunas agrupadas 2.5D nativas, com escala e linha de base comuns, período, valores, legenda, resultado e semântica.
- INV-1A com carteiras de acompanhamento, ações/FIIs manuais, compras, vendas e posições zeradas preservadas;
- quantidades e preços escalados em inteiros, cálculos `BigInt`, custo médio móvel e resultado realizado sem ponto flutuante;
- operações imutáveis em ordem cronológica, correção por anulação encadeada e nova operação, com IDs idempotentes e confirmação do servidor;
- telas de investimentos no grupo Patrimônio do Menu, privacidade global, temas, estados completos, 320 px e fonte ampliada;
- coleções `investmentPortfolios`, `investmentAssets` e `investmentOperations`, mappers estritos, repositório transacional e regras locais fechadas;
- testes locais de domínio, mappers, repositório, controllers, widgets e Security Rules para isolamento, concorrência, venda excedente e anulação atômica.
- UI-INV-1B com seletor compacto de carteira e navegação interna por Resumo, Ativos e Lançamentos;
- resumo de investimentos com custo acompanhado, resultado realizado, evolução de compras/vendas e alocação por classe ou ativo usando somente operações reais;
- busca, filtros e ordenação locais de ativos, histórico móvel responsivo e gerenciamento de carteiras sem exclusão;
- formulário de operação com prévia canônica de valor bruto, taxas, valor final, quantidade e possível novo preço médio antes da confirmação;
- detalhes de posição reorganizados e aviso explícito de indisponibilidade de cotação, sem dados de mercado simulados ou dependência gráfica externa.
- INV-PROV-1 com dividendos, JCP e rendimentos de FII informados manualmente, em estados previsto, recebido, cancelado e anulado;
- valores total ou por unidade calculados em inteiros com `BigInt` e half-up, imposto retido informado e líquido derivado sem afetar contas ou saldo;
- quarta aba Proventos com resumo, filtros, colunas dos últimos 12 meses, distribuição, cartões e histórico mensal/anual usando somente registros reais;
- coleção `investmentIncomeEvents`, mapper estrito, repositório confirmado pelo servidor, idempotência, revisão e regras locais testadas no Emulator `demo-*`.
- SUB-1A com domínio puro de entitlement Premium, planos gratuito/mensal/anual, fontes Google Play e concessões controladas, sem preço ou dependência de pagamento;
- máquina canônica de dez estados, capabilities tipadas, decisão explícita integral/somente leitura/negada e validade baseada em instante confiável injetado;
- política de transições por revisão para eventos duplicados ou fora de ordem e contrato cliente exclusivamente de leitura, observação, releitura e diagnóstico sanitizado;
- preservação de carteiras, ativos, operações e proventos após perda do Premium, sem alterar preço médio, contas, saldo ou resumo mensal.
- SUB-1B com backend ESM exclusivamente local e sem dependências externas, gateway fake, DTO estrito, token protegido, reconciliação idempotente, RTDN, acknowledgement e grants sintéticos;
- mapper e repositório do entitlement somente leitura confirmada, além de Security Rules locais que negam toda escrita cliente e coleções internas Premium.
- Security Rules SUB-1B compiladas e publicadas exclusivamente em development, sem acesso a production, com SHA-256 `F01E52545F2CE88896A48B28B957BF45F8AE79B0173DF2E20449929FF21532B4`; backend real, Google Play e enforcement Premium permanecem ausentes.

### Segurança

- separação entre ambientes development e production;
- SUB-1A mantém tokens de compra, recibos, payloads e credenciais fora do domínio; grants de development falham fora do ambiente correto e nenhum método cliente concede ou altera entitlement;
- SUB-1B mantém tokens fora de projeções e diagnósticos, vincula compras a um UID/ambiente e nega acesso cliente às coleções operacionais;
- configuração Firebase local excluída do versionamento;
- bloqueio de inicialização Firebase production sem configuração própria;
- bloqueio de release production enquanto documentos jurídicos oficiais estiverem pendentes.
- investimentos isolados por UID verificado e perfil jurídico atual, sem exceção para owner;
- compra/venda exige atualização atômica da projeção mínima do ativo; edição, restauração e exclusão de operações são negadas;
- proventos confirmados preservam valores e datas; cancelamento/anulação são terminais, restauração/exclusão são negadas e owner não amplia acesso;
- Emulator Suite usa somente projeto `demo-*`; em autorização posterior, as regras INV-1A foram publicadas exclusivamente em development e o APK debug foi aprovado manualmente.
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
