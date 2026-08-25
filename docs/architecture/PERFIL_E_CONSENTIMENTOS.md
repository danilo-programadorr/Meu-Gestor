# Arquitetura de perfil e consentimentos

## Fluxo seguro

1. `authStateProvider` informa a sessão atual.
2. O portão recarrega o usuário do Firebase Authentication.
3. O token é atualizado forçadamente e precisa conter `email_verified=true`.
4. Somente então `UserProfileRepository` busca `users/{uid}` diretamente do servidor.
5. Perfil inexistente encaminha à configuração inicial.
6. Perfil com versão jurídica antiga encaminha ao novo aceite.
7. Perfil válido libera a área autenticada técnica.
8. Perfil incompatível, cache não confirmado ou falha segura bloqueia o acesso e oferece nova tentativa.

## Camadas

- `presentation`: páginas, estados, controladores Riverpod e portões `go_router`.
- `domain`: `UserProfile`, validação do nome, falhas e contrato do repositório, sem imports Firebase ou Flutter.
- `data`: conversor estrito, transações Firestore, timestamps do servidor e diagnóstico sanitizado.

Widgets não acessam Firestore diretamente. Mapas Firestore ficam restritos à camada de dados.

## Consistência

A criação verifica e grava o documento em transação. Se o perfil já existir, ele é validado e preservado. Depois de cada gravação, uma leitura com origem `server` confirma o resultado; documento de cache ou com escrita pendente não é entregue como perfil confirmado.

O nome interno do aplicativo vem do perfil Firestore. A tentativa posterior de espelhar o nome no Authentication pode falhar sem desfazer o perfil. A interface informa essa condição e permite nova tentativa futura, pois Firestore e Authentication não oferecem transação conjunta.

## Privacidade

O perfil não contém email, telefone, CPF, endereço, foto, provedor, identificador Google, dispositivo, IP ou dados financeiros. Logs development registram somente operação, categoria, código Firestore, etapa e tipo de exceção.

IA e Analytics não são instalados nem ativados. Os booleanos persistidos representam apenas preferências futuras e independentes. No ASSIST-0, `aiConsentEnabled` somente participa do contrato local: o uso futuro exigirá também versão da política, timestamp e leitura confirmada pelo servidor. Memória persistente terá consentimento separado e continua indisponível.

## Offline

A primeira configuração e todas as alterações deste incremento exigem confirmação do servidor. Cache não substitui autorização, não ignora versão jurídica e não esconde gravação pendente. Uma estratégia offline financeira completa permanece fora do escopo.
