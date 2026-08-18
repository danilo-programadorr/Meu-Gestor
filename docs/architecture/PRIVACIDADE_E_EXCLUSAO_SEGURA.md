# Reset financeiro e exclusão segura de conta

## Estado atual

DATA-1A/PRIV-1A e DATA-1B/PRIV-1B existem como contratos Dart e backend ESM local com fakes determinísticos. PRIV-1E-A acrescenta somente o codebase Gen 2 local `backend/functions/privacy`, suas três callables e adaptadores Admin injetáveis. Não houve deploy, acesso Firebase, deleção real, sessão real ou publicação de Rules.

PRIV-1C/PRIV-1D adiciona a tela e a reautenticação local por provedores já suportados. PRIV-1E-A introduz o cliente oficial de Callables e App Check: a reautenticação renova o ID token antes da chamada e a interface consulta o estado devolvido pelo servidor. Como as Functions continuam apenas locais e a persistência Admin paginada não foi ativada, nenhuma confirmação, exclusão, sucesso visual ou limpeza local ocorre antes de um backend publicado e auditado. Rules de locks permanecem somente locais e testadas no Emulator.

## Fronteira futura

Uma borda server-side autenticada derivará o UID, `auth_time`, App Check, e-mail confirmado e perfil jurídico do contexto verificado. O cliente envia apenas a intenção, a frase e uma chave opaca de idempotência; nunca escolhe UID, caminho, lote, cursor, relógio ou tipo de autenticação. Owner não tem desvio de autorização e só pode atuar sobre o próprio UID.

## Functions locais PRIV-1E-A

O codebase `privacy` em Node 22 declara exclusivamente `preparePrivacyOperation`, `confirmPrivacyOperation` e `getPrivacyOperationStatus`. Todas exigem Auth, e-mail verificado, App Check, perfil jurídico atual e UID derivado; as duas mutações também exigem `auth_time` de até cinco minutos pelo relógio do servidor. Os contratos têm campos fechados, comparam a frase somente na memória do processamento e a descartam antes de resposta, log ou recibo.

A identidade runtime é um parâmetro de deploy e não aparece no Git. Os adaptadores injetados encapsulam leitura de perfil Firestore, revogação de refresh tokens, exclusão Auth e relógio. O processador ESM continua sendo a única fonte de transições, lote, cursor e manifesto. A ligação a uma persistência Firestore paginada real, testes Auth/Functions Emulator e qualquer publicação pertencem ao PRIV-1E-B após auditoria externa explícita.

## Fluxo idempotente

```text
prepared → confirmed → locked → deleting → completed                 (reset)
prepared → confirmed → locked → deleting → authDeletionPending → completed  (conta)
                                    ↘ failed recuperável ↗
```

O lock é persistido antes do primeiro lote. Reset bloqueia somente mutações financeiras; exclusão de conta bloqueia todas as mutações vinculadas ao UID. Cada execução faz somente uma etapa ou lote conservador, persiste o cursor `{coleção, último documento}` e pode retomar após timeout sem descobrir ou apagar caminhos fora do manifesto fechado.

Chamadas externas futuras são reivindicadas por lease com expiração no relógio do servidor. Se um worker cair entre a reivindicação e a confirmação, outro worker só a retoma após a lease expirar; a revogação e a exclusão Auth precisam permanecer idempotentes.

Para conta, a ordem é: apagar os alvos do manifesto, revogar refresh tokens, excluir Firebase Authentication de modo idempotente e materializar a conclusão. A confirmação perdida após a exclusão do Auth é reconciliada pelo recibo, sem restauração da conta. Não existe chamada de cancelamento Google Play.

## Dados e retenção

Reset apaga apenas contas, categorias, lançamentos, compromissos, carteiras, ativos, operações e proventos. Exclusão inclui também perfil/consentimentos, entitlement e referências Premium, diretório/grant de teste fechado e `system_admins`.

Após completar, operação e locks deixam de conter UID. Permanece somente recibo anônimo com ID aleatório, tipo, resultado, `completedAt` e `expiresAt` de trinta dias planejados. Não existem dados financeiros, e-mail, UID, valor, token, chave de idempotência ou cópia dos dados apagados. TTL, backups, retenções legais e a página externa exigida pela Google Play são trabalhos futuros sujeitos a auditoria antes de produção.
