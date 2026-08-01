# Publicação manual das regras Firestore development

Execute somente após revisar o arquivo `firestore.rules` local e confirmar que o projeto selecionado é explicitamente o ambiente **development** correto.

1. Acesse o Firebase Console pelo navegador.
2. Selecione explicitamente o projeto Firebase development correto. Não use um projeto apenas porque o nome parece semelhante.
3. Abra **Firestore Database**.
4. Abra a aba **Regras**.
5. Compare o conteúdo atual do Console com o arquivo local `firestore.rules`.
6. Substitua somente o conteúdo das regras pelo conteúdo completo e conferido do arquivo local.
7. Revise novamente se a regra começa com `rules_version = '2';`, exige email verificado e termina negando caminhos desconhecidos.
8. Clique em **Publicar**.
9. Não altere índices.
10. Não crie coleções ou documentos manualmente.
11. Não abra acesso temporário e não use regras permissivas.
12. Retorne ao projeto e confirme apenas com a mensagem: `REGRAS FIRESTORE PUBLICADAS`.

Não envie credenciais, tokens, configuração de cliente ou capturas contendo identificadores sensíveis.
