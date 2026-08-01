# Regras iniciais do Firestore — development

## Escopo

O arquivo público `firestore.rules` protege o perfil `users/{uid}`, as subcoleções `accounts`, `categories` e `transactions` e a leitura administrativa pontual em `system_admins/{uid}`. Caminhos financeiros e administrativos não autorizados continuam negados.

## Garantias pretendidas

- negação por padrão;
- ausência de acesso anônimo;
- exigência de proprietário e email verificado no token;
- leitura somente por caminho exato do próprio perfil;
- listagem de `users` negada;
- criação com exatamente 17 campos, tipos e valores fixos validados;
- timestamps técnicos e de consentimento iguais a `request.time`;
- atualização limitada a nome, snapshot de verificação, versões jurídicas, consentimentos e `updatedAt`;
- vínculo obrigatório entre cada valor alterado e seu timestamp correspondente;
- `ownerId`, `createdAt`, locale, moeda, fuso e versão do esquema imutáveis;
- exclusão do perfil, subcoleções não autorizadas e caminhos desconhecidos negados;
- contas limitadas ao próprio UID verificado, com 11 campos exatos, BRL, centavos inteiros, tipos permitidos e timestamps do servidor;
- atualização de conta limitada a nome, tipo, saldo inicial, inclusão no total e transição pareada de arquivamento;
- exclusão e subcoleções internas de conta negadas.
- categorias com campos exatos, enumerações fechadas, tipo imutável e arquivamento pareado;
- lançamentos com campos exatos, centavos inteiros positivos, data não futura e referências próprias ativas;
- edição de lançamento limitada a descrição, categoria compatível, data e notas;
- cancelamento irreversível sem exclusão e sem participação no saldo.
- `system_admins` permite somente `get` do documento cujo ID coincide com o UID autenticado e verificado;
- `system_admins` nega `list`, `create`, `update` e `delete` ao cliente;
- `isActiveOwner()` valida papel, estado ativo, development, versão 1 e timestamp sem usar e-mail;
- owner não amplia acesso aos dados financeiros de outros UIDs.

## Limitação de validação

As regras presentes neste arquivo foram publicadas manualmente no ambiente development e os fluxos do aplicativo foram validados no Android. Elas ainda não foram executadas no Emulator Suite. Busca textual, revisão estrutural e teste do aplicativo não substituem testes diretos das regras; as matrizes permanecem pendentes de execução futura no emulador.

## Publicação

A publicação é exclusivamente manual pelo proprietário. Para o acesso owner, siga `CONFIGURACAO_MANUAL_OWNER_DEV.md`, publique primeiro as regras e somente depois crie manualmente o documento. Não abrir acesso temporário.
