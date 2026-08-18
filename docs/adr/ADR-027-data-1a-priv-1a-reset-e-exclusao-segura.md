# ADR-027 — DATA-1A/PRIV-1A: contratos de reset financeiro e exclusão segura

**Status:** domínio, backend ESM, experiência Flutter, Rules locais e borda Gen 2 local implementados e testados; sem Function publicada, persistência Admin ativada, publicação de Rule, exclusão real, limpeza de cache real, deploy, commit ou push.

## Contexto

O aplicativo ainda nega exclusão do cliente pelas Security Rules. O reset financeiro e a exclusão de conta precisam ser idempotentes, isolados por UID e executados pelo servidor, sem usar relógio do aparelho, sem depender de uma operação atômica global e sem expor dados apagados em diagnósticos ou comprovantes.

## Decisão

- `financialReset` preservará Firebase Authentication, perfil, consentimentos, preferência visual, entitlement/assinatura Premium e acesso owner. Removerá somente contas, categorias, lançamentos, compromissos a pagar/receber, carteiras, ativos, operações e proventos; o cache financeiro local será limpo apenas após confirmação futura do servidor.
- `accountDeletion` removerá os mesmos dados, perfil/consentimentos, entitlement e referências Premium, diretório/grant de teste fechado e `system_admins/{uid}`. A exclusão do Firebase Authentication ocorrerá por último, após bloqueio de novas escritas e processamento transacional com cursor persistido.
- O manifesto de coleções é fechado no domínio. A implementação futura não poderá inventar caminhos, aceitar UID de terceiro, excluir diretamente pelas Rules nem restaurar operação concluída.
- A autorização futura exige frase exata, autenticação, App Check, e-mail confirmado, perfil jurídico válido, UID da própria sessão e `auth_time` validado pelo servidor com no máximo cinco minutos. Frase e UI são confirmação de intenção, não substitutos da reautenticação.
- A máquina de estados é `prepared → confirmed → writeLocked → deletingFinancialData → completed` para reset; e `prepared → confirmed → writeLocked → deletingFinancialData → deletingIdentityData → authenticationDeletionPending → completed` para conta. Falhas recuperáveis guardam somente o estado de retomada/cursor; conclusão é terminal.
- Ao final, permanece somente recibo anônimo com ID aleatório, tipo, resultado e `completedAt`, planejado para retenção de 30 dias. Não contém UID, e-mail, chave de idempotência, dados financeiros ou cópia de dados apagados. Não há retenção antifraude enquanto não existir cobrança real. Backups exigem auditoria e decisão antes de produção.
- A exclusão não cancela assinatura Google Play. A futura interface deverá mostrar esse aviso e o acesso oficial ao gerenciamento da Play; dados e acesso local serão encerrados sem tentar manipular uma compra externa.

## Consequências

O backend ESM local em `backend/privacy` agora usa storage, relógio, revogação de sessão, exclusão Auth e emissor de recibo abstratos, todos com fakes determinísticos. Ele persiste uma única operação ativa por UID, aplica o manifesto fechado em lotes conservadores, reconcilia timeout após commit e não mantém UID depois de completar. O recibo e a auditoria local são sanitizados.

PRIV-1C/PRIV-1D acrescenta a rota Perfil > Dados e privacidade, consequência explícita para reset/exclusão, frase exata, reautenticação por senha ou Google e renovação forçada do token. PRIV-1E-A acrescenta o repositório oficial de Callables, configuração App Check sem token versionado e o codebase local Node 22 `privacy` com somente `preparePrivacyOperation`, `confirmPrivacyOperation` e `getPrivacyOperationStatus`. As callables derivam identidade, e-mail, App Check e `auth_time`; elas não aceitam UID, data, cursor ou estado do cliente e não persistem/logam a frase. Sem deploy e sem storage Firestore paginado conectado, qualquer processamento permanece falha-fechada e o cliente não mostra sucesso nem limpa estado. Rules locais negam integralmente operações, locks e recibos privados; lock financeiro bloqueia mutações financeiras e lock de conta bloqueia também atualização de perfil, sem bypass owner.

O próximo incremento deverá ligar o núcleo à persistência Firestore paginada e às adaptações Admin reais, aplicar Rules/lock no servidor, validar Auth/App Check Emulator, realizar revogação de sessão e exclusão final do Auth sob autorização e testar offline/concorrência no Emulator. A página externa de solicitação de exclusão exigida pela Google Play terá de chamar o mesmo fluxo autenticado e não poderá aceitar uma exclusão automática por e-mail. Nenhuma destas ações externas foi iniciada neste ADR.
