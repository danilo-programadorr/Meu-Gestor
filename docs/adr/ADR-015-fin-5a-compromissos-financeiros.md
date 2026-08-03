# ADR-015 — FIN-5A Compromissos financeiros

- Status: aceito e implementado localmente até FIN-5A-2B
- Data: 02/08/2026

## Contexto

O núcleo atual registra somente receitas e despesas já ocorridas. Contas a pagar e a receber precisam existir como compromissos independentes, sem alterar o saldo real antes da confirmação e sem permitir que compromisso e lançamento divirjam.

## Decisão

- Identificar o incremento como `FIN-5A — Compromissos financeiros`, pertencente à macroetapa de controle financeiro e sem relação com a macroetapa 5 de inteligência artificial.
- Persistir contas a pagar em `users/{uid}/payables/{payableId}` e contas a receber em `users/{uid}/receivables/{receivableId}`.
- Usar `pending`, `paid`, `cancelled` e `voided` para contas a pagar e `pending`, `received`, `cancelled` e `voided` para contas a receber.
- Calcular atraso pela data civil atual de `America/Sao_Paulo`; atraso nunca será status persistido.
- Manter vencimento separado da data real da movimentação.
- Não incluir compromissos diretamente no saldo real. Somente um lançamento ativo vinculado participa do saldo e do resumo mensal.
- Evoluir `transactions` para esquema 2 com `originType` e `originId`. Documentos esquema 1 permanecem compatíveis como lançamentos manuais e não haverá migração em massa.
- Confirmar pagamento ou recebimento em uma única transação Firestore, criando exatamente um lançamento e gravando o vínculo nos dois documentos.
- Permitir `pending -> cancelled` sem criar lançamento e sem excluir o compromisso.
- Exigir `paid/received -> voided` quando uma confirmação for anulada, invalidando atomicamente o lançamento vinculado e preservando movimento, vínculo e auditoria.
- Usar `revision` para detectar estado obsoleto e concorrência nas mutações dos compromissos.
- Manter owner sujeito a UID, autenticação, regras financeiras, atomicidade e limites técnicos comuns.

## Incrementos autorizados

- FIN-5A-0: decisões, ADR, matriz de requisitos e proposta técnica para o saldo inicial.
- FIN-5A-1: objeto de data civil, entidades, estados, invariantes, contratos e testes unitários.
- FIN-5A-2: mappers estritos, repositório Firestore, operações atômicas, esquema 2, regras locais e testes isolados no Emulator Suite.
- FIN-5A-2B: simplificação das regras e auditoria dos logs para impedir regressão do limite de avaliação, sem alterar estados, vínculos ou permissões.

Controllers, providers, rotas, telas, publicação das regras e qualquer deploy não fazem parte do FIN-5A-2.

## Fora do escopo

- recorrências;
- parcelamentos;
- pagamentos ou recebimentos parciais;
- juros, multas e descontos;
- notificações.

## Consequências

- O modelo de domínio diferencia cancelamento de pendência e anulação posterior à liquidação.
- As regras validam o vínculo bidirecional com `getAfter()` e negam gravações parciais.
- O mapper de lançamentos aceita os esquemas 1 e 2; novos lançamentos são esquema 2.
- A edição e a anulação isolada de lançamentos vinculados são negadas.
- A estratégia segura para corrigir saldo inicial continua sujeita a aprovação própria e não pode ser aplicada somente na interface.
