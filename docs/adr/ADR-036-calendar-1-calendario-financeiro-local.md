# ADR-036 — CALENDAR-1: calendário financeiro local e previsões derivadas

Data: 27/08/2026
Situação: implementado somente localmente; sem Google Calendar em nuvem, Firebase ou qualquer serviço externo.

## Contexto

`payables` e `receivables` já possuem vencimento civil, estado terminal e, quando liquidados, data de movimentação distinta. O aplicativo precisava de uma visão temporal única sem transformar previsão em saldo, lançamento ou pagamento automático.

## Decisão

1. O calendário é projetado exclusivamente de compromissos confirmados do próprio usuário. `pending`, `overdue`, `paid`, `received`, `cancelled` e `voided` são exibidos sem criar novo estado financeiro; atraso continua derivado pela data civil de `America/Sao_Paulo`.
2. Vencimento e movimentação real permanecem campos separados. Uma liquidação é mostrada na agenda, mas não integra previsão de entradas/saídas pendentes.
3. Recorrência é um plano local por dispositivo, vinculado a um compromisso-modelo já existente. O plano guarda somente referência, frequência, intervalo, âncora e estado; não copia descrição, categoria, valor, conta, UID ou lançamento.
4. Toda ocorrência recorrente é `forecast`: não é pendência, não cria conta, lançamento, saldo, cobrança ou confirmação. A regra mensal aplica o último dia quando a âncora não existe no mês destino.
5. Recorrência pode ser cancelada, mas nunca excluída ou restaurada por esta interface. O cancelamento preserva o registro local e não altera o compromisso-modelo nem seu histórico financeiro.
6. A integração Android usa apenas o provedor local do próprio aparelho. A permissão `READ_CALENDAR` só é solicitada depois de um toque explícito em “Escolher calendários permitidos”; nenhuma agenda ou evento é lido automaticamente. As leituras posteriores recebem somente os IDs escolhidos pelo usuário e são exibidas sem cache ou log. Não há canal nem permissão de escrita: criar, alterar ou excluir evento externo permanece indisponível. Um incremento futuro deverá exigir, além da seleção, confirmação específica, recente e com digest para cada mutação externa.
7. O Assistente pode no futuro consultar a projeção e produzir proposta de lembrete. `draftReminder` é somente proposta e nunca autoriza pagar, receber, concluir ou alterar um compromisso sem confirmação exata em executor separado.

## Consequências

- O APK pode oferecer agenda e previsões honestas sem nova coleção, Rule ou deploy.
- Planos recorrentes não acompanham automaticamente outros dispositivos e não são fonte canônica financeira; uma sincronização futura exigirá incremento próprio, modelo, Rules, migração e revisão de privacidade.
- Não há integração com Google Calendar em nuvem, serviço remoto, criação de evento externo ou exclusão externa nesta etapa.
