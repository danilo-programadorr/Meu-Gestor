# Publicação manual das regras de contas — development

Este procedimento é executado exclusivamente pelo proprietário no Firebase Console. Não usa Firebase CLI, não cria projeto, não altera produção e não exige compartilhar credenciais.

## Antes de publicar

1. Confirme visualmente que está autenticado na conta Google correta.
2. Abra o Firebase Console no navegador.
3. Selecione manualmente o projeto de development já aprovado. Não selecione projeto pelo nome por inferência.
4. Confirme que o ambiente exibido não é production.
5. No projeto local, abra `firestore.rules` e confira o SHA-256 informado no relatório do Ponto de Controle 1.
6. Preserve uma cópia recuperável das regras atualmente publicadas no seu ambiente privado. Não envie essa cópia no chat.

## Publicação

1. No Firebase Console, abra **Firestore Database**.
2. Abra a guia **Regras**.
3. Substitua integralmente o editor pelo conteúdo completo do arquivo local `firestore.rules`.
4. Confirme que o bloco de perfil `match /users/{userId}` continua presente.
5. Confirme dentro dele o bloco `match /accounts/{accountId}`.
6. Confirme que `allow delete: if false;` existe para perfil e conta.
7. Confirme que os bloqueios recursivos de subcoleções e caminhos desconhecidos continuam no fim.
8. Use a validação sintática oferecida pelo Console.
9. Se houver qualquer erro, não publique; copie somente a mensagem técnica sem dados pessoais para diagnóstico.
10. Clique em **Publicar** apenas no projeto development.
11. Aguarde a confirmação visual do Console.

## Depois de publicar

1. Não crie coleção ou documento manualmente.
2. Não teste alterando perfil existente pelo Console.
3. Não publique as mesmas regras em production.
4. Responda ao ponto de controle com a mensagem literal `REGRAS DE CONTAS PUBLICADAS`.
5. Somente após essa mensagem serão repetidos pub get, formato, análise e testes e será gerado o APK debug development autorizado para teste manual.

## Reversão

Se a publicação falhar ou causar comportamento inesperado, pare o teste do aplicativo e restaure manualmente no mesmo projeto development a cópia recuperável das regras anteriores. Registre horário, ambiente e mensagem técnica, sem UID, email, nomes, saldos ou conteúdo de documentos.
