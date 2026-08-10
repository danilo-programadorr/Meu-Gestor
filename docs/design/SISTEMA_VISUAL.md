# Sistema visual — Meu Gestor Financeiro

## 1. Situação

- Versão inicial implementada na Etapa 3B.
- Aplicação inicial: autenticação Android em português do Brasil.
- Referência principal: composição visual de `login-aprovado.png`.
- Referências secundárias: cadastro, redefinição de senha e paletas aprovadas.
- As imagens completas de referência não são usadas como fundo nem substituem widgets.
- O único ativo derivado é `assets/images/auth/auth_hero.webp`, contendo exclusivamente uma área fotográfica sem interface, texto, marca, logotipo, gráfico ou dado.

## 2. Cores

Todos os valores ficam centralizados em `lib/app/theme/app_colors.dart`. Widgets não definem hexadecimais de identidade.

| Token | Valor | Finalidade |
|---|---:|---|
| backgroundPrimary | `#050B18` | fundo escuro principal |
| backgroundSecondary | `#151E32` | superfícies escuras neutras |
| backgroundElevated | `#1A2940` | cartões escuros elevados |
| surfacePrimary | `#151E32` | campos e cartões escuros |
| borderDefault | `#29445A` | bordas azul-petróleo discretas |
| primaryCyan | `#63AFC8` | azul-gelo para ícones, foco e ações |
| primaryBlue | `#4F8CA8` | apoio de ação e gradientes controlados |
| chartBlue | `#8CC9D8` | destaque claro e gráficos |
| positiveGreen | `#62B982` | receita/sucesso acompanhado de texto/ícone |
| secondaryPurple | `#7447E8` | apoio visual futuro |
| errorRed | `#F07B73` | despesa/erro acompanhado de texto/ícone |
| textPrimary | `#F4F7FB` | texto principal no tema escuro |
| textSecondary | `#AAB5C8` | texto auxiliar no tema escuro |
| disabled | `#738095` | controles inativos |

O tema claro usa fundo `#F4F7FA`, superfícies brancas, cartões secundários `#EAF1F5`, ação `#3F7F99`, apoio `#D8EDF3`, texto `#142033`/`#5D6A7B` e borda `#C7D7E0`. O tema escuro evita grandes preenchimentos ciano. Erro, atenção, receita e despesa nunca dependem somente de cor.

## 3. Tipografia

- Família do sistema: Roboto, fornecida pelo Android/Flutter, sem download externo.
- Títulos principais: 30 px, peso 700, altura 1,2.
- Títulos de seção: 24 px, peso 700, altura 1,25.
- Corpo principal: 16 px, peso 400, altura 1,5.
- Corpo auxiliar: 14 px, peso 400, altura 1,5.
- Ações: 15 px, peso 700.
- Os layouts permitem quebra e rolagem com escala de texto ampliada.

## 4. Espaçamento, raios e dimensões

- Escala: 4, 8, 12, 16, 24, 32 e 40 px.
- Margem horizontal padrão: 24 px; compacta: 18 px.
- Altura mínima de campo e botão: 56 px.
- Alvo mínimo de toque: 48 px.
- Raios: 8, 14, 22 e 28 px; círculos usam raio total.
- Conteúdo de autenticação limitado a 560 px para preservar leitura em telas maiores.

## 5. Sombras, gradientes e opacidade

- A elevação usa sombra escura difusa de 28 px e deslocamento vertical de 14 px.
- Foco de marca usa brilho azul-gelo com opacidade reduzida; nunca substitui a borda de foco.
- Gradiente escuro oficial: `#050B18`, `#151E32`, `#10243A`.
- Gradiente claro usa superfícies claras auxiliares.
- Acentos digitais usam pontos ciano com 18% de opacidade e não recebem eventos de toque.
- Overlays de carregamento preservam contraste e bloqueiam interação duplicada.

## 6. Ícones

- Ícones Material são usados com rótulos semânticos quando transmitem informação.
- Campos usam email, cadeado e pessoa; ações usam setas e ícones textuais equivalentes.
- O botão Google usa ícone genérico de conta, sem copiar logotipo de terceiro da referência.
- Não existe botão Apple nesta etapa.

