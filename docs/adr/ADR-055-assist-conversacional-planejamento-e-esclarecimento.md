# ADR-055 — Assistente conversacional com planejamento e esclarecimento

## Status

Aceita para development. Produção não foi autorizada; a apresentação de uma
resposta real permanece sujeita à confirmação runtime pelo aplicativo.

## Contexto

O fluxo anterior tentava interpretar linguagem livre e compor a resposta
fundamentada em uma única inferência, depois de carregar um contexto amplo. Uma
frase válida, mas ambígua, podia terminar em indisponibilidade em vez de pedir a
informação que faltava. O cliente também aplicava uma lista rígida de termos
antes de consultar o backend.

## Decisão

- A callable executa primeiro um planejamento estruturado sem dados
  financeiros. O plano seleciona intenção, período civil e uma ferramenta
  financeira de catálogo fechado, ou retorna uma categoria fechada de
  esclarecimento.
- Somente um plano completo autoriza leitores owner-scoped. Cada ferramenta
  limita as fontes consultadas; o servidor continua sendo a autoridade sobre
  identidade, período, valores, evidências, fontes e admissão da resposta.
- Toda intenção fundamentada, inclusive listagem de ativos, passa pela mesma
  composição conversacional. Não existe resposta pública montada por frase
  fixa: o modelo controla somente a linguagem, enquanto cada nome e grandeza
  continua vinculado a uma evidência owner-scoped e é revalidado pelo servidor.
- O mesmo `gemini-3.8-flash` atende os dois tiers internos. Planejamento e
  respostas comuns usam `thinkingLevel: LOW`; análises complexas usam
  `thinkingLevel: MEDIUM`, sem
  ampliar os tetos existentes de saída ou custo. A requisição não envia
  `candidateCount`, `temperature` ou outros parâmetros incompatíveis com esse
  modelo; schema e nível de raciocínio são os controles autoritativos. O SDK
  usa explicitamente a API GA `v1` no endpoint global.
- Planejamento e composição possuem reservas e confirmações de quota
  independentes e atômicas. Uma consulta fundamentada pode consumir duas
  inferências; um pedido de esclarecimento encerra após a primeira e não lê
  contexto financeiro.
- `clarification_required` pode usar uma pergunta contextual curta do
  planejador, admitida pelo servidor sem números, identidade, valores ou
  recomendações. Conteúdo fora desse contrato volta para uma pergunta canônica.
- O Flutter mantém no máximo as três mensagens recentes da própria pessoa em
  memória e as envia em ordem no turno seguinte. Respostas e fatos financeiros
  não são reenviados. A memória é apagada ao sair da conversa, trocar conta,
  ativar privacidade ou descartar o estado; no modo de voz, a interface mostra
  somente áudio. A síntese neural ocorre depois da admissão e tem reserva de
  custo própria; texto não a executa.
- A janela inteira é interpretada semanticamente pelo planejador; não existe
  catálogo de frases para reconhecer continuações. Como a saída contém somente
  enums e uma pergunta curta, o teto do planejamento é 384 tokens para impedir
  truncamento da estrutura e do raciocínio interno sem ampliar o teto da
  resposta financeira ou o limite de custo da chamada.
- A lista rígida de frases deixa de bloquear perguntas. Entrada não vazia e
  segura segue ao planejador, que pode entender linguagem livre ou solicitar a
  informação ausente.
- A interface mostra a fala aprovada uma única vez, com fontes e períodos
  compactos abaixo dela. Mensagens de transição e frases das evidências não
  duplicam a resposta; a continuação aceita também o contexto de ativos.
- A identidade pública da assistente é Luma e faz parte das instruções do
  planejador. Perguntas sociais sobre nome, identidade ou capacidades recebem
  resposta natural e segura antes de qualquer leitura financeira. O tratamento pelo primeiro nome,
  por um apelido ou sem nome é uma preferência local, isolada pelo proprietário
  e aplicada apenas ao cumprimento da sessão; ela não é enviada ao modelo,
  à callable, aos logs ou ao serviço de voz.
- Indisponibilidade admitida no modo de voz usa uma fala neural canônica do
  servidor. Se não houver WAV neural válido, o Flutter permanece silencioso e
  não substitui a identidade da Luma pelo TTS local do Android.
- Depois do consentimento efetivo, cada conta vê uma apresentação local única
  da Luma e de seus limites. Esse marcador fica somente no aparelho, isolado
  pelo proprietário, e não integra a consulta remota.

## Verificação

Os testes cobrem planejamento sem fatos financeiros, seleção mínima de fontes,
períodos relativos em `America/Sao_Paulo`, esclarecimento sem leitura de dados,
duas reservas de quota, composição fundamentada, contrato servidor → Flutter,
continuação efêmera, listagem conversacional de ativos, apresentação sem
duplicação e descarte por privacidade, conta, saída e operação tardia.
Também cobrem identidade e capacidades da Luma, áudio neural do fallback sem
promoção para `grounded`, ausência de TTS Android e apresentação única por conta.
O SDK é inspecionado sem rede para confirmar modelo, endpoint, schema,
`thinkingLevel`, candidato unary e tratamento fechado de truncamento, bloqueio
e JSON inválido.

O runtime importa diretamente `@google/genai` 1.52.0, SDK oficial Apache-2.0.
A versão já fazia parte do grafo transitivo do artefato; declará-la diretamente
fixa o contrato do import sem aumentar o conjunto resolvido. O SDK Vertex
anterior permanece por compatibilidade, sem alteração ampla de dependências.

## Consequências

O contrato público `grounded` permanece compatível e mantém o estado fechado
`clarification_required`. A remoção da resposta fixa para ativos faz esse fluxo
usar a segunda reserva e inferência já previstas para as demais intenções. As
barreiras de Auth, App Check, consentimento,
isolamento por proprietário, ledger e admissão numérica não são reduzidas. A
validação local não comprova latência, permissões runtime nem apresentação de
uma resposta real; isso depende de publicação development e de um único teste
acompanhado pelo aplicativo em autorização posterior.
