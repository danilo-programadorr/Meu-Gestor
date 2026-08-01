# ADR-011 — Perfil, segurança inicial e consentimentos

- Status: aceito
- Data: 31/07/2026

## Contexto

O aplicativo precisa persistir um perfil mínimo depois da confirmação do email, sem liberar áreas autenticadas antes da validação pelo servidor e sem ativar serviços opcionais. As regras do Firestore precisam proteger esse primeiro documento antes da introdução de dados financeiros.

## Decisão

- O perfil fica exclusivamente em `users/{uid}` e contém somente os 17 campos autorizados.
- Firebase Authentication é a fonte da identidade; Firestore é a fonte do nome exibido dentro do aplicativo depois da criação do perfil.
- O usuário precisa estar autenticado, com `emailVerified=true` no usuário recarregado e `email_verified=true` no token forçadamente atualizado antes do primeiro acesso ao Firestore.
- Um perfil válido é obrigatório antes da área autenticada.
- As regras negam por padrão, proíbem listagem, exclusão, subcoleções e caminhos desconhecidos e permitem somente o próprio documento.
- Termos e Política são obrigatórios e versionados como `terms-dev-1.0.0` e `privacy-dev-1.0.0`.
- IA e Analytics têm consentimentos opcionais, separados e inicialmente desativados.
- `analyticsConsentUpdatedAt` registra a alteração de Analytics simetricamente a `aiConsentUpdatedAt`.
- A criação usa transação e não sobrescreve perfil existente. Gravações usam timestamps do servidor e são confirmadas por leitura do servidor.
- A alteração de nome grava primeiro o Firestore e depois tenta espelhar no Authentication. Não há transação atômica entre esses serviços e falhas parciais são informadas.
- A exclusão do perfil não é disponibilizada nesta etapa.
- As regras serão publicadas manualmente pelo proprietário no Firebase Console.

## Consequências

- Cache não serve como prova de autorização nem de aceite jurídico atual.
- A primeira configuração exige conexão com o servidor.
- IA e Analytics permanecem inativos mesmo quando a preferência futura é marcada.
- Não existem testes reais das regras neste incremento porque Firebase CLI e Emulator Suite não estão autorizados. A matriz documenta os casos pendentes para execução futura.
- A área autenticada permanece bloqueada até a publicação manual das regras development e a validação final autorizada.
