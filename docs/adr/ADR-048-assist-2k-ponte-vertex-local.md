# ADR-048 — ASSIST-2K: ponte Vertex local e fail-closed

## Contexto

O Assistente já possui contrato mínimo de chamada, admissão de contexto,
barreira de resposta fundamentada, roteamento Flash/Pro e ledger de custo. A
integração de runtime precisava continuar isolada do Flutter, do banco default
e de configuração privada, sem ativar chamadas reais nesta etapa.

## Decisão

- O codebase assistant, Node 22, usa @google-cloud/vertexai 1.12.0 como
  dependência direta oficial, acessada apenas por importação dinâmica dentro do
  adaptador de runtime.
- A identidade runtime fornece ADC e o identificador genérico do projeto
  somente no ambiente autorizado. Não há chave, URL, projeto, conta de serviço
  ou credencial versionados.
- ASSISTANT_REAL_PROVIDER_ENABLED começa ausente/falso. O kill switch é ativo
  por ausência e só pode ser desativado explicitamente pelo parâmetro inverso
  ASSISTANT_KILL_SWITCH_DISABLED=true.
- Enquanto qualquer controle estiver fechado, o adaptador falha antes de criar
  o cliente ou ler a configuração de runtime. A callable responde
  safe_unavailable.
- Mesmo com ambos os controles futuramente abertos, os leitores de
  autorização, contexto, uso e ledger permanecem fail-closed nesta etapa.
  Portanto não existe caminho operacional até o Vertex nem acesso ao banco
  default.
- Flash é a rota lógica padrão; Pro só pode ser escolhido pelo roteador
  server-side. As saídas devem ser JSON estruturado e passam pela barreira
  fundamentada antes de qualquer resposta.
- Os tetos máximos reserváveis são 20 centavos para Flash e 100 centavos para
  Pro; o ledger futuro continua sendo a autoridade para os limites de R$ 5 por
  dia e R$ 45 por mês.
- O lockfile usa override aninhado de gaxios 6.3.0 sob
  @google-cloud/vertexai → google-auth-library, removendo a cadeia de
  produção vulnerável que trazia uuid 9.0.1. Não há atualização major,
  override global ou npm audit fix --force.

## Consequências

- Não houve deploy, chamada Vertex, segredo, Function adicional, endpoint
  Flutter, acesso Firebase ou leitura de dados de usuário.
- Um roteiro versionado só permite publicar o circuito ainda desligado e exige
  identidade runtime fornecida fora do Git. Ele não foi executado.
- A ativação development exigirá autorização separada para leitores
  server-side mínimos, ledger persistente, revisão de IAM/App Check, testes
  sintéticos e rollback. Produção permanece fora do escopo.

## Verificação

- Testes injetam fakes e comprovam que controles fechados não carregam o SDK,
  cliente, credencial ou rede.
- A árvore de produção instalada sem opcionais passa em npm audit sem
  vulnerabilidades moderadas ou superiores.
- O smoke local importa somente o SDK; não instancia cliente nem chama Vertex.
