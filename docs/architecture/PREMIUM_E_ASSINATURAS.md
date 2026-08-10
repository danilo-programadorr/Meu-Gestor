# SUB-1A — Domínio Premium e assinaturas

## Fronteira atual

O SUB-1A cria somente tipos de domínio e contratos. Não cobra, não consulta loja, não persiste entitlement, não aplica paywall e não muda o acesso atual aos investimentos em development. Não há produto mensal/anual configurado, período de teste real, backend de verificação ou Security Rule Premium.

O domínio vive em `lib/features/subscriptions/domain/` e não importa Flutter, Firebase, Riverpod, Google Play Billing nem biblioteca de pagamento. Preços e moeda não fazem parte do modelo porque serão fornecidos futuramente pela loja.

## Planos, fontes e ambiente

| Conceito | Valores atuais | Regra |
|---|---|---|
| plano | `free`, `monthly`, `annual` | mensal e anual têm as mesmas capabilities; não existe vitalício |
| fonte | `googlePlay`, `administrativeGrant`, `developmentGrant` | concessões nunca serão escritas pelo aplicativo |
| ambiente | `development`, `production` | grant de development é inválido em production |

Plano gratuito é representado pela ausência explícita de entitlement. Entitlements são Premium e possuem owner, fonte, ambiente, revisão e esquema. Uma concessão administrativa ou de development precisa de validade e será criada futuramente somente por backend auditável. Owner poderá receber concessão para o próprio UID, mas nunca acesso cruzado.

## Entidade e invariantes

`PremiumEntitlement` contém plano, estado, fonte, ambiente, capabilities, início do entitlement, período atual, carência e eventos de cancelamento/expiração/revogação/reembolso, além da última verificação, revisão e versão de esquema.

- todos os instantes são UTC e chegam prontos ao domínio;
- `revision >= 1` e `schemaVersion == 1`;
- períodos são completos, crescentes e obrigatórios fora de `pending`;
- capabilities duplicadas, owner vazio, datas locais e campos de estado incompatíveis são rejeitados;
- `graceUntil` existe somente na carência e estende o período original;
- `cancelled` mantém o fim pago e exige cancelamento programado;
- expiração, revogação e reembolso exigem seus próprios instantes exclusivos;
- recibo, purchase token, cartão, payload Google, preço e credenciais não existem na entidade.

## Máquina de estados

| Estado | Acesso comercial | Observação |
|---|---|---|
| `pending` | negado | aguarda confirmação do servidor |
| `trialing` | integral até o fim exclusivo | teste confirmado |
| `active` | integral até o fim exclusivo | assinatura confirmada |
| `gracePeriod` | integral até `graceUntil` exclusivo | sinaliza carência e releitura |
| `accountHold` | negado | leitura histórica preservada |
| `paused` | negado | leitura histórica preservada |
| `cancelled` | integral até o fim pago exclusivo | cancelamento não expira imediatamente |
| `expired` | negado | leitura histórica preservada |
| `revoked` | negação imediata | terminal, mesmo com período futuro |
| `refunded` | negação imediata | terminal, mesmo com período futuro |

Transições aceitas incluem pendente para teste/ativa, ativa para cancelada/carência/hold/pausada, carência para ativa/hold, cancelada para expirada e renovação com período novo. Revogação é possível a partir de qualquer estado não terminal; reembolso somente em estados aplicáveis. Eventos com revisão antiga ou repetida, verificação regressiva, owner/ambiente divergente, troca de fonte dentro do mesmo ciclo ou período reduzido são negados deterministicamente.

Uma nova assinatura depois de `expired` precisa começar no ou depois do instante de expiração. `revoked` e `refunded` não são restaurados; um novo ciclo deverá ser representado por novo estado autoritativo do backend.

## Capabilities e modo somente leitura

As capabilities iniciais são:

- `investmentsManual`;
- `investmentIncome`;
- `investmentQuotes`;
- `investmentCalculators`;
- `investmentAnalysis`.

A solicitação também informa a intenção `read`, `mutate` ou `consumeService`. Isso evita transformar leitura histórica em permissão de edição. Carteiras, ativos, operações e proventos são dados preserváveis: após perda de acesso, leitura recebe `readOnly`, enquanto criação, edição, operações e proventos são negados. Cotações, calculadoras e análises não são dados históricos preservados; cotações deixam de ser fornecidas para evitar custo recorrente.

Nenhum desses bloqueios está conectado à interface ou aos repositórios de investimentos no SUB-1A. As duas primeiras capabilities correspondem a módulos existentes; as demais apenas reservam significado estável e não habilitam funcionalidade.

## Decisão de acesso

`PremiumEntitlementPolicy` recebe o ambiente esperado e decide usando:

1. entitlement presente ou ausente;
2. capability solicitada;
3. intenção de leitura, mutação ou consumo;
4. instante UTC confiável injetado.

O resultado informa modo, motivo estável, capability, intenção, validade, carência, cancelamento pendente e necessidade de nova verificação. O domínio nunca chama `DateTime.now()`. Uma janela máxima de verificação pode ser injetada pela futura aplicação; o SUB-1A não fixa prazo comercial.

A decisão cliente serve à experiência e falha de maneira explicável. Ela não substitui backend, validação da compra nem Security Rules.

## Contrato e persistência futura

`PremiumEntitlementRepository` oferece somente leitura atual, observação de snapshots confirmados, releitura do servidor e diagnóstico sanitizado. Entitlement ausente é resultado explícito. Não existem métodos cliente para criar, ativar, renovar, revogar, reembolsar ou conceder.

A proposta futura, ainda não criada, é um documento fixo `users/{uid}/entitlements/premium`, escrito exclusivamente por backend. Ele poderá armazenar o estado canônico e campos equivalentes aos do domínio. Token, recibo bruto, identidade de pagamento e auditoria confidencial ficarão em armazenamento exclusivo do backend, nunca em documento legível pelo cliente. A adoção desse caminho exigirá ADR de persistência, mapper, backend, regras, testes de Emulator, custo e autorização própria.

## Preservação e experiência

Perder Premium nunca apaga carteira, ativos, operações ou proventos, nunca recalcula preço médio e nunca modifica conta, saldo ou resumo mensal. A renovação recuperará mutações sem migração dos dados históricos. A interface futura deverá explicar o estado, manter leitura e oferecer ação segura de renovação, sem esconder dados ou simular benefícios indisponíveis.

Google Play Billing será integrado somente em incremento posterior. A integração B3/corretoras permanece cancelada. Cotação atrasada por provedor independente permanece bloqueada por licenciamento e pela implementação segura de SUB-1.
