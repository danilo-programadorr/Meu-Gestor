# Matriz de permissões do Assistente Financeiro Pessoal

## Pré-condições comuns

Toda leitura exige Auth, App Check, e-mail verificado, perfil jurídico atual, consentimento IA vigente confirmado no servidor e UID próprio. Owner não possui bypass. O cliente não envia UID nem contexto.

| Capacidade | Sem confirmação | Após confirmação explícita | Observação |
|---|---:|---:|---|
| ler contexto financeiro próprio | permitir | n/a | snapshot server-only minimizado |
| explicar e resumir | permitir | n/a | toda afirmação factual cita evidência |
| comparar períodos/ativos próprios | permitir | n/a | apenas dados realmente disponíveis |
| perguntar por dado ausente | permitir | n/a | resposta não é persistida automaticamente |
| sugerir alternativas | permitir | n/a | sem recomendação ou ordem financeira |
| criar/editar item financeiro | negar execução; permitir prévia | futuro: executor separado | revalidar revisão, invariantes e idempotência |
| arquivar/restaurar | negar execução; permitir prévia | futuro: executor separado | respeitar histórico e regras do módulo |
| cancelar/anular/excluir | negar execução; permitir prévia | futuro: executor separado | consequência irreversível precisa ficar explícita |
| resetar dados/excluir conta | negar | negar | usar exclusivamente o fluxo de privacidade dedicado |
| alterar Auth, owner ou entitlement | negar | negar | fronteira administrativa fora do assistente |
| acessar dados de outro UID | negar | negar | inclusive owner |
| acessar segredo/configuração/log interno | negar | negar | nunca entra no contexto ou resposta |

## Matriz de dados

| Dado | Montagem server-side | Envio ao provedor | Memória ASSIST-0 |
|---|---:|---:|---:|
| valores, datas e estados próprios necessários | permitir | permitir, tipado/minimizado | negar |
| agregados determinísticos | permitir | permitir com evidência | negar |
| ticker e cotação pública atrasada | permitir | permitir com origem/horário | negar |
| descrição ou nome de categoria | permitir | permitir somente após filtro de conteúdo | negar |
| UID, e-mail, nome pessoal, ID persistido | permitir somente para autorização interna | negar | negar |
| senha, token, chave, credencial, App/Project ID | negar | negar | negar |
| dado pessoal/financeiro de terceiro | negar | negar | negar |
| entitlement, owner, grant e operação de privacidade | negar como contexto | negar | negar |
| módulo futuro sem dado real | declarar ausente | declarar ausente | negar |

## Casos negativos obrigatórios

Ausência ou divergência de Auth, App Check, e-mail, perfil, UID, consentimento, versão, confirmação do servidor ou evidência falha antes de liberar resposta. Campos extras do cliente, contexto fornecido pelo cliente, segredos, identificadores pessoais longos e evidência desconhecida são recusados. Resposta de provedor não executa mutação.
