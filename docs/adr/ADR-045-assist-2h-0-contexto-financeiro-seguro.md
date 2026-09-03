# ADR-045 — ASSIST-2H-0: contexto financeiro seguro do Assistente

## Contexto

O Assistente já possui contrato de fatos tipados, consentimento, aliases e
barreira fail-closed. Faltava uma ponte local que reunisse somente fontes
financeiras próprias confirmadas, sem acoplar a callable ao banco padrão.

## Decisão

- A ponte ESM `AssistantFinancialContextBridge` recebe leitores injetados para
  contas, lançamentos, compromissos, calendário financeiro, investimentos e
  proventos. Ela não importa SDK, cliente de rede ou persistência.
- Cada leitor recebe o UID somente no limite interno server-side e devolve
  snapshot estrito sem ID persistido. A saída para o provedor contém apenas
  fato tipado, período UTC, fonte fechada e alias efêmero `ev_*`.
- Dinheiro permanece em centavos inteiros BRL. Texto, datas e números são
  validados; ponto flutuante, UID, e-mail, token, segredo, campos extras,
  dados de terceiros e fonte desconhecida são recusados.
- Qualquer fonte não confirmada invalida a montagem inteira. Não há contexto
  parcial, dado inventado ou leitura de cache/escrita pendente.
- O contexto continua sem memória, sem mutação e sem chamada remota. A
  callable publicada permanece desligada e sem acesso ao banco `(default)`.

## Consequências

Uma futura implementação de leitores requer autorização separada, identidade
com privilégio mínimo e auditoria de acesso. Ela não pode alterar este contrato
nem habilitar Vertex, endpoint Flutter, Secret Manager ou provedor por si só.
