# ADR-026 — SUB-1F-1: ativação segura de Premium no teste fechado

**Status:** backend e integração Flutter implementados localmente; callable e Rules não publicadas, sem lista, concessão ou entitlement real.

## Contexto

O requisito de participação contínua do teste fechado é atendido por uma concessão individual de quinze dias, contada por relógio confiável do servidor no momento da primeira ativação autenticada. Esta decisão substitui a janela global prevista no ADR-024, sem alterar a oferta comercial futura de três dias do plano mensal.

## Decisão

- O diretório privado `_premiumClosedTestTesters/{uid}` contém somente metadados mínimos de autorização: ambiente `development`, track `closed`, estado, instante de autorização, revisão e esquema. Não armazena e-mail e é integralmente negado ao cliente pelas Rules.
- A autorização e revogação da lista são serviços administrativos server-side sem callable público. A ativação é uma callable distinta que aceita payload vazio, deriva o próprio UID do token autenticado e exige e-mail verificado, App Check e perfil jurídico atual.
- `closedTestGrant` inicia no relógio do servidor e dura exatamente quinze dias por usuário. Gera identificador opaco, capabilities Premium completas, revisão e auditoria sanitizada; o aplicativo não informa UID alvo, prazo, capability, track ou identificador de grant.
- A composição de Functions só ativa esse caminho quando o ambiente runtime explícito resolve para `development`; ausência, divergência ou `production` são negados antes de persistir qualquer dado.
- A transação preserva idempotência e concorrência. Após expiração, a mesma identidade retorna o estado expirado, sem restaurar capabilities ou apagar dados. Uma concessão não substitui entitlement existente de outra origem.
- A fonte permanece inválida em production. Não representa compra, assinatura, preço, cobrança, oferta Play de quinze dias ou o teste comercial `teste-3d`.
- ACCESS-INV-DEV-1 integra o cliente somente em `development`: após ausência confirmada do entitlement no servidor, uma tentativa por UID/processo chama a callable com payload vazio. A resposta não concede acesso; uma segunda leitura server-only do entitlement é obrigatória e respostas tardias são descartadas.

## Consequências

- A próxima publicação autorizada deverá incluir a nova callable e as Rules locais, criar o diretório privado por procedimento administrativo aprovado e observar App Check antes de conceder qualquer acesso.
- Não há e-mail, UID, token, App ID, credencial ou lista de testadores no repositório. Fixtures usam somente identificadores sintéticos.
- Production não referencia a ativação automática. Usuário não autorizado, App Check inválido, timeout, múltiplos toques e confirmação ainda ausente permanecem bloqueados sem criar bypass de depuração.
