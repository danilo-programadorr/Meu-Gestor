# Matriz local de regras — INV-1A investimentos manuais

Escopo: `investmentPortfolios`, `investmentAssets` e `investmentOperations` sob `users/{uid}`. Execução exclusivamente no Firestore Emulator com Project ID `demo-meu-gestor-financeiro`.

| Caso | Resultado esperado |
|---|---|
| usuário não autenticado, e-mail não confirmado ou perfil inválido | negar leitura e escrita |
| UID diferente do caminho | negar acesso cruzado, inclusive ao owner |
| carteira com campo ausente/extra, owner divergente ou timestamp cliente | negar |
| criar, editar, arquivar e restaurar carteira válida | permitir com revisão e `request.time` |
| excluir carteira, ativo ou operação | negar |
| ativo com carteira ausente/arquivada, ticker inválido ou ID não determinístico | negar |
| compra sem atualização do ativo ou projeção sem operação | negar |
| compra atômica com vínculo, quantidade e topo corretos | permitir |
| venda zero, futura, fora de ordem, acima da posição ou com taxa superior ao valor bruto | negar |
| revisão incorreta, campo imutável ou caminho desconhecido | negar |
| duas operações concorrentes sobre a mesma revisão | permitir somente uma |
| editar operação confirmada ou restaurar operação anulada | negar |
| anular operação isoladamente ou que não seja a mais recente | negar |
| anular o topo e restaurar atomicamente quantidade e elo anterior | permitir |
| duas operações válidas na mesma data civil | permitir, preservando cadeia por ID |
| regressões de perfil, contas, categorias, lançamentos, compromissos e owner | preservar |

O log é auditado contra limite de 1.000 expressões, excesso de leituras de regras, avaliação interrompida, erro de valor nulo e falha interna do Emulator.
