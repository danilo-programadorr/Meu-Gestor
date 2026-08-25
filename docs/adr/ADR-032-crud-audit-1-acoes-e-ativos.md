# ADR-032 — CRUD-AUDIT-1: ações coerentes e ciclo de vida dos ativos

- Status: aceito localmente
- Data: 24/08/2026

## Contexto

As entidades financeiras não admitem um CRUD genérico: apagar uma conta, lançamento, operação ou ativo histórico quebraria saldos derivados, vínculos e auditoria. Ao mesmo tempo, um ativo cadastrado por engano e nunca utilizado precisa de correção e exclusão compreensíveis. A interface também usava ícones equivalentes com implementações locais repetidas.

## Decisão

1. A matriz `CRUD_ACTION_MATRIX.md` passa a registrar todas as ações existentes e as ausências intencionais.
2. Ícones isolados de editar, excluir, arquivar e restaurar usam um componente canônico com tooltip e semântica específicos.
3. Ativos novos usam schema 2 com `hasHistory=false`, `isArchived=false` e `archivedAt=null`.
4. A primeira operação ou o primeiro provento eleva `hasHistory` atomicamente e o marcador nunca regride.
5. Ativo schema 2 sem histórico pode ter nome e tipo corrigidos e pode ser excluído após trava por arquivamento e revalidação server-only de operações e proventos.
6. Ativo histórico ou legado nunca pode ser excluído. Seu nome pode ser corrigido, seu tipo torna-se imutável e ele pode ser arquivado/restaurado.
7. O ticker continua imutável porque compõe o identificador do documento. Corrigi-lo exige cadastrar o ticker certo; o registro errado só pode ser apagado se nunca usado.
8. Arquivar bloqueia novas operações e proventos, preservando toda leitura histórica. Owner não recebe bypass.

## Compatibilidade e segurança

Documentos schema 1 são interpretados conservadoramente como históricos, sem migração em massa. As Rules locais exigem campos exatos, UID próprio, perfil jurídico, ausência de lock de privacidade, revisão monotônica e as mesmas transições. Delete direto de qualquer ativo histórico, operação ou provento permanece negado.

## Consequências

- Cadastros incorretos podem ser resolvidos sem deixar lixo quando nunca utilizados.
- Histórico financeiro continua imutável e explicável.
- A exclusão exige consultas server-only e uma transação final; timeout é reconciliado por releitura.
- As alterações de Rules permanecem locais até autorização específica de publicação.
