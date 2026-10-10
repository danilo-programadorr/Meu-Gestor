# Plano de ativação development — cotações BRAPI

Estado em 10/10/2026: recursos de development criados, Function implantada e
Scheduler mantido pausado até uma atualização acompanhada produzir snapshot
válido. Produção permanece inalterada.

## Recursos propostos

Projeto exclusivo: `meu-gestor-financeiro-dev`.

- Function Gen 2 `refreshDelayedMarketQuotes`, região
  `southamerica-east1`, codebase `quotes`, Node 22, 256 MiB, timeout 30 s,
  concorrência 1, mínimo 0 e máximo 1 instância;
- Secret Manager `BRAPI_API_TOKEN`, acessível somente pela identidade runtime;
- service account runtime
  `quotes-runtime-dev@meu-gestor-financeiro-dev.iam.gserviceaccount.com`;
- service account invocadora
  `quotes-scheduler-dev@meu-gestor-financeiro-dev.iam.gserviceaccount.com`;
- Scheduler `refresh-delayed-market-quotes-dev`, região
  `southamerica-east1`, inicialmente pausado;
- catálogo global `_marketQuoteCatalog` com `PETR4` (`stock`) habilitado e
  `HGLG11` (`fii`) cadastrado, mas desabilitado por ausência de cobertura no
  plano Gratuito, ambos sem vínculo com carteira;
- TTL de 30 dias no campo `expiresAt` de `_marketQuoteRefreshRequests`;
- Rules atuais, que permitem somente `get` de snapshot conhecido pelo aplicativo
  financeiro válido e negam catálogo, listagem, escrita e coleções internas.

O catálogo inicial é deliberadamente representativo e não deriva dos ativos de
nenhuma pessoa. Alterações posteriores são administrativas, globais, auditadas e
limitadas no código a um ticker ativo enquanto vigorar o plano Gratuito; não
existe descoberta pelo aplicativo. O contrato provider-neutral de 50 itens não
é usado para ampliar chamadas BRAPI.

## IAM mínimo proposto

A identidade runtime recebe um papel customizado no projeto contendo somente:

- `datastore.databases.get`;
- `datastore.entities.get`;
- `datastore.entities.list`;
- `datastore.entities.create`;
- `datastore.entities.update`;
- `datastore.entities.delete`.

Ela recebe também `roles/secretmanager.secretAccessor` restrito ao recurso
`BRAPI_API_TOKEN`. O Firestore não oferece escopo IAM por coleção para esse
cliente server-side; a limitação às coleções de cotações permanece no código e
na identidade dedicada.

A identidade do Scheduler recebe somente `roles/run.invoker` no serviço Cloud
Run subjacente à Function. O job usa OIDC com audience igual à URL da Function,
POST e corpo vazio. O agente gerenciado do Cloud Scheduler mantém apenas seu
papel padrão `roles/cloudscheduler.serviceAgent`.

Quem executar a ativação precisa temporariamente de `iam.serviceAccounts.actAs`
nas duas identidades, além das permissões já necessárias para criar a Function,
o Scheduler, o segredo, o papel customizado, o TTL e os documentos de catálogo.
Essas permissões do operador não são concedidas às identidades de runtime.

## Frequência, cobertura e volume

Condições públicas conferidas em 09/10/2026: o plano Gratuito oferece 15.000
requisições por ciclo, um ticker por chamada, histórico de até três meses e
atraso aproximado de 30 minutos. A própria BRAPI o posiciona para testes,
projetos pessoais e protótipos; esta ativação permanece exclusivamente em
development e não autoriza redistribuição como feed nem uso em produção.
Referências: <https://brapi.dev/faq/quais-as-limitacoes>,
<https://brapi.dev/faq/o-plano-gratuito-tem-limitacoes-importantes> e
<https://brapi.dev/legal/terms-of-use>.

O schema oficial da rota de ações não oferece `marketState`; a integração não
inventa esse estado. Cotações válidas são classificadas como atrasadas e vencem
60 minutos após `regularMarketTime`. Referência:
<https://brapi.dev/docs/acoes>.

Proposta conservadora: `*/30 10-18 * * 1-5`, timezone
`America/Sao_Paulo`, sem retry automático. O circuit breaker interno trata
falhas e a próxima janela tenta novamente. Com até 23 dias úteis, são no máximo
414 execuções agendadas e 414 requisições BRAPI por mês para o único ticker
ativo. O atraso declarado é 30 minutos e `staleAfter`, 60 minutos.

Com `PETR4` ativo, a estimativa superior é aproximadamente 3,3 mil leituras e
2,5 mil escritas Firestore por mês. As 414 chamadas representam apenas o
Scheduler em um mês de 23 dias úteis: a execução acompanhada, reprocessamentos
manuais e qualquer mudança de agenda consomem chamadas adicionais. Retry do
Scheduler fica zerado, IAM restringe o invocador e o código rejeita mais de um
ticker ativo, mas não existe contador mensal próprio; o dashboard BRAPI continua
sendo a autoridade sobre o ciclo e consumo. A cota pública atual do plano
Gratuito é 15.000 chamadas por ciclo e um ticker por requisição.

## Ordem e desativação

1. Confirmar limites contratuais sem expor o token.
2. Criar identidades, papel customizado, segredo e catálogo.
3. Publicar Rules e somente a Function `quotes` em development.
4. Conceder invocação somente à identidade do Scheduler.
5. Criar o Scheduler pausado e conferir URL, OIDC, timezone e limites.
6. Habilitar o job e acompanhar uma única execução com logs sanitizados.

Para desativar: pausar primeiro o Scheduler, marcar o catálogo como desabilitado,
desabilitar a versão do segredo e remover `roles/run.invoker` da identidade do
Scheduler. Snapshots existentes não são apagados; tornam-se vencidos conforme o
contrato e o aplicativo os apresenta como indisponíveis/vencidos. A Function
permanece privada até eventual remoção autorizada.
