# INV-1A — Investimentos manuais

## Objetivo e fronteira

O módulo acompanha ações e fundos imobiliários em BRL a partir de operações inseridas manualmente. Ele não movimenta dinheiro no núcleo financeiro: contas, saldo, receitas, despesas, compromissos, saldo inicial e resumo mensal permanecem inalterados.

Não há cotações, APIs externas, corretoras, Open Finance, dividendos, impostos, desdobramentos, bonificações, subscrições, transferências de custódia ou dados simulados.

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

O redesign UI-INV-1B permanece integralmente na apresentação. A área usa seletor de carteira e abas Resumo, Ativos e Lançamentos. Evolução de compras/vendas é agregada das operações ativas; alocação usa o custo canônico das posições abertas. Busca, filtros e ordenação não gravam estado remoto.

A prévia do formulário não cria uma segunda regra financeira: quantidade e preço continuam escalados, valor bruto e possível média usam `InvestmentArithmetic`, e a confirmação persiste o mesmo `InvestmentOperationDraft` validado pelo fluxo original. Métricas sem fonte real — cotação, patrimônio de mercado, valorização e rentabilidade não realizada — não possuem campos substitutos.

## Limitação segura

Security Rules não recalculam custo médio nem percorrem todo o histórico. Por isso operações devem ser cadastradas da mais antiga para a mais recente e correções antigas exigem anular primeiro as posteriores. O cliente não promete edição histórica arbitrária nem enfraquece regras para simulá-la.
