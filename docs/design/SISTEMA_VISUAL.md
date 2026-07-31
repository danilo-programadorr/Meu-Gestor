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
| backgroundPrimary | `#040A1A` | fundo escuro principal |
| backgroundSecondary | `#081129` | fundo escuro secundário |
| backgroundElevated | `#0C2237` | elevação e fallback visual |
| surfacePrimary | `#18203E` | campos e cartões escuros |
| borderDefault | `#294A70` | bordas em estado normal |
| primaryCyan | `#17CFFF` | foco, links e ação de destaque |
| primaryBlue | `#2F80ED` | apoio de ação e gradientes |
| chartBlue | `#5A6DA3` | gráficos futuros, não usado como estado |
| positiveGreen | `#74BA76` | confirmação positiva acompanhada de texto/ícone |
| secondaryPurple | `#7447E8` | apoio visual futuro |
| errorRed | `#FF6B7A` | erro acompanhado de texto/ícone |
| textPrimary | `#F0F6FC` | texto principal no tema escuro |
| textSecondary | `#92A8BB` | texto auxiliar no tema escuro |
| disabled | `#6B8599` | controles inativos |

O tema claro usa superfícies auxiliares centralizadas, com texto escuro e ação azul. O tema escuro segue integralmente a base azul-marinho aprovada. Ciano não é usado como texto longo sobre fundo claro. Erro e sucesso nunca dependem somente de cor.

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
- Foco de marca usa brilho ciano com opacidade reduzida; nunca substitui a borda de foco.
- Gradiente escuro oficial: `#040A1A`, `#081129`, `#041746`.
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
- Testes cobrem 320 × 568 px, teclado simulado, escala de texto 1,6, temas claro/escuro e semântica principal.

## 11. Limitações conhecidas

- A validação manual em dispositivo Android aprovou a interface, navegação e fluxos de autenticação por e-mail; o login Google corrigido aguarda novo teste do APK atualizado.
- Golden tests não foram introduzidos porque nenhuma dependência ou baseline visual adicional foi autorizada.
- Web, Windows e iOS exigirão configuração Firebase oficial específica e revisão responsiva quando forem adicionados.
- Os textos jurídicos no aplicativo são provisórios e exclusivos de development; produção permanece bloqueada.
