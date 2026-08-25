# ADR-031 — FREE-1 e INV-UX-3: investimentos gratuitos e exclusão segura

## Status

Aceita para implementação local em 24/08/2026. Nenhuma publicação de Rules, deploy, commit, push ou geração de APK integra esta decisão.

## Contexto

O produto deixa de cobrar pelo acompanhamento manual de investimentos, proventos, calculadoras e análises. A infraestrutura de assinatura e teste fechado já construída precisa permanecer reversível e auditável, mas não pode participar do fluxo ativo do aplicativo nem provocar chamadas em runtime.

Carteiras também precisavam de uma exclusão permanente segura. Security Rules não conseguem consultar coleções para provar que uma carteira está vazia; autorizar o delete apenas com uma consulta do cliente criaria uma condição de corrida e permitiria órfãos.

## Decisão

1. Investimentos, proventos, calculadoras e análises ficam disponíveis a qualquer usuário que já satisfaça autenticação, e-mail confirmado, perfil jurídico e isolamento por UID.
2. Rotas, menus, controllers, providers e repositório ativos não consultam entitlement, compra, cobrança ou concessão de teste. A tela comercial e seus gates deixam de ser alcançáveis pelo aplicativo.
3. O código de monetização permanece isolado e inativo como histórico reversível. Ele não é inicializado nem chamado pelo runtime ativo. Uma eventual retomada comercial exigirá nova decisão, integração explícita e validação completa.
4. A carteira passa ao esquema 2 com `hasHistory`, inicialmente `false`. A criação do primeiro ativo eleva esse marcador para `true` na mesma transação. A transição é monotônica e nunca pode voltar a `false`.
5. Somente carteira do esquema 2, `hasHistory=false`, confirmada vazia no servidor e arquivada como trava pode ser excluída. Carteiras do esquema 1 são lidas normalmente, mas são conservadoramente não excluíveis. Carteiras com qualquer histórico continuam arquiváveis.
6. A interface posiciona a lixeira ao lado da edição, explica o limite, exige a frase exata `EXCLUIR`, bloqueia repetição e só anuncia sucesso após confirmação do repositório.
7. Todo resultado rápido das calculadoras é exibido em modal não descartável por toque externo, rolável, com título, entradas, fórmula/premissas, resultado, aviso financeiro e fechamento explícito por `X`.

## Consequências

- O núcleo financeiro e a integridade dos investimentos permanecem independentes de monetização.
- Documentos antigos não exigem migração em massa e não ganham uma permissão de exclusão arriscada.
- Uma carteira que já recebeu um ativo não pode ser apagada mesmo que todo o histórico seja posteriormente anulado; o arquivamento preserva a trilha.
- As Rules FREE-1 são apenas locais neste checkpoint. Até publicação especificamente autorizada, o backend remoto conserva o comportamento já publicado.
- Nenhum preço, assinatura, teste, entitlement ou dado fictício é apresentado no aplicativo ativo.