## 7. Campos

- Normal: superfície elevada e borda padrão.
- Foco: borda primária de 2 px, além do foco nativo.
- Erro: borda vermelha, mensagem textual e semântica.
- Desabilitado: cor `disabled`, sem ação.
- Senha: botão de exibir/ocultar com tooltip.
- Teclado, autofill e ação seguinte/concluir são configurados por tipo de campo.

## 8. Botões

- Primário: superfície clara, texto escuro, seta e altura mínima de 56 px.
- Social: contorno, ícone genérico e rótulo que pode quebrar em até duas linhas.
- Carregamento: ação desabilitada e indicador de progresso com região semântica ativa.
- Cancelamento do Google é informação, não erro grave.
- Divisores flexionam e limitam o texto para não estourar com fonte ampliada.

## 9. Composição de autenticação

- `AuthScaffold`: fundo, SafeArea, rolagem, teclado, largura e superfície curva.
- `AuthHero`: ativo fotográfico local, `BoxFit.cover`, proporção responsiva e fallback seguro.
- Marca financeira própria: círculo, tendência e carteira; nenhuma identidade comercial externa.
- A transição entre hero e formulário é feita com widgets e raios reais.
- Login, cadastro e redefinição compartilham componentes, sem duplicar implementação visual.

## 10. Acessibilidade

- Textos e ícones acompanham cores de estado.
- Ações têm rótulos, tooltips, alvo de toque e estados habilitado/desabilitado.
- Mensagens dinâmicas usam regiões semânticas ativas.
- SafeArea e rolagem evitam perda de conteúdo em tela pequena e teclado aberto.
- Testes cobrem 320 px, teclado simulado, escala de texto até 1,8, temas claro/escuro e semântica principal.

## 11. Limitações conhecidas

- A validação manual em dispositivo Android aprovou a interface, navegação, fluxos de autenticação por e-mail e login Google.
- As telas de configuração de perfil, perfil e consentimentos reutilizam SafeArea, rolagem, escala tipográfica, semântica e estados de carregamento do sistema visual aprovado.
- Golden tests não foram introduzidos porque nenhuma dependência ou baseline visual adicional foi autorizada.
- Web, Windows e iOS exigirão configuração Firebase oficial específica e revisão responsiva quando forem adicionados.
- Os textos jurídicos no aplicativo são provisórios e exclusivos de development; produção permanece bloqueada.

## 12. Aplicação em categorias e lançamentos

- Ícone e cor de categoria vêm de catálogos fechados e sempre aparecem acompanhados de texto.
- Receita e despesa usam sinal, rótulo e ícone; verde/vermelho não são o único meio de distinção.
- Formulários monetários aceitam padrão BRL, mas persistem somente centavos inteiros positivos.
- Estados vazio, carregando, erro, confirmado e cancelado possuem mensagens explícitas.
- Filtros e resumos permitem quebra de texto; ações da home usam largura total em telas estreitas.

## 13. Aplicação no acesso proprietário

- O selo “Acesso proprietário” usa `ActionChip`, ícone administrativo, contraste do tema e alvo de toque nativo.
- A semântica anuncia a finalidade completa do selo sem expor identidade técnica.
- A Área do proprietário usa cartões, textos e ícones; nenhum estado depende apenas de cor.
- Conteúdo administrativo permanece oculto durante carregamento ou falha de autorização.
- A página usa SafeArea, rolagem, largura máxima e textos flexíveis para tema claro/escuro, tela pequena e fonte ampliada.

## 14. Aplicação no dashboard financeiro

