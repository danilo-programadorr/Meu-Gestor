# ADR-056 — INV-2C: composição BRAPI operacional em development

## Contexto

A BRAPI foi aprovada como fonte independente de cotações atrasadas. Os
contratos provider-neutral, o gateway, a persistência transacional e o leitor
Flutter já existiam, mas a Function exportada permanecia desativada, aceitava
uma futura lista interna de alvos e não empacotava os módulos compartilhados no
artefato do codebase.

## Decisão

- A BRAPI permanece atrás do gateway provider-neutral. O token é declarado por
  `defineSecret` e só será materializado no Secret Manager durante uma ativação
  externa autorizada; não existe valor no código, APK, catálogo ou logs.
- `_marketQuoteCatalog/{ticker}` é a única fonte de alvos. Cada documento contém
  somente ticker público, tipo `stock`/`fii`, estado habilitado, versão e horário
  administrativo. O aplicativo não lê, lista ou escreve o catálogo.
- A execução aceita POST vazio de um Scheduler autenticado por IAM. O endpoint
  privado rejeita listas no payload e deriva o identificador idempotente do
  horário fornecido pelo Scheduler. Cabe ao perímetro Cloud Run rejeitar quem
  não possui `run.routes.invoke`.
- O contrato provider-neutral suporta até 50 tickers, mas a composição BRAPI
  development falha fechada acima de um ticker ativo, conforme o plano Gratuito.
  `PETR4` é o único item inicialmente habilitado; `HGLG11` permanece cadastrado
  e desabilitado porque a cobertura pública do plano não inclui FIIs.
- A composição usa Firestore Admin exclusivamente nas coleções globais de
  catálogo, snapshot, lease, request e circuito. Nenhum UID, carteira,
  quantidade, custo ou operação entra na consulta à BRAPI.
- Falha de transporte, timeout, resposta inválida ou ticker omitido falha
  fechada, registra apenas código enumerado e mantém circuit breaker. Snapshot
  anterior pode continuar visível somente conforme seu próprio `staleAfter`.
- Os contratos compartilhados são copiados de forma determinística no
  predeploy; dependências, segredos e configuração privada não são copiados.
- Os documentos técnicos de requisição recebem `expiresAt` por 30 dias. A
  política TTL correspondente é um recurso externo separado e só será criada
  durante uma ativação development explicitamente autorizada.
- FREE-1 governa a leitura no aplicativo. Cotações não dependem de entitlement,
  não alteram operações e não geram total de carteira com cobertura parcial.

## Consequências

- Código e testes locais não criam Function, Scheduler, identidade, segredo,
  IAM, catálogo real ou chamada BRAPI. Esses recursos exigem plano e autorização
  externos antes da ativação development.
- O runtime de Firestore usa `@google-cloud/firestore` 8.7.1 como dependência
  direta porque o artefato omite dependências opcionais. A instalação
  reproduzível e a auditoria do artefato são gates obrigatórios.
- O catálogo inicial e a frequência precisam reproduzir exatamente cobertura,
  atraso e limites contratados. Não há descoberta a partir de carteiras.
- O atraso declarado é 30 minutos e o snapshot vence após 60 minutos. O limite
  operacional não é apresentado como cota garantida: execuções manuais também
  consomem a franquia e devem permanecer excepcionais e acompanhadas.
