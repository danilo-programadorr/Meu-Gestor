# Calendário financeiro — CALENDAR-1

## Fonte e isolamento

O calendário financeiro lê somente os estados confirmados de `payables` e `receivables` do UID autenticado e já autorizado pelo portão financeiro. Não consulta dados de outro usuário, owner, assinatura, Google Calendar em nuvem ou serviços remotos. A consulta opcional de eventos do provedor local Android é separada da agenda financeira, exige seleção explícita e nunca alimenta valores, saldo ou estado de compromisso.

Cada entrada preserva:

- vencimento como `SaoPauloCivilDate`;
- data de movimentação real somente quando o compromisso está pago/recebido ou anulado;
- estado derivado ou canônico: pendente, atrasado, pago, recebido, cancelado, anulado ou previsão recorrente;
- direção de entrada/saída e valor em centavos inteiros.

`overdue` é derivado apenas quando o compromisso é pendente e seu vencimento é anterior a hoje em `America/Sao_Paulo`. Vencimento no próprio dia não está atrasado.

## Previsão

A previsão mensal soma somente pendências e ocorrências `forecast` no intervalo civil selecionado. Entradas e saídas são exibidas separadamente e o resultado é sua diferença. Pagamentos/recebimentos concluídos não voltam a integrar esse cálculo.

Previsão não é saldo projetado canônico: não inclui contas, despesas fora de compromissos, receitas futuras inexistentes, cotação, metas, reserva, juros, multa ou qualquer dado ausente. A tela declara essa limitação.

## Recorrências locais

Uma recorrência é um plano de agenda local, por dispositivo, associado a um compromisso-modelo existente. O armazenamento local contém somente referência do modelo, frequência semanal/mensal/anual, intervalo, data âncora, eventual término e estado. Descrição, valor, categoria e conta continuam sendo consultados no compromisso confirmado; se ele não estiver disponível, nenhuma previsão é exibida.

As ocorrências começam depois da âncora para não duplicar o vencimento-modelo. Para mês/ano com dia inexistente, usa-se o último dia do mês. Cancelamento é terminal na experiência atual: preserva o plano sem apagar dados e interrompe somente suas previsões futuras.

## Calendário Android e Assistente

O provedor local Android é opcional. O app solicita `READ_CALENDAR` somente após o usuário abrir a configuração e escolher essa ação; sem permissão e sem calendários selecionados, não há leitura. O adaptador recebe apenas a lista escolhida pelo usuário, não registra nem persiste eventos e não possui método nativo de escrita. Criação, alteração ou exclusão externa permanecem indisponíveis neste incremento. Um adaptador futuro deverá validar confirmação fresca, calendário selecionado, tipo de escrita e digest antes de qualquer mutação externa.

O Assistente continua somente leitura. Ele pode receber uma futura proposta de lembrete (`draftReminder`), mas não tem executor para pagar, receber, concluir ou alterar compromissos. Qualquer ação posterior exigirá confirmação explícita, revisão e revalidação do estado financeiro.
