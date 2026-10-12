# NEWS-1 — Notícias financeiras via Marketaux

## Escopo aprovado

A navegação global oferece Notícias no espaço anteriormente ocupado por
Ranking. Ranking permanece dentro de Investimentos. O feed possui somente
Mercado, Economia e Internacional, com até três matérias por categoria.

O aplicativo não chama o Marketaux. Ele lê por `get` os documentos conhecidos
`marketNewsFeeds/market`, `marketNewsFeeds/economy` e
`marketNewsFeeds/international`. Listagem, escrita e categorias arbitrárias são
negadas pelas Rules.

## Contrato e privacidade

O backend envia ao Marketaux apenas idioma `pt`, termo fixo da categoria,
limite `3` e página `1`. Carteira, ticker, quantidade, UID, email, histórico e
qualquer dado financeiro ficam fora da integração.

Cada snapshot contém somente categoria, provedor, instante de captura,
validade e até três itens com identificador opaco, título, domínio da fonte,
URL HTTPS, publicação e URL HTTPS opcional da miniatura informada pelo
Marketaux. O texto integral e o arquivo da imagem não são armazenados. O app
carrega diretamente a miniatura pública, sem anexar UID, carteira ou dado
financeiro, e a matéria abre externamente na fonte original. Falha ou ausência
da imagem mantém um ícone local seguro.

O plano Free consultado em 11/10/2026 informa 100 requisições diárias, três
matérias por requisição, notícias globais e metadados completos. A interface
identifica o Marketaux, mostra o domínio da fonte e direciona ao artigo
original. Os termos públicos não apresentam uma exigência adicional de
atribuição, mas limitam o uso a finalidade pessoal e não comercial. Por isso,
esta ativação é exclusiva de development; uso comercial ou produção exige
confirmação contratual específica do provedor.

Ausência, cobertura parcial e expiração são visíveis. Snapshot antigo não é
apresentado como atual, e falha de uma categoria impede publicação parcial do
novo ciclo.

## Limites e operação development

- plano Marketaux: gratuito, 100 requisições diárias e até três matérias por
  requisição;
- um ciclo: três requisições, uma por categoria;
- frequência proposta: a cada duas horas em `America/Sao_Paulo`;
- consumo nominal: 36 requisições por dia;
- teto interno: 90 requisições reservadas por dia UTC;
- retry automático: desativado;
- falha: circuit breaker de 30 minutos, preservando o último snapshot como
  desatualizado;
- concorrência: uma instância e uma requisição simultânea;
- publicação: transação única das três categorias.

O teto interno protege somente chamadas originadas por este backend. Consumo
feito fora dele na mesma conta do Marketaux não pode ser medido pelo app.
Cada ciclo reserva as três chamadas antes da rede. Falhas mantêm a reserva;
retry do mesmo identificador é idempotente; uma execução manual válida com
identificador novo também reserva três; transações e lease impedem que chamadas
concorrentes ultrapassem o contador. Requisições rejeitadas antes do provedor
não consomem a reserva porque não podem gerar consumo externo.

## Recursos externos propostos

Nenhum item abaixo é criado por esta implementação local:

- Function privada: `refreshMarketNews`, região `southamerica-east1`;
- codebase Firebase: `news`;
- identidade runtime: `news-runtime-dev`;
- segredo: `MARKETAUX_API_TOKEN`, acessível apenas pela identidade runtime;
- identidade invocadora: `news-scheduler-dev`;
- Scheduler: `refresh-market-news-dev`, expressão `0 */2 * * *`, timezone
  `America/Sao_Paulo`, inicialmente pausado;
- IAM runtime: leitura/escrita Firestore exigida pelos snapshots e controles e
  `secretmanager.secretAccessor` restrito ao segredo específico;
- IAM Scheduler: `run.invoker` restrito ao serviço de destino.

Antes da ativação, identidades e permissões existentes devem ser inspecionadas,
o segredo deve ser fornecido por entrada privada e uma execução acompanhada
deve comprovar contrato e Rules. Produção permanece fora do escopo.
