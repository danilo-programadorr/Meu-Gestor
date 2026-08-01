# Configuração manual do owner em development

Esta configuração deve ser realizada pelo proprietário no Firebase Console. Não compartilhe UID, senha, token, chave privada ou arquivo de conta de serviço no chat.

Status do ambiente development: regras publicadas, documento criado manualmente e fluxo owner validado. As instruções abaixo permanecem como procedimento reproduzível para configuração ou recuperação do ambiente.

## 1. Confirmar o projeto

1. Abra o Firebase Console no navegador.
2. Selecione manualmente o projeto Firebase de `development` já utilizado pelo aplicativo.
3. Não selecione nem altere projeto de produção.

## 2. Publicar primeiro as regras

1. No projeto local, abra `firestore.rules`.
2. No Firebase Console, acesse **Firestore Database** → **Rules**.
3. Substitua o editor pelo conteúdo completo do arquivo local.
4. Revise se existe `match /system_admins/{adminUid}` com somente `get` do próprio UID verificado e escrita/listagem negadas.
5. Clique em **Publish**.
6. Não use Firebase CLI e não altere outras configurações do projeto.

## 3. Localizar o UID correto

1. No Firebase Console, acesse **Authentication** → **Users**.
2. Localize visualmente a conta Google real do proprietário pelo e-mail mostrado no Console.
3. Confirme que o provedor e a conta correspondem ao login usado no aplicativo.
4. Copie o valor da coluna **User UID** localmente.
5. Não envie esse UID no chat e não o grave em documentação ou código.

## 4. Criar o documento administrativo

1. Acesse **Firestore Database** → **Data**.
2. Crie a coleção raiz `system_admins`, caso ainda não exista.
3. Crie um documento usando exatamente o UID copiado como **Document ID**.
4. Adicione somente os cinco campos abaixo:

| Campo | Tipo no Console | Valor |
|---|---|---|
| `role` | string | `owner` |
| `active` | boolean | `true` |
| `environment` | string | `development` |
| `grantedAt` | timestamp | data e hora atuais |
| `schemaVersion` | number | `1` |

5. Salve o documento.
6. Não adicione e-mail, nome, telefone, provedor, observação, token, IP, dispositivo, client ID ou UID duplicado.

## 5. Revogação manual

O acesso pode ser revogado alterando `active` para `false` ou excluindo manualmente o documento. O aplicativo revalida após novo login, troca de usuário, retorno do background e uso de “Atualizar acesso”.

## 6. Confirmação segura

Depois de publicar as regras e criar o documento, confirme apenas a conclusão da operação. Não envie valores de campos, UID, e-mail, capturas do Console ou credenciais.
