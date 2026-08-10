# ADR-017 — INV-1A: carteira de acompanhamento manual

## Contexto

O primeiro incremento de investimentos precisa acompanhar ações e fundos imobiliários informados pelo usuário, sem corretora conectada, cotações, Open Finance ou impacto no saldo financeiro. Compras e vendas formam histórico sensível e não podem ser apagadas ou reescritas. Security Rules não conseguem agregar arbitrariamente todas as operações anteriores para recalcular uma posição durante cada escrita.

## Decisão

- Isolar o módulo em `features/investments`, com domínio sem Flutter ou Firebase, contratos de repositório, implementação Firestore e apresentação Riverpod.
- Persistir carteiras, ativos e operações em `investmentPortfolios`, `investmentAssets` e `investmentOperations`, sempre sob `users/{uid}`.
- Usar centavos inteiros para dinheiro, escala de oito casas para quantidade e seis para preço unitário. Cálculos intermediários usam `BigInt` e arredondamento half-up explícito.
- Manter operações confirmadas imutáveis. Correção ocorre por anulação terminal e nova operação; exclusão e restauração são proibidas.
- Aceitar operações em ordem cronológica. Cada operação guarda o ID e a data da operação ativa anterior, formando uma pilha imutável. Somente a operação ativa mais recente pode ser anulada; a anulação restaura atomicamente o topo anterior.
- Materializar no ativo apenas `currentQuantityScaled`, `lastOperationId`, `lastOperationAt` e `revision`. Esses campos existem para Security Rules validarem venda, vínculo, concorrência e anulação atômica; custo, preço médio e resultado continuam derivados do histórico.
- Usar ID determinístico `portfolioId__TICKER` para impedir ticker duplicado na mesma carteira.
- Exigir releitura `Source.server` após alterações. IDs de tentativa são gerados uma vez e preservados em falha incerta para reconciliação idempotente.
- Não associar operações de acompanhamento a contas, lançamentos, receitas, despesas, saldo inicial ou compromissos.

## Consequências

- Compra incorpora taxas ao custo. Venda reduz o resultado realizado pelas taxas e baixa custo médio proporcional; venda total baixa exatamente o custo restante.
- Posição zerada permanece visível e operações anuladas permanecem no histórico, mas não participam da projeção.
- Para corrigir uma operação antiga, o usuário precisa anular antes as operações posteriores do mesmo ativo. Essa limitação é apresentada na interface e evita uma falsa garantia que exigiria backend agregador.
- O módulo não informa valor atual, rentabilidade não realizada, dividendos, eventos corporativos, impostos ou recomendação de investimento.
- Uma integração futura de cotações ou processamento server-side exigirá autorização, modelo de confiança, custos, política de falha e nova decisão arquitetural.

## Estado

Implementado e validado na INV-1A. As regras foram publicadas exclusivamente no Firebase development em autorização posterior e o APK debug development foi aprovado manualmente. Produção não foi acessada.
