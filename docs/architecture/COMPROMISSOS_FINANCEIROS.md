# FIN-5A — Compromissos financeiros

## Estado

FIN-5A-0, FIN-5A-1 e FIN-5A-2 foram autorizados em 02/08/2026. Domínio, persistência Firestore, regras locais e testes no Emulator Suite estão implementados; interface permanece fora do escopo.

## Fonte canônica

`payables` e `receivables` representam compromissos. Eles nunca alteram diretamente o saldo real. `transactions` continua sendo a fonte canônica dos movimentos efetivados.

Um compromisso confirmado referencia exatamente um lançamento, e o lançamento esquema 2 referencia seu compromisso. Vencimento e movimentação são datas civis independentes.

## Estados

Conta a pagar:

- `pending`: editável, sem lançamento;
- `paid`: pagamento confirmado e lançamento de despesa ativo;
- `cancelled`: pendência cancelada sem lançamento;
- `voided`: pagamento anteriormente confirmado foi anulado e o lançamento vinculado foi invalidado.

Conta a receber:

- `pending`: editável, sem lançamento;
- `received`: recebimento confirmado e lançamento de receita ativo;
- `cancelled`: pendência cancelada sem lançamento;
- `voided`: recebimento anteriormente confirmado foi anulado e o lançamento vinculado foi invalidado.

`cancelled` e `voided` são terminais. Nenhum estado permite exclusão física ou restauração silenciosa.

## Atraso e datas

Atraso é calculado por:

```text
status == pending && dueDate < hoje em America/Sao_Paulo
```

Vencimento no dia atual não está atrasado. O objeto `SaoPauloCivilDate` representa ano, mês e dia sem confundir data de negócio com instante técnico. A convenção persistida permanece 03:00 UTC, correspondente à meia-noite de São Paulo na convenção vigente do projeto.

`cancelledAt`, `voidedAt`, `createdAt` e `updatedAt` são instantes técnicos de auditoria; `dueDate` e a data da movimentação são datas civis.

## Contrato de persistência

O contrato separa criação, edição de pendência, confirmação, cancelamento e anulação. `FirebaseCommitmentRepository` usa transações Firestore e confirma no servidor o compromisso e o lançamento vinculado como uma única mutação lógica.

O ID de lançamento é gerado uma vez por tentativa. `revision` identifica concorrência. Repetição ou recuperação após timeout consulta o estado confirmado: se conta, data e vínculo forem equivalentes, retorna o lançamento já criado; divergência produz conflito. Duas confirmações concorrentes podem ter IDs propostos distintos, mas apenas a primeira grava e a outra reconcilia com o vínculo vencedor.

`settlementAccountId` permanece nulo em `pending`/`cancelled` e registra a conta usada em `paid`/`received`/`voided`. Ele permite que as regras comparem a conta do compromisso com `transactions.accountId`, além de valor, categoria, data, tipo e origem.

Lançamentos novos são gravados no esquema 2. Origem manual usa `originType=manual` e `originId=null`; liquidações usam `payable` ou `receivable` e o ID do compromisso. Documentos esquema 1 continuam legíveis, editáveis e anuláveis como manuais, sem migração.

## Estratégia proposta para o saldo inicial

### Problema

Hoje `openingBalanceCents` pode ser alterado no formulário, mapper, repositório e Security Rules mesmo depois de existirem lançamentos. Bloquear somente o campo na interface não protege a integridade porque um cliente modificado ainda poderia gravar diretamente no Firestore.

Security Rules não conseguem consultar arbitrariamente se existe qualquer lançamento de uma conta. Um booleano controlado apenas pelo cliente também não é prova confiável, e introduzir marcador de primeiro movimento exigiria migração ou backfill dos dados existentes.

### Proposta recomendada, ainda não implementada

1. Tornar `openingBalanceCents` imutável para todas as contas existentes e futuras após a publicação da correção.
2. Separar no domínio o modelo de criação do modelo de edição; edição deixa de receber saldo inicial.
3. Remover o campo dos mapas de atualização do repositório.
4. Remover `openingBalanceCents` das chaves permitidas por `isValidAccountUpdate` em `firestore.rules`.
5. Manter a interface apenas como reflexo desses controles, nunca como controle principal.
6. Criar, em incremento futuro próprio, uma operação de ajuste de saldo auditável que gere movimento canônico, em vez de reescrever o saldo inicial.

Essa opção bloqueia também a correção direta em contas que ainda não possuem movimentos. O custo é intencional: sem backend capaz de consultar movimentos ou marcador confiável previamente migrado, essa é a única alternativa simples que fecha a regra no servidor sem estado auxiliar vulnerável.

### Alternativas não recomendadas

- esconder o campo apenas na interface: não protege gravação direta;
- confiar em flag gravada livremente pelo cliente: permite contorno;
- consultar lançamentos a partir de Security Rules: consultas arbitrárias não são suportadas;
- introduzir Cloud Function apenas para essa edição: adiciona backend, operação externa e custo antes de autorização;
- criar marcador de primeiro movimento sem migração: deixaria contas existentes em estado ambíguo.

## Limites atuais

- as regras e a persistência existem somente no código local e não foram publicadas;
- não existem controllers, providers, rotas ou telas de compromissos;
- recorrências, parcelamentos, liquidações parciais, juros, multas, descontos e notificações permanecem fora do escopo;
- a imutabilidade de `openingBalanceCents` não foi implementada e pertence a incremento futuro separado, junto da operação auditável de ajuste.
