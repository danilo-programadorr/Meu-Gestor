# ADR-057 — cobertura automática e histórico diário de cotações

## Contexto

O INV-2C lia snapshots globais com segurança, mas o catálogo era manual e o
plano Gratuito da BRAPI, que aceita um ticker por requisição, havia sido
interpretado como um único ticker ativo. Assim, um ativo cadastrado aparecia em
todas as telas, porém podia permanecer sem cotação. O snapshot sobrescrito
também não permitia demonstrar evolução real de mercado.

## Decisão

- Um trigger Firestore dedicado observa ativos owner-scoped e materializa uma
  demanda global opaca. O ID é um SHA-256 da referência interna; UID, carteira,
  nome, quantidade, custo e operações são descartados antes da persistência.
- O catálogo agrega demanda por ticker, desabilita conflitos de classe e não
  aceita listas vindas do aplicativo. Somente ticker público e classe chegam ao
  gateway; somente o ticker chega à BRAPI.
- O plano Gratuito continua limitado a um ticker por chamada. O serviço divide
  até 30 alvos em chamadas sequenciais, com isolamento de falha por alvo,
  idempotência, lease e circuit breaker existentes.
- O snapshot mais novo grava atomicamente um ponto por dia civil de
  `America/Sao_Paulo`. O cliente lê no máximo 30 pontos no detalhe e não calcula
  gráfico quando há menos de dois pontos reais.
- A credencial BRAPI usa exclusivamente o header `Authorization`. O timeout
  proposto é 5 segundos por chamada e 180 segundos por execução, com uma única
  chamada simultânea, `minInstances=0` e `maxInstances=1`.

## Consequências

- O app passa a receber cobertura sem uma lista manual por pessoa, mas o plano
  Gratuito ainda limita o catálogo a 30 tickers ativos e dados atrasados. Acima
  desse teto, o refresh falha fechado em vez de produzir cobertura parcial não
  declarada.
- A agenda de 414 ciclos em 23 dias úteis pode consumir até 12.420 das 15.000
  requisições publicadas. Essa conta não é garantia porque ciclo de cobrança,
  ações manuais e mudança de agenda precisam ser controlados operacionalmente.
- Ativos existentes exigem backfill único após o deploy; triggers não recebem
  eventos anteriores. A série diária requer TTL externo em `expiresAt` para
  manter retenção aproximada de três meses.
- Nenhuma operação, custo, provento, conta ou saldo é alterado. Cobertura
  ausente, vencida ou conflitante continua explícita e nunca vira preço zero.
