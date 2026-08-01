# ADR-014 — Acesso proprietário seguro

- Status: aprovado, regras publicadas e acesso validado manualmente em development
- Data: 01/08/2026

## Contexto

O proprietário precisa acessar todos os módulos implementados e futuros recursos comerciais ou experimentais sem que identidade, assinatura ou segredos sejam compilados no aplicativo. Esse acesso não pode romper isolamento financeiro ou controles técnicos.

## Decisão

- Associar o papel `owner` exclusivamente ao UID da sessão por `system_admins/{uid}`.
- Não usar e-mail, senha, UID hardcoded, armazenamento local ou parâmetro de rota como autorização.
- Permitir ao cliente apenas `get` do próprio documento, com e-mail verificado; negar listagem e toda escrita.
- Exigir documento de cinco campos, leitura do servidor, timeout e validação estrita.
- Centralizar autorização em `AccessContext` e `AppCapability`.
- Conceder ao owner todas as capabilities registradas, inclusive bypass futuro de assinatura, recursos pagos, IA e limites comerciais comuns.
- Manter Security Rules, isolamento por UID, integridade financeira, autenticação, concorrência e limites técnicos de segurança obrigatórios.
- Falhar fechado e manter módulos normais próprios disponíveis em erro administrativo.
- Limitar esta implementação a `development`.
- Revalidar em login, troca de usuário, retorno ao aplicativo e atualização manual.
- Realizar publicação das regras e criação/revogação do documento manualmente pelo proprietário.

## Consequências

Não há cobrança, plano, pagamento, loja ou consumo real de IA nesta etapa. A solução exige uma leitura pontual adicional por sessão ou revalidação. Uma migração futura para custom claims pode reduzir leituras e permitir autorização de backend, mas exigirá processo seguro de concessão, revogação e atualização do token.

## Pendências

- Testes reais das regras no Emulator Suite.
- Avaliação futura de custom claims e backend administrativo seguro.