- A Home segue uma hierarquia de leitura curta: cabeçalho pessoal, filtros, saldo total, resumo do período, ações rápidas, gráficos, planejamento e lançamentos recentes.
- O cartão principal mantém saldo atual e resultado mensal como conceitos distintos. Receitas, despesas e resultado possuem texto, valor, ícone e cor semântica.
- A comparação mensal usa `CustomPainter` nativo e legenda textual; nenhuma dependência gráfica externa foi adicionada.
- A ocultação de valores é global para o dashboard, preserva a estrutura visual e anuncia “Valor oculto” para tecnologias assistivas.
- Compromissos pendentes aparecem somente em planejamento e nunca são apresentados como parte do saldo real. Atrasos são derivados pela data civil de São Paulo e ficam separados dos próximos vencimentos.
- Ações rápidas usam grade de duas colunas, alvo mínimo de 48 px, feedback Material e rotas específicas que preselecionam receita ou despesa quando aplicável.
- O conteúdo usa largura máxima de 720 px, margem compacta até 360 px, quebra por `Wrap`, SafeArea e rolagem vertical. Carregamento mantém blocos com altura estável; vazio e erro oferecem próximo passo e retry.
- A barra de navegação inferior não integra o produto. Privacidade, troca rápida de tema e Menu ocupam o cabeçalho; contas, categorias, lançamentos, compromissos, perfil e aparência usam o painel agrupado e preservam retorno seguro.
- O dashboard reutiliza os providers existentes de workspace e compromissos. Não cria consultas, projeções financeiras ou fontes de verdade paralelas.
- Cada refinamento visual permanece sujeito à aprovação manual no APK debug development antes de commit ou push.

## 15. UI-2 — temas e análise local

- A preferência inicial segue o sistema e pode ser alterada no cabeçalho ou em Perfil > Aparência para Sistema, Claro ou Escuro.
- A escolha é carregada antes da árvore visual e persistida apenas no aparelho; não reinicia o roteador nem sincroniza com Firebase.
- `ColorScheme` cobre controles Material, diálogos, bottom sheets, calendários e snackbars. `AppThemeColors` cobre receita, despesa, atenção, informação, superfícies e trilhas de gráfico.
- O dashboard filtra dados reais por conta, mês anterior, mês atual, ano atual ou intervalo civil. Filtros nunca escrevem documentos nem alteram o saldo canônico.
- Comparação de receitas/despesas e rosca de categorias são nativas, possuem vazio, semântica, legenda textual e ocultação conjunta de valores/percentuais.
- O carrossel usa monogramas e ícones genéricos porque contas ainda não possuem instituição. `ACC-2 — Catálogo de bancos e fintechs` permanece futuro e não coletará credenciais.
- Compromissos pendentes são filtrados por vencimento. Não há filtro por conta antes da liquidação porque o modelo não associa conta à pendência.
- Reserva de emergência, metas, previsão financeira, comparação anual avançada, Open Finance e logos bancários permanecem fora do escopo.

## 16. UI-3 — dashboard sofisticado e minimalista

- A hierarquia móvel passa a ser: cabeçalho compacto, filtros, saldo/resultado, receitas/despesas, ações rápidas, comparação, categorias, compromissos e lançamentos.
- Saldo oficial usa 32 px e permanece independente do período. Resultado usa 20 px na mesma superfície e não reaparece como KPI separado.
- Receitas e despesas são dois indicadores equivalentes. Em 320 px ou fonte ampliada podem empilhar sem perder o contexto do período.
- Ações rápidas formam faixa horizontal com continuidade visual; cada alvo preserva pelo menos 48 px e feedback Material.
- A comparação usa duas colunas agrupadas com escala e linha de base comuns. Gradientes, topo, face lateral e sombras discretas criam profundidade 2.5D sem perspectiva exagerada; legenda, valores, período e resultado permanecem textuais.
- A rosca usa 140–152 px, começa em coral controlado e mostra até quatro categorias reais; excedentes são somados em “Outras”.
- A Home não duplica a lista de contas: o filtro compacto permanece no topo e Contas e carteiras é acessada pelo Menu. Carrossel, Ver todas e Adicionar conta ficam restritos às telas administrativas adequadas.
- Contas usam monogramas e ícones genéricos. Logos e instituições continuam bloqueados até o futuro ACC-2.
- A tela de contas usa total azul-marinho/petróleo no escuro e superfície clara no tema claro. Cartões informam saldo positivo, zerado ou negativo por ícone e texto.
- Filtros são chips horizontais; seletores usam bottom sheets e mês/ano usa diálogo nativo. “Limpar” só aparece quando o contexto difere de todas as contas no mês atual.
- Azul-gelo permanece restrito a seleção, ícones, bordas, gráficos e ações; grandes superfícies ciano não fazem parte da composição.

