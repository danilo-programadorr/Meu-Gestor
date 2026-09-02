# ADR-044 — ASSIST-2F-0: codebase Functions local do Assistente

## Contexto

ASSIST-2E-0 registrou a callable por injeção, mas não havia um codebase Firebase implantável. Era necessário preparar a embalagem Gen 2 sem conectar dados, provedor ou identidade real.

## Decisão

O codebase isolado `assistant` usa Node 22 e exporta somente `assistRemoteV1`. A única dependência direta é `firebase-functions` 7.3.2. A identidade runtime é um `defineString` obrigatório, sem valor no repositório; sua ausência impede a materialização do deploy. O contrato puro é copiado no predeploy e a borda não importa Firebase Admin, Firestore, Vertex, Secret Manager ou URL externa.

Com kill switch ativo e provedor real desligado, a callable valida Auth, e-mail verificado e App Check e responde `safe_unavailable` antes de acessar quaisquer leitores ou ledger. Assim o artefato não acessa o banco `(default)`, `assistant-controls-dev` ou coleções financeiras.

## Consequências

Não há recurso em nuvem, custo, identidade configurada, endpoint Flutter ou chamada de provedor neste incremento. Deploy development, valor parametrizado da identidade, leitores server-side, controle de custo persistente e ativação do provedor requerem autorizações separadas.
