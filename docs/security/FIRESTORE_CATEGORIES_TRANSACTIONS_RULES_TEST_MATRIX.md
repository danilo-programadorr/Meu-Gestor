# Matriz de regras — categorias e lançamentos

Estado: revisão estrutural local concluída; execução no Emulator Suite pendente.

| Caso | Operação | Resultado esperado |
|---|---|---|
| usuário anônimo | qualquer leitura ou escrita | negar |
| UID diferente | get, list, create ou update | negar |
| email não verificado | qualquer acesso financeiro | negar |
| perfil ausente, incompatível ou jurídico desatualizado | qualquer acesso financeiro | negar |
| categoria própria válida | get, list e create | permitir |
| categoria com campo ausente, extra ou tipo inválido | create/update | negar |
| categoria com `ownerId`, `kind`, `createdAt` ou `schemaVersion` alterado | update | negar |
| arquivar/restaurar categoria com par incoerente | update | negar |
| excluir categoria ou escrever subcoleção | delete/write | negar |
| lançamento próprio válido com conta e categoria ativas | create | permitir |
| lançamento com conta arquivada/inexistente | create | negar |
| lançamento com categoria arquivada/inexistente ou tipo divergente | create/update | negar |
| lançamento com valor zero, negativo, `double` ou acima do limite | create | negar |
| lançamento futuro, descrição/notas inválidas ou campo desconhecido | create/update | negar |
| alterar conta, tipo, valor, proprietário, criação ou esquema | update | negar |
| editar descrição, categoria compatível, data não futura ou notas de lançamento ativo | update | permitir |
| cancelar lançamento ativo com timestamps do servidor | update | permitir |
| restaurar ou editar lançamento cancelado | update | negar |
| excluir lançamento ou escrever subcoleção | delete/write | negar |
| caminho financeiro desconhecido | qualquer acesso | negar |

Nenhum item desta matriz foi declarado aprovado em emulador. A publicação manual não substitui esses testes.
