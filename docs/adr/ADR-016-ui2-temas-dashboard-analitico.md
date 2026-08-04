# ADR-016 — UI-2: temas persistentes e dashboard analítico

## Contexto

A UI-1 reuniu saldo, resumo mensal, compromissos e atalhos na Home, mas ainda usava tokens escuros diretamente, mantinha `ThemeMode.system` fixo e não oferecia filtros ou distribuição de despesas. O modelo atual de contas também não possui instituição bancária.

## Decisão

- Manter `ThemeData` como fonte global de estilos e adicionar `AppThemeColors` para cores semânticas e superfícies que não cabem no `ColorScheme`.
- Oferecer as preferências Sistema, Claro e Escuro, com Sistema como padrão. A escolha fica somente no aparelho, na chave `appearance.theme_mode`, por um adaptador de `shared_preferences` atrás de contrato próprio.
- Carregar a preferência antes de `runApp` para evitar troca visível do tema durante a primeira rota. Mudanças posteriores atualizam o `MaterialApp.router` sem recriar o roteador ou perder a pilha.
- Respeitar a redução de animações do sistema e limitar a transição normal de tema a 220 ms.
- Calcular indicadores, gráficos e filtros apenas na camada de apresentação, sobre as listas próprias já confirmadas pelos providers. Nenhum documento, saldo ou resumo persistido é alterado.
- Filtrar lançamentos por conta e intervalo civil inclusivo de `America/Sao_Paulo`. O saldo mostrado continua sendo o saldo atual oficial, total ou da conta selecionada; o período afeta receitas, despesas, resultado, categorias e lançamentos.
- Filtrar compromissos pendentes pelo vencimento no período. Uma pendência não possui conta antes da liquidação, por isso o filtro de conta não é aplicado a compromissos.
- Representar contas com ícones genéricos e monogramas. Não inferir instituição pelo nome e não usar logos de terceiros.

## Consequências

- `shared_preferences` 2.5.5 é a única dependência adicionada e guarda somente aparência, nunca dados financeiros ou credenciais.
- Os filtros são locais e proporcionais ao volume já carregado. Paginação, projeções e agregados remotos exigirão desenho futuro específico.
- A distribuição por categoria e a comparação de receitas/despesas usam `CustomPainter`, sem biblioteca externa de gráficos.
- Valores e percentuais dos gráficos são ocultados junto com o modo de privacidade do dashboard.
- `ACC-2 — Catálogo de bancos e fintechs` fica futuro. Deve suportar bancos, bancos digitais, fintechs, carteiras digitais, dinheiro, outro e múltiplas contas na mesma instituição, sem coletar credenciais bancárias.
- Reserva de emergência, metas, previsão financeira e comparação anual avançada permanecem fora do UI-2.

## Estado

Implementado e aprovado visualmente no celular em 04/08/2026, após a consolidação UI-3B. Nenhum schema financeiro, regra Firestore ou dado remoto foi alterado.
