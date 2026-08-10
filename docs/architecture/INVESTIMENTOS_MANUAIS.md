# INV-1A — Investimentos manuais

## Objetivo e fronteira

O módulo acompanha ações e fundos imobiliários em BRL a partir de operações inseridas manualmente. Ele não movimenta dinheiro no núcleo financeiro: contas, saldo, receitas, despesas, compromissos, saldo inicial e resumo mensal permanecem inalterados.

Não há cotações, APIs externas, corretoras, Open Finance, agenda automática, cálculo tributário, desdobramentos, bonificações, subscrições, transferências de custódia ou dados simulados. O INV-PROV-1 aceita somente proventos informados manualmente e imposto retido conhecido pelo usuário.

## Camadas

- `domain`: carteiras, ativos, operações, valores escalados, projeção determinística, falhas tipadas e contrato de repositório;
- `data`: mappers de campos exatos, diagnóstico sanitizado, provider e `FirebaseInvestmentRepository`;
- `presentation`: controllers Riverpod, formulários, lista de carteiras/posições e detalhe com histórico;
- `firestore.rules`: autorização por UID, perfil jurídico, contratos fechados e vínculo atômico entre ativo e operação.

Tipos Firebase não entram no domínio e widgets não acessam Firestore diretamente.

## Representação numérica

| Conceito | Representação | Escala |
|---|---:|---:|
| dinheiro e taxas | `int` em centavos | 2 |
| quantidade | `int quantityScaled` | 8 |
| preço unitário | `int unitPriceScaled` | 6 |

O valor bruto em centavos é `roundHalfUp(quantityScaled × unitPriceScaled / 10^12)`. Produtos, rateios e médias usam `BigInt` antes da verificação de `int64`. Nenhum valor financeiro usa `double`.

## Projeção

- compra: `custo += valorBruto + taxas` e `quantidade += quantidadeComprada`;
- venda parcial: baixa custo pela proporção do custo médio, com half-up;
- venda total: baixa exatamente todo o custo restante;
- resultado realizado: `valorBrutoDaVenda - taxasDaVenda - custoBaixado`;
- operação anulada é ignorada;
- posição zerada continua na lista.

Custo, preço médio e resultado são reconstruídos de operações imutáveis. O ativo materializa somente a quantidade e o topo da cadeia necessários à proteção server-side.

## Escritas e concorrência

Criação de operação e atualização do ativo ocorrem na mesma transação Firestore. A operação referencia o topo anterior; o ativo passa a referenciar a nova operação e incrementa `revision`. Venda somente é aceita quando a quantidade disponível é suficiente.

Anulação exige que a operação seja o topo atual. Operação e ativo mudam atomicamente: a operação se torna `isVoided=true` e o ativo restaura quantidade, ID e data anteriores. Repetição, revisão obsoleta ou duas gravações concorrentes têm no máximo um vencedor.

Leituras e alterações relevantes exigem confirmação do servidor. Timeout, indisponibilidade e aborto são tratados como resultado incerto e preservam o mesmo ID de tentativa para reconciliação sem duplicação.

## Experiência e privacidade

Investimentos são acessados pelo grupo Patrimônio no Menu da Home e não ocupam uma seção do dashboard. A interface explica que o acompanhamento não altera saldo e que não existe cotação. Estados de carregamento, vazio, falha e retry são explícitos.

Valores e quantidades seguem a privacidade global compartilhada com a Home. Layouts cobrem temas claro/escuro, 320 px, fonte ampliada, rolagem, alvos de toque, tooltips e texto equivalente a indicadores visuais.

O redesign UI-INV-1B permanece integralmente na apresentação. A área usa seletor de carteira e abas Resumo, Ativos, Lançamentos e Proventos. Evolução de compras/vendas é agregada das operações ativas; alocação usa o custo canônico das posições abertas. Busca, filtros e ordenação não gravam estado remoto.

A prévia do formulário não cria uma segunda regra financeira: quantidade e preço continuam escalados, valor bruto e possível média usam `InvestmentArithmetic`, e a confirmação persiste o mesmo `InvestmentOperationDraft` validado pelo fluxo original. Métricas sem fonte real — cotação, patrimônio de mercado, valorização e rentabilidade não realizada — não possuem campos substitutos.

## INV-PROV-1 — proventos manuais

Cada registro vive em `users/{uid}/investmentIncomeEvents/{eventId}` e referencia carteira e ativo próprios. Ações aceitam dividendo ou JCP; FIIs aceitam rendimento de FII. O evento começa `expected` e pode ir para `received` ou `cancelled`; um recebido pode ir somente para `voided`. Estados terminais não são restaurados e nenhum documento é excluído.

O modo `total` recebe bruto e imposto em centavos. O modo `perUnit` recebe quantidade em escala 8 e valor por unidade em escala 6; o bruto é `roundHalfUp(quantidade × valorUnitário / 10^12)`. O líquido é sempre bruto menos imposto. O domínio usa `BigInt` para intermediários e a data civil segue `America/Sao_Paulo`; somente a data efetiva de recebimento não pode ser futura.

Criação, edição de previsão, recebimento, cancelamento e anulação usam revisão, `mutationId`, timestamps do servidor, leitura server-only e reconciliação após resultado incerto. Controllers bloqueiam múltiplos toques e preservam os IDs da tentativa em timeout, indisponibilidade ou aborto. Valores, datas e referências financeiras ficam imutáveis depois do recebimento.

A aba Proventos usa somente os documentos confirmados: resumo líquido, filtros de período/ativo/tipo/status, colunas de recebido versus previsto nos últimos 12 meses, distribuição dos recebidos por ativo, cartões e histórico mensal/anual. Valores obedecem à privacidade global; em 320 px ou fonte ampliada, cabeçalho, filtros e controles se empilham.

Proventos são acompanhamento patrimonial. Não existe referência a conta, categoria financeira ou `transaction`; criar, receber, cancelar ou anular não muda saldo, receitas, despesas, compromissos, posição do ativo ou resumo mensal.

## Limitação segura

Security Rules não recalculam custo médio nem percorrem todo o histórico. Por isso operações devem ser cadastradas da mais antiga para a mais recente e correções antigas exigem anular primeiro as posteriores. O cliente não promete edição histórica arbitrária nem enfraquece regras para simulá-la.
