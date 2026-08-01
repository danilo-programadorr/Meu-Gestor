# Matriz de testes das regras Firestore — contas

Status: revisão local concluída; execução real no Emulator Suite pendente. Esta matriz e inspeção textual não são prova de segurança. Firebase CLI e emulador não foram executados.

| Caso | Resultado esperado | Cobertura da regra | Estado no emulador |
|---|---|---|---|
| Anônimo lê contas | negar | isVerifiedOwner | pendente |
| Anônimo cria conta | negar | isVerifiedOwner | pendente |
| Usuário não verificado lê | negar | token email_verified | pendente |
| Usuário não verificado cria | negar | token email_verified | pendente |
| Usuário lê suas contas | permitir | UID do caminho | pendente |
| Usuário lê conta de outro UID | negar | UID do caminho | pendente |
| Usuário cria sob outro UID | negar | UID do caminho e ownerId | pendente |
| Usuário sem perfil atual lê ou grava | negar | hasCurrentLegalProfile | pendente |
| Listagem da própria subcoleção | permitir | allow list próprio | pendente |
| Consulta collectionGroup | não utilizada e negar por padrão | ausência de regra global | pendente |
| Criação válida | permitir | isValidAccountCreate | pendente |
| ownerId incorreto | negar | ownerId igual ao userId | pendente |
| Campo adicional | negar | keys hasOnly | pendente |
| Campo ausente | negar | keys hasAll | pendente |
| Tipo de campo incorreto | negar | hasValidAccountTypes | pendente |
| Nome vazio, curto, longo, com controle ou espaços repetidos | negar | isValidAccountName | pendente |
| Tipo desconhecido ou cartão | negar | isValidAccountType | pendente |
| Saldo decimal | negar | openingBalanceCents is int | pendente |
| Saldo em string | negar | openingBalanceCents is int | pendente |
| Saldo abaixo ou acima do limite | negar | limites inteiros | pendente |
| Moeda diferente de BRL | negar | currencyCode fixo | pendente |
| Criação já arquivada | negar | isArchived false | pendente |
| archivedAt preenchido na criação | negar | archivedAt null | pendente |
| createdAt ou updatedAt do cliente | negar | igualdade com request.time | pendente |
| Atualização válida de nome | permitir | affectedKeys e nome válido | pendente |
| Atualização válida de tipo | permitir | affectedKeys e enum | pendente |
| Atualização válida do saldo inicial | permitir nesta etapa | affectedKeys e limites | pendente |
| Atualização válida de includeInTotal | permitir | affectedKeys e bool | pendente |
| Alteração de ownerId | negar | imutabilidade | pendente |
| Alteração de createdAt | negar | imutabilidade | pendente |
| Alteração de currencyCode | negar | imutabilidade e BRL | pendente |
| Alteração arbitrária de schemaVersion | negar | imutabilidade e versão 1 | pendente |
| Arquivamento válido | permitir | false para true e request.time | pendente |
| Arquivamento sem archivedAt | negar | transição pareada | pendente |
| archivedAt muda sem estado | negar | transição pareada | pendente |
| Restauração válida | permitir | true para false e null | pendente |
| Restauração mantendo archivedAt | negar | transição pareada | pendente |
| Exclusão | negar | allow delete false | pendente |
| Subcoleção dentro da conta | negar | match recursivo interno | pendente |
| Caminho desconhecido | negar | match recursivo final | pendente |

## Pré-condição para execução futura

A execução desta matriz requer autorização específica para Firebase CLI e Emulator Suite. Até lá, nenhum caso deve ser marcado como testado ou aprovado no emulador. A publicação manual em development também não substitui os testes negativos automatizados.
