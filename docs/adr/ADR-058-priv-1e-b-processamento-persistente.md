# ADR-058 — Processamento persistente de privacidade

- Status: implementado localmente; não publicado
- Data: 18/10/2026

## Contexto

PRIV-1E-A exportava três callables protegidas, mas a composição real usava
`unavailableProcessor`. O núcleo em memória não apagava Firestore, não retomava
falha de processo e o cliente tratava `prepare` como se não houvesse mais ação.

## Decisão

- Preservar as três callables públicas e adicionar um trigger interno sobre
  `users/{uid}/privacyOperations/current` para avançar lotes confirmados.
- Persistir uma operação ativa por UID, lock server-side, cursor e revisão no
  Firestore. Cada lote confirma deletes e avanço do cursor atomicamente.
- Derivar UID exclusivamente de Auth na borda. O worker recebe UID somente do
  caminho Admin criado pelo backend.
- Permitir continuação sem perfil apenas para uma exclusão de conta já
  confirmada e owner-scoped, pois o próprio fluxo apaga o perfil antes de Auth.
  Auth, e-mail e App Check permanecem obrigatórios nas callables.
- Limpar uso pseudonimizado da Luma no banco nomeado na exclusão, preservando
  apenas totais operacionais globais sem owner.
- Manter recibo concluído com campos anônimos e retenção de 30 dias já aceita no
  ADR-027. Nenhuma configuração TTL ou deploy faz parte desta fase.
- Não usar `clearPersistence()`; a limpeza local remove apenas chaves por UID
  depois do recibo confirmado.

## Consequências

Falhas antes de commit não avançam cursor; repetição é segura. Falhas depois de
commit são reconciliadas pelo estado persistido. O Auth é removido somente após
os alvos do manifesto, e `user-not-found` é sucesso idempotente em retry. A
publicação futura ainda exige identidade runtime, acesso mínimo ao banco padrão
e ao banco nomeado, além de autorização explícita de deploy.
