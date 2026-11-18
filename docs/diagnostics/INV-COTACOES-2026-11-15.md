# Investigação de atualização das cotações — 15/11/2026

> O diagnóstico inicial abaixo foi preservado como histórico. A recuperação
> autorizada e as verificações posteriores estão na seção final deste documento.

## Escopo e resultado

Inspeção local e leituras sanitizadas exclusivamente em development. Nenhuma
consulta à BRAPI, execução manual do job, alteração IAM, deploy, mudança de
quota, escrita no banco ou geração de APK foi realizada.

O bloqueio operacional comprovado está antes do handler: o Cloud Run rejeita
a invocação do Scheduler com HTTP 403. Não há evidência de que essas tentativas
tenham alcançado catálogo, BRAPI ou persistência.

## Evidências observadas

- Job `refresh-delayed-market-quotes-dev`: `ENABLED`, cron
  `*/30 10-18 * * 1-5`, timezone `America/Sao_Paulo`, OIDC configurado.
- Última tentativa indicada pelo job: `2026-11-13T21:30:01.939583Z`
  (18:30 de Brasília), código 7.
- Os seis registros de término mais recentes consultados no Scheduler
  informaram `PERMISSION_DENIED` e HTTP 403.
- Os 24 registros mais recentes consultados no Cloud Run informaram HTTP 403,
  latência `0s` e rejeição de acesso. Revisão:
  `refreshdelayedmarketquotes-00005-lec`.
- A Function está `ACTIVE`, com timeout 180 s, concorrência 1 e máximo de uma
  instância. A referência ao segredo BRAPI está configurada; o segredo não foi
  lido. Isso não comprova validade da chave nem resposta do provedor.
- A identidade do job corresponde a `quotes-scheduler-dev`. O destino,
  normalizado sem barra final, corresponde ao serviço Cloud Run; a audience
  corresponde exatamente à URL canônica do serviço.
- A política do serviço não contém nenhum binding `roles/run.invoker`. Não há
  bindings diretos para essa identidade na política do projeto. O papel do
  agente gerenciado do Scheduler existe no projeto. Não foi realizada uma
  avaliação completa de condições/grupos/políticas de organizações ancestrais.
- Foram lidos metadados dos quatro snapshots globais, sem paginação pendente.
  A captura mais recente é `2026-10-17T01:24:48.355Z`
  (16/10 às 22:24:48 de Brasília); a validade mais recente terminou em
  `2026-10-19T13:45:00Z` (19/10 às 10:45). Todos estão vencidos nesta revisão.

Não foram registrados tickers associados a carteiras, preços, quantidades,
UIDs, credenciais, URLs de requisições autenticadas ou mensagens brutas.

## Correção operacional mínima proposta — não executada

Conceder `roles/run.invoker` à identidade existente
`quotes-scheduler-dev@meu-gestor-financeiro-dev.iam.gserviceaccount.com`
somente no serviço `refreshdelayedmarketquotes`, região `southamerica-east1`,
projeto `meu-gestor-financeiro-dev`. Manter o serviço privado, sem `allUsers`,
sem papel no projeto inteiro e sem permissões de banco/segredo para o Scheduler.

Após autorização específica de IAM, reler o binding e acompanhar uma execução
do job existente. Conferir entrada do handler, catálogo, resultado do provedor,
captura/validade e leitura no aplicativo. O disparo consome a cota contratada
por ticker e não deve ser repetido sem avaliar seu resultado. Um HTTP 200
isolado não comprova cotações novas: o serviço também pode devolver snapshots
existentes em caminhos de idempotência, lease ou circuito aberto.

Referência oficial: https://docs.cloud.google.com/scheduler/docs/http-target-auth

## Inspeção local e limites

- `InvestmentQuotesPage` invalida somente
  `investmentPortfolioPerformanceProvider` no botão de tentar novamente; esse
  provider depende de `investmentQuotesProvider`, que faz uma consulta única.
  Há um problema potencial de reutilização do resultado/falha nessa rota.
  Requer regressão reproduzida antes de correção. Não explica o HTTP 403 externo.
- Resumo e detalhes possuem caminhos de atualização que invalidam explicitamente
  as cotações. Não se deve generalizar a limitação acima para todas as telas.
- Há divergências históricas no plano de ativação (30 s/um ticker versus código
  atual de 180 s/até 30 tickers). O estado operacional foi conferido diretamente;
  a documentação histórica não foi tratada como prova de ativação.
- Não foi determinada a data nem o autor da retirada/ausência do binding.
  A proximidade entre deploy e última captura não prova causalidade.
- Ainda não é possível garantir sucesso da BRAPI depois da liberação do acesso.
  O próximo bloqueio, se houver, deve ser diagnosticado pela execução real.
- Não foram executadas suítes neste diagnóstico: nenhum código executável foi
  alterado. Alterações locais anteriores, inclusive de segurança e Luma, foram
  preservadas. Não houve commit/push nem acesso a produção.

## Recuperação autorizada — 15 e 16/11/2026

Após autorização específica do proprietário, foi concedido
`roles/run.invoker` exclusivamente à identidade existente do Scheduler no
serviço `refreshdelayedmarketquotes`, em development. A releitura confirmou
o binding sem condição e ausência de invocação pública. Não houve concessão
no projeto inteiro nem acesso adicional a banco ou segredo.

