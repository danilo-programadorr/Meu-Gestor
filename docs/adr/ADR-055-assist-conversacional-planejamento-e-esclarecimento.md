# ADR-055 — Assistente conversacional com planejamento e esclarecimento

## Status

Validada localmente; publicação e confirmação runtime permanecem pendentes de
autorização específica.

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
- O mesmo `gemini-3.8-flash` atende os dois tiers internos. Perguntas simples
  usam `thinkingLevel: LOW`; análises complexas usam `thinkingLevel: HIGH`, sem
  ampliar os tetos existentes de saída ou custo. A requisição não envia
  `candidateCount`, `temperature` ou outros parâmetros incompatíveis com esse
  modelo; schema e nível de raciocínio são os controles autoritativos. O SDK
  usa explicitamente a API GA `v1` no endpoint global.
- Planejamento e composição possuem reservas e confirmações de quota
  independentes e atômicas. Uma consulta fundamentada pode consumir duas
  inferências; um pedido de esclarecimento encerra após a primeira e não lê
  contexto financeiro.
- `clarification_required` usa somente perguntas canônicas do servidor. Texto
  livre produzido pelo modelo não é apresentado como esclarecimento.
- O Flutter mantém no máximo uma continuação em memória e a envia apenas no
  turno seguinte. Ela é apagada ao concluir, sair da conversa, trocar conta,
  ativar privacidade ou descartar o estado. Áudio e transcrição continuam
  locais; voz mostra somente áudio.
- A lista rígida de frases deixa de bloquear perguntas. Entrada não vazia e
  segura segue ao planejador, que pode entender linguagem livre ou solicitar a
  informação ausente.

## Verificação

Os testes cobrem planejamento sem fatos financeiros, seleção mínima de fontes,
períodos relativos em `America/Sao_Paulo`, esclarecimento sem leitura de dados,
duas reservas de quota, composição fundamentada, contrato servidor → Flutter,
continuação efêmera e descarte por privacidade, conta, saída e operação tardia.
O SDK é inspecionado sem rede para confirmar modelo, endpoint, schema,
`thinkingLevel`, candidato unary e tratamento fechado de truncamento, bloqueio
e JSON inválido.

O runtime importa diretamente `@google/genai` 1.52.0, SDK oficial Apache-2.0.
A versão já fazia parte do grafo transitivo do artefato; declará-la diretamente
fixa o contrato do import sem aumentar o conjunto resolvido. O SDK Vertex
anterior permanece por compatibilidade, sem alteração ampla de dependências.

## Consequências

O contrato público `grounded` permanece compatível e ganha o estado fechado
`clarification_required`. As barreiras de Auth, App Check, consentimento,
isolamento por proprietário, ledger e admissão numérica não são reduzidas. A
validação local não comprova latência, permissões runtime nem apresentação de
uma resposta real; isso depende de publicação development e de um único teste
acompanhado pelo aplicativo em autorização posterior.
