# Regras iniciais do Firestore — development

## Escopo

O arquivo público `firestore.rules` protege o perfil `users/{uid}`, as subcoleções `accounts`, `categories`, `transactions`, `payables`, `receivables`, `investmentPortfolios`, `investmentAssets`, `investmentOperations`, `investmentIncomeEvents` e a leitura pontual de `entitlements/premium`, além da leitura administrativa em `system_admins/{uid}`. Caminhos financeiros, Premium e administrativos não autorizados continuam negados.

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
- carteiras e ativos de acompanhamento pertencem ao próprio UID e usam campos exatos; somente carteira schema 2 arquivada e marcada como nunca utilizada admite exclusão;
- operações de investimento são imutáveis, encadeadas cronologicamente e só podem ser criadas ou anuladas junto da projeção do ativo;
- vendas não excedem a posição nem aceitam taxa superior ao valor bruto; concorrência e repetição preservam uma única ponta válida da cadeia;
- investimentos não criam lançamentos, não referenciam contas e não alteram o saldo real;
- proventos manuais exigem carteira/ativo próprios e ativos, tipo compatível, valores coerentes, revisão e timestamps do servidor;
- somente previsões editam valores; recebimento, cancelamento e anulação seguem transições fechadas, sem restauração ou exclusão;
- `system_admins` permite somente `get` do documento cujo ID coincide com o UID autenticado e verificado;
- `system_admins` nega `list`, `create`, `update` e `delete` ao cliente;
- `isActiveOwner()` valida papel, estado ativo, development, versão 1 e timestamp sem usar e-mail;
- owner não amplia acesso aos dados financeiros de outros UIDs.
- entitlement Premium permite somente `get` do documento fixo próprio, com autenticação, e-mail confirmado e perfil jurídico atual;
- listagem, escrita, entitlement desconhecido, subcoleções e acesso owner cruzado são negados;
- eventos, vínculos, inbox RTDN, outbox de acknowledgement e grants internos Premium são totalmente inacessíveis ao cliente;
- `_premiumClosedTestTesters/{uid}` e `_premiumClosedTestGrants/{grantId}` são diretório e auditoria internos do teste fechado: negam `get`, `list` e toda escrita ao cliente, inclusive owner; não armazenam e-mail;
- FREE-1 remove entitlement e capability das decisões ativas de investimentos e cotações; Auth, e-mail confirmado, perfil jurídico e UID próprio continuam obrigatórios;
- mutações preservam contratos, referências, revisões e atomicidade; o marcador `hasHistory` só transita de falso para verdadeiro e impede exclusão de histórico;
- ativos schema 2 sem histórico podem ser corrigidos, arquivados/restaurados e excluídos; primeiro uso marca histórico atomicamente, e ativo histórico ou legado nunca é excluído nem troca de tipo;
- owner não possui bypass e a infraestrutura Premium interna continua integralmente inacessível ao cliente.

## Validação local e publicação

As regras são exercitadas no Emulator Suite com projeto isolado `demo-*`, incluindo acessos negados, transições, concorrência, regressões do núcleo financeiro e auditoria do log. O conjunto SUB-1B foi publicado anteriormente somente em development com SHA-256 `F01E52545F2CE88896A48B28B957BF45F8AE79B0173DF2E20449929FF21532B4`. As alterações FREE-1, INV-UX-3 e CRUD-AUDIT-1 permanecem exclusivamente locais: não houve deploy nem acesso Firebase neste checkpoint.

Para manter operações complexas abaixo de 1.000 expressões, leituras validam contratos completos e mutações usam curto-circuito pela transição funcional. O marcador de carteira tem ramo estrito próprio e alterações do ativo são classificadas em metadados, arquivamento, primeiro histórico ou projeção atômica antes das validações completas. Campos exatos, referências, UID, perfil e integridade não foram removidos. A matriz local cobre também excesso de leituras, avaliação interrompida e erros internos.

## Publicação

A publicação é exclusivamente manual pelo proprietário e exige autorização específica. Para o acesso owner, siga `CONFIGURACAO_MANUAL_OWNER_DEV.md`, publique primeiro as regras e somente depois crie manualmente o documento. Não abrir acesso temporário.