## 17. INV-1A — acompanhamento manual de investimentos

- Investimentos é acessado por `Menu > Patrimônio > Investimentos`; a Home não recebe cotação, patrimônio estimado nem indicadores fictícios.
- A hierarquia móvel é: cabeçalho enxuto, seletor de carteira, abas Resumo/Ativos/Lançamentos e conteúdo específico rolável. O aviso manual permanece no Resumo sem ocupar o topo de todas as jornadas.
- Quantidade, custo acumulado, preço médio e resultado realizado são derivados exclusivamente das operações registradas. Sem cotação externa, valor atual e rentabilidade não são exibidos.
- O cartão principal usa a mesma linguagem de gradiente, borda e sombra discreta do dashboard, mas se chama “Custo atual acompanhado” e nunca “patrimônio atual”.
- Evolução usa colunas nativas de compras e vendas por período real. Alocação usa rosca compacta pelo custo das posições abertas, alterna classes/ativos e sempre mantém legenda textual acionável.
- A privacidade global oculta conjuntamente valores monetários, quantidades e percentuais, inclusive em cartões, gráficos, posições e histórico.
- Ativos usam busca local, chips Ações/FIIs e ordenação determinística. Lançamentos usam cartões verticais; nenhuma tabela exige rolagem horizontal.
- Compra e venda compartilham formulário por intenção, validação pt-BR, prévia canônica e confirmação explícita. A prévia mostra valor bruto, taxas, valor final, quantidade resultante e possível preço médio de compra.
- Anulação é oferecida somente para a operação mais recente, exige confirmação e explica que o histórico será preservado e a projeção restaurada.
- Estados de carregamento, vazio, erro e retry possuem próximos passos claros. O gerenciador de carteiras reúne criação, edição, arquivamento e restauração sem apagar ativos ou operações.
- Em largura de 320 px e fonte a 180%, ações quebram linha, cartões não dependem de largura fixa e o estado da posição fica abaixo do título quando necessário.
- Temas claro, escuro e sistema reutilizam o sistema visual aprovado; azul-gelo permanece em destaques discretos e não ocupa grandes superfícies.
- Logos, marcas, fotos, ilustrações proprietárias, barra inferior global, paywall, B3, rankings, notícias, agenda automática e rentabilidade de mercado não compõem o redesign.

## 18. INV-PROV-1 — proventos manuais

- Proventos é a quarta aba do módulo e preserva o seletor de carteira acima das abas. Não ocupa a Home nem sugere dinheiro disponível.
- A hierarquia é resumo líquido do período, filtros, colunas recebido/previsto, distribuição por ativo, registros e histórico mensal/anual.
- Colunas compartilham escala e base; rosca e legendas possuem equivalentes textuais. Gráficos vazios explicam a ausência de dados e nunca recebem exemplos fictícios.
- Cartões exibem ativo, tipo, previsão, status, bruto, imposto e líquido. A ação primária confirma recebimento; edição/cancelamento aparecem somente no previsto e anulação somente no recebido.
- O formulário explica antes dos campos que nenhum saldo será alterado, oferece modos total e por unidade, prévia canônica e diálogo de confirmação.
- Privacidade oculta valores e quantidades em resumo, gráficos, cartões, histórico, prévia e confirmação. Datas, tipos e status permanecem legíveis.
- Em 320 px ou fonte a 180%, cabeçalho, filtros e seletor do histórico se empilham; formulários mantêm rolagem com teclado e dropdowns usam a largura disponível.
- Azul-gelo permanece em seleção e destaque discreto. Não são usados logos, marca de referência, cotação, ranking, notícias, B3, paywall ou agenda automática.
