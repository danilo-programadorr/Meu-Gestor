# ADR-043 — ASSIST-2E-0: registro Gen 2 local da callable do Assistente

## Contexto

ASSIST-2D-0 criou a factory fail-closed para o contrato `assist-remote-v1`. É necessário estabilizar o nome e as opções Gen 2 sem registrar uma Function em nuvem ou abrir uma rota do Flutter.

## Decisão

`registerAssistRemoteV1Gen2` compõe a factory por injeção e expõe somente o nome `assistRemoteV1`. As opções são imutáveis: `southamerica-east1`, 256 MiB, 30 segundos, concorrência 1, mínimo 0, máximo 1 e `enforceAppCheck: true`.

O registro não configura projeto, identidade runtime, URL, Secret Manager, banco ou provedor. Auth, App Check, e-mail, perfil, consentimento e privacidade continuam no contrato da factory. O cliente permanece sem endpoint; quando a composição for usada no futuro, receberá somente a mensagem sanitizada. Kill switch ativo e flag de provedor falsa preservam `safe_unavailable`.

## Consequências

Não há import de SDK Vertex, URL externa, chave, Function implantada ou custo. Uma futura composição com `firebase-functions/v2/https`, leitores Admin, runtime identity, ledger transacional e deploy requerá autorização externa separada.
