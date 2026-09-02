# ADR-042 — ASSIST-2D-0: callable remota segura local

## Contexto

O contrato ASSIST-2B-0 e o ledger ASSIST-2C precisam de uma borda preparada para Cloud Functions Gen 2 sem permitir ativação acidental do provedor ou exposição de contexto financeiro.

## Decisão

`createAssistRemoteV1Callables` é uma factory local injetável compatível com `onCall` Gen 2. A callable futura é nomeada `assistRemoteV1` e aceita exclusivamente `{ contractVersion: 'assist-remote-v1', message }`. UID, e-mail, App Check, consentimento, perfil, contexto, modelo, custo, instruções e identidade são derivados ou validados no servidor; qualquer campo adicional é recusado.

A factory exige Auth, e-mail verificado, App Check, perfil jurídico e consentimento IA confirmado. Privacidade financeira ativa impede até a leitura do contexto. Flash é a decisão lógica padrão e Pro depende somente do roteador interno. A porta do ledger exige `reserve` e `confirm`, mas não é chamada enquanto o provedor estiver desligado.

O kill switch é obrigatoriamente `true` e a flag de provedor obrigatoriamente `false`. Mesmo após autorização e roteamento válidos, a resposta é sempre o objeto determinístico `safe_unavailable`, sem modelo, contexto, custo ou conteúdo do usuário.

## Consequências

Não há codebase registrado, export de Function implantável, Firebase Admin, Firestore, Secret Manager, IAM, Vertex, endpoint Flutter ou chamada externa neste incremento. Uma ativação futura exigirá decisão separada para composição com fontes server-side, identidade runtime, ledger transacional, segredo/provedor, App Check e deploy controlado.
