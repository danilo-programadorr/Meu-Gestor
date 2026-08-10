# Regras iniciais do Firestore — development

## Escopo

O arquivo público `firestore.rules` protege o perfil `users/{uid}`, as subcoleções `accounts`, `categories`, `transactions`, `payables`, `receivables`, `investmentPortfolios`, `investmentAssets` e `investmentOperations`, além da leitura administrativa pontual em `system_admins/{uid}`. Caminhos financeiros e administrativos não autorizados continuam negados.

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
- compromissos pendentes não alteram saldo; confirmação e anulação exigem vínculo bidirecional e atualização atômica do lançamento esquema 2;
- carteiras e ativos de acompanhamento pertencem ao próprio UID, usam campos exatos e não admitem exclusão;
- operações de investimento são imutáveis, encadeadas cronologicamente e só podem ser criadas ou anuladas junto da projeção do ativo;
- vendas não excedem a posição nem aceitam taxa superior ao valor bruto; concorrência e repetição preservam uma única ponta válida da cadeia;
- investimentos não criam lançamentos, não referenciam contas e não alteram o saldo real;
- `system_admins` permite somente `get` do documento cujo ID coincide com o UID autenticado e verificado;
- `system_admins` nega `list`, `create`, `update` e `delete` ao cliente;
- `isActiveOwner()` valida papel, estado ativo, development, versão 1 e timestamp sem usar e-mail;
- owner não amplia acesso aos dados financeiros de outros UIDs.

## Validação local e publicação

As regras são exercitadas no Emulator Suite com projeto isolado `demo-*`, incluindo acessos negados, transições atômicas, concorrência, regressões do núcleo financeiro e auditoria do log. A suíte consolidada após INV-1A possui 40 testes. Perfil, núcleo financeiro, compromissos, investimentos e owner foram publicados somente em development mediante autorizações específicas; produção permanece bloqueada.

## Publicação

A publicação é exclusivamente manual pelo proprietário e exige autorização específica. Para o acesso owner, siga `CONFIGURACAO_MANUAL_OWNER_DEV.md`, publique primeiro as regras e somente depois crie manualmente o documento. Não abrir acesso temporário.