A primeira execução acompanhada ainda recebeu HTTP 403 antes do handler.
A conta estava ativa, a audience era a canônica do serviço, não havia header
de autenticação sobrescrito e o agente gerenciado correto tinha seu papel.
Após a janela de propagação, uma única repetição concluiu com:

- revisão `refreshdelayedmarketquotes-00005-lec`, sem novo deploy;
- entrada HTTP em `2026-11-16T01:57:36.736340Z`, status 200 e duração
  `3.498117116s`;
- `quote_catalog_loaded`: quatro alvos;
- `quote_refresh_completed`: quatro alvos;
- `quote_refresh_http_completed`: quatro alvos e quatro snapshots;
- quatro capturas posteriores ao disparo, todas válidas e classificadas
  `marketClosed`; captura mais recente `2026-11-16T01:57:40.984Z` e menor
  validade `2026-11-16T13:45:00Z`.

Isso demonstra recuperação operacional do caminho Scheduler → handler → BRAPI
→ snapshots, e não apenas HTTP 200 com dados antigos. Não demonstra apresentação
no celular. Foram dois disparos acompanhados no total; o primeiro não entrou no
handler. Nesta continuação não foram feitas novas chamadas à BRAPI.

A consulta de 16/11 confirmou que o job continua `ENABLED`, com o mesmo cron e
timezone, e próxima janela às 10:00 de Brasília. Os quatro snapshots continuavam
válidos antes da abertura. Não se esperam novos negócios durante o fechamento.

### Reparos locais reproduzidos

1. O botão `Atualizar estado` da rota secundária invalidava apenas a projeção de
   rentabilidade. Com outra tela mantendo a consulta observada, a tentativa
   reutilizava o resultado vazio ou a falha em cache. Duas regressões de widget
   falharam antes da correção. Agora a ação invalida o workspace e a consulta de
   cotações compartilhada; ambas as regressões passaram, incluindo o patrimônio
   derivado das novas cotações sintéticas.
2. O SDK instalado emitia `['private']` no manifesto. O código do CLI instalado
   converte esse valor em lista vazia e substitui o binding de invocação em um
   update. Isso demonstra um risco de recorrência em novo deploy, mas não prova
   o autor ou a data da retirada anterior. Uma regressão sobre o manifesto real
   falhou antes da correção. A configuração local agora emite exclusivamente
   `['quotes-scheduler-dev@']`, resolvido pelo CLI no projeto de destino, mantendo
   o endpoint autenticado e restrito à identidade aprovada.

Os reparos de código não foram publicados, commitados nem incluídos em APK.
A liberação operacional IAM já está aplicada e beneficia o APK existente;
o reparo do botão requer um build posterior, e a configuração declarativa
de invocação deve acompanhar a próxima publicação autorizada de cotações.

### Validação local e limites

- Suíte Flutter completa após o reparo do botão: 940 testes aprovados.
- Análise estática dos dois arquivos Dart alterados e `flutter analyze --no-pub`
  global: sem problemas. A execução global em terminal concluiu em 265,9 s;
  as tentativas anteriores sem progresso foram interrompidas e não contabilizadas.
- Domínio de cotações: check e 21 testes aprovados.
- Functions de cotações: check e 24 testes aprovados, incluindo o manifesto.
  A suíte dependente de Emulator fica omitida no comando unitário e foi
  executada separadamente abaixo, não apresentada como cobertura do runner comum.
- Firestore Emulator: 85 testes de Rules e cinco de runtime aprovados, sem
  skips; relatórios JUnit gerados em `.codex-tmp/quotes-repair-20261116-*.xml`.
- A auditoria do log sintético do Emulator não encontrou os diagnósticos
  proibidos pelo repositório. `git diff --check` não encontrou erros; os avisos
  de conversão LF/CRLF não foram tratados como falhas. A verificação limitada
  de padrões de segredo nos arquivos do reparo não encontrou candidatos e
  nenhum arquivo foi adicionado ao staging.
- A revisão estática independente do delta dos quatro arquivos de código
  não encontrou problemas relevantes. Ela não reexecutou testes nem validou
  recursos remotos e não substitui a confirmação visual no dispositivo.
- A invocação direta inicial do JAR falhou ao carregar mensagens de validação
  em `pt_BR`. A repetição usou `-Duser.language=en -Duser.country=US` somente no
  processo filho Java e aprovou as suítes sem modificar as Rules. O erro inicial
  não foi tratado como falha de segurança do produto nem ocultado por testes.
- O JDK portátil e o JAR já existentes foram usados; nada foi instalado ou
  baixado. O processo local de Emulator foi encerrado ao final.
- Não houve mudança no Assistente, dependências, quotas, frequência, controles,
  dados pessoais/financeiros ou produção por este reparo. Alterações anteriores
  alheias a ele continuam preservadas e fora de staging.
- A captura estruturada no Segundo Cérebro retornou `LOCAL_OPERATION_FAILED`.
  `doctor` indicou caminhos acessíveis; `recover` informou zero pendências.
  Nenhuma ampliação de permissões foi tentada. Este documento local preserva
  o aprendizado, sem alegar publicação no vault.
