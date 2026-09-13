# ADR-054 — Corte temporal do contexto e endpoint Vertex global

## Status

Aceita para publicação exclusiva em development.

## Contexto

A callable solicitava o dia civil corrente em `America/Sao_Paulo`, mas a
ponte de contexto exigia que o relógio do servidor já tivesse alcançado o fim
exclusivo desse mesmo dia. Assim, toda consulta durante “hoje” falhava antes
das leituras owner-scoped. Separadamente, o SDK Vertex instalado derivava
`global-aiplatform.googleapis.com` quando `location` era `global`, em vez do
endpoint global suportado `aiplatform.googleapis.com`.

## Decisão

O contexto mantém duas noções independentes:

- `technicalWindow`: limites UTC do período civil solicitado, sempre no
  intervalo `[início, fim exclusivo)` de `America/Sao_Paulo`;
- `availableDataWindow`: corte efetivamente legível, do início civil até o
  menor valor entre o relógio confiável do servidor e o fim do período.

`periodComplete` declara explicitamente se o fim civil já foi alcançado. Um
período futuro continua inválido; um período passado permanece completo; o dia
corrente permanece “hoje”, incompleto, e nenhum fato posterior ao corte pode
ser admitido.

Para Vertex, a configuração adiciona `apiEndpoint: 'aiplatform.googleapis.com'`
somente quando `location === 'global'`. Localidades regionais continuam usando
o host derivado pelo SDK. Projeto e autenticação permanecem fornecidos pela
identidade runtime via ADC, sem chave de API.

## Verificação

Os testes cobrem a falha reproduzida, períodos futuros e inválidos, virada de
dia e mês, exclusão de fatos posteriores ao corte e validação estrita do novo
contrato. Um teste de composição usa os adaptadores reais de contexto, o leitor
de uso owner-scoped com consumo não zero e o ledger transacional para reserva e
confirmação de quota, simulando apenas as bordas externas.

Outro teste intercepta a chamada antes da rede e verifica o host construído
pelo SDK instalado tanto para `global` quanto para `southamerica-east1`.

## Consequências

O contrato Flutter `assist-remote-v1` não muda. A confirmação operacional ainda
depende de uma chamada real pelo aplicativo, que comprovará em conjunto o
registro de uso, as permissões da identidade runtime e a aceitação da resposta
fundamentada pelo contrato do APK.
