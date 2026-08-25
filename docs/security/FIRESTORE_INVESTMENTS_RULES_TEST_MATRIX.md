# Matriz local de regras — INV-1A e INV-PROV-1

Escopo: `investmentPortfolios`, `investmentAssets`, `investmentOperations` e `investmentIncomeEvents` sob `users/{uid}`. Execução exclusivamente no Firestore Emulator com Project ID `demo-meu-gestor-financeiro`.

| Caso | Resultado esperado |
|---|---|
| usuário não autenticado, e-mail não confirmado ou perfil inválido | negar leitura e escrita |
| UID diferente do caminho | negar acesso cruzado, inclusive ao owner |
| carteira com campo ausente/extra, owner divergente ou timestamp cliente | negar |
| criar, editar, arquivar e restaurar carteira válida | permitir com revisão, `request.time`, esquema 2 e marcador monotônico |
| excluir carteira esquema 2 ativa | negar; o repositório precisa arquivá-la como trava |
| excluir carteira esquema 2 arquivada, confirmada vazia e `hasHistory=false` | permitir |
| excluir carteira esquema 1, com `hasHistory=true`, ativo, operação ou provento | negar |
| criar primeiro ativo sem elevar `hasHistory` no mesmo batch | negar |
| criar primeiro ativo e elevar `hasHistory` para `true` atomicamente | permitir; reversão posterior é negada |
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
| criar provento total ou por unidade com carteira/ativo ativos e tipo compatível | permitir |
| provento com referência ausente/arquivada, ação/FII incompatível ou valor divergente | negar |
| editar campos financeiros de uma previsão com revisão e mutation novas | permitir |
| confirmar recebimento com data efetiva não futura | permitir |
| cancelar previsão ou anular recebimento preservando valores e datas | permitir |
| editar recebido, restaurar cancelado/anulado ou excluir provento | negar |
| duas transições concorrentes sobre a mesma revisão | permitir somente uma |
| mutação de provento afetar conta, lançamento ou projeção do ativo | não ocorre; documentos permanecem iguais |
| ausência, expiração ou documento inválido de entitlement | não interfere no acesso FREE-1 |
| leitura/mutação própria de investimentos com Auth, e-mail e perfil válidos | permitir sem capability comercial |
| leitura de cotação conhecida pelo próprio usuário financeiro | permitir sem entitlement; listagem e escrita continuam negadas |

O log é auditado contra limite de 1.000 expressões, excesso de leituras de regras, avaliação interrompida, erro de valor nulo e falha interna do Emulator.

Situação do INV-PROV-1: 50 testes aprovados em nove suites; regras compiladas e publicadas com sucesso exclusivamente em development, sem acesso a production, com SHA-256 `8B689BA72FE05B1C04409E00083644D83B2EEACFDDA67A7C8D003B843E102FBE`. O APK debug development foi gerado e aprovado manualmente; commit e push permaneciam pendentes nesta atualização documental.

Situação local FREE-1/INV-UX-3: 71/71 testes em 14 suites aprovados no Emulator `demo-meu-gestor-financeiro`; auditoria do log sem limite de expressões, excesso de leituras, avaliação interrompida, erro nulo ou falha interna. Estas Rules não foram publicadas.
