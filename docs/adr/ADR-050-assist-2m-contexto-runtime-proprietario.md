# ADR-050 — ASSIST-2M: contexto runtime delegado ao proprietário

## Contexto

O Assistente precisa compor fatos financeiros confirmados do usuário
autenticado sem conceder à identidade runtime acesso administrativo ao banco
Firestore `(default)`. Firebase Admin e `roles/datastore.user` removeriam a
fronteira que as Security Rules já demonstram por UID.

## Decisão

- A callable só prepara uma autoridade efêmera depois de validar Auth, e-mail,
  App Check e perfil. Ela obtém o cabeçalho `Authorization` do mesmo envelope
  que o perímetro da callable validou; o cliente nunca o envia no payload.
- O leitor runtime usa esse bearer somente em `GET` para coleções fechadas sob
  `users/{uid}` via Firestore REST. A autenticação delegada faz as Security
  Rules continuarem sendo a autoridade da leitura própria.
- A identidade runtime não recebe `datastore.user`, Firebase Admin ou qualquer
  permissão genérica no banco `(default)`.
- Apenas contas, lançamentos, compromissos, calendário financeiro derivado,
  carteiras/ativos/operações e proventos recebidos são convertidos em fatos
  mínimos. UIDs, e-mails, tokens, IDs de documento, textos livres e estrutura
  Firestore não entram no contexto final.
- Um erro HTTP, token ausente, documento de outro UID, campo inválido ou
  paginação acima do limite falha fechada: não há contexto parcial.

## Consequências

Esta etapa é exclusivamente local. A Function continua com provedor desligado
e dependências fail-closed; não houve chamada Firestore, alteração de IAM ou
acesso a dado real. A ativação futura exige revisar se o endpoint REST aceita o
token Firebase no ambiente development e confirmar a equivalência da fronteira
nas Rules publicadas antes de qualquer rollout.
