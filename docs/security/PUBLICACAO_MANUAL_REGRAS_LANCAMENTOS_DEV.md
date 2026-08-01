# Publicação manual das regras de categorias e lançamentos — development

Somente o proprietário pode realizar estas ações. Não use CLI e não crie documentos manualmente.

1. Abra o Firebase Console no navegador e selecione explicitamente o projeto de development já aprovado.
2. Confirme visualmente o Project ID antes de prosseguir; não selecione production.
3. Abra Firestore Database > Rules.
4. Compare o conteúdo atual do editor com o arquivo local `firestore.rules`.
5. Substitua integralmente o editor pelo conteúdo completo do arquivo local. Não copie apenas os blocos novos.
6. Revise se permanecem presentes as regras de perfil e contas, além dos blocos `categories` e `transactions`.
7. Confirme que o rodapé continua negando caminhos desconhecidos e que nenhuma regra usa `allow read, write: if true`.
8. Use a validação sintática oferecida pelo Console.
9. Publique somente se o Console não apontar erro e o projeto confirmado for development.
10. Não crie coleções ou documentos para testar neste ponto.
11. Retorne ao projeto e informe literalmente `REGRAS DE LANÇAMENTOS PUBLICADAS`.

Se o Console indicar erro, não flexibilize a regra. Registre apenas a mensagem técnica sem tokens, IDs sensíveis ou conteúdo de configuração e interrompa a publicação.
