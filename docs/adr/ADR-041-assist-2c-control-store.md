# ADR-041 — ASSIST-2C: controle persistente de custo isolado

## Contexto

Uma futura chamada de modelo precisa reservar custo antes de sair do perímetro controlado. O banco financeiro padrão e os dados de usuários não podem participar desse controle.

## Decisão

O controle usa somente um banco Firestore nomeado em development, separado do banco padrão. O ledger aceita exclusivamente `requestId` aleatório, tier, duração, custo máximo reservado, custo confirmado e estado. Valores são centavos inteiros.

Uma transação reserva antes da chamada. Os tetos são R$ 5,00 por dia e R$ 45,00 operacional por mês. Repetição do mesmo `requestId` é idempotente; divergência, estado inconsistente, ausência de reserva ou custo confirmado acima da reserva falham fechados. Uma reserva somente é reduzida depois de uma medição confirmada.

O runtime futuro terá apenas `roles/datastore.user` condicionado à igualdade exata do recurso do banco nomeado. Não recebe acesso ao banco padrão, dados financeiros, Firestore Admin, Storage, Pub/Sub ou permissões administrativas. A Rule isolada do banco nomeado nega leitura e escrita a qualquer cliente; foi validada por `projects.test` e publicada exclusivamente em development. Não há cliente, Function, Cloud Run, segredo, chamada Vertex ou dado real neste incremento.

Um orçamento development de R$ 50,00 alerta em 50%, 80% e 100%. Alertas não interrompem faturamento nem substituem o ledger.

## Validação pré-publicação

A fonte deny-all foi avaliada inline pelo método oficial `projects.test`, sem ruleset ou release persistente. Os dez casos sintéticos — anônimo e autenticado para `get`, `list`, `create`, `update` e `delete` no banco nomeado — retornaram `DENY`. A fonte validada foi então publicada exclusivamente no banco nomeado development, sem alterar a Release do banco `(default)`.

## Consequências

O primeiro adaptador real deverá usar transações Firestore e tempo de servidor. A regra inicial do banco nomeado permanece fechada ao cliente; o teste negativo do runtime contra o banco padrão é obrigatório antes de qualquer Function.
