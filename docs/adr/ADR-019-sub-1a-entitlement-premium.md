# ADR-019 — SUB-1A domínio e contrato de entitlement Premium

## Status

Aceita em 10/08/2026. O SUB-1A implementa somente domínio puro, contrato de repositório, testes e documentação. Não há cobrança, paywall, produto configurado, persistência, backend de verificação ou integração com Google Play Billing.

## Contexto

O acesso Premium precisa suportar assinatura mensal e anual, teste, renovação, cancelamento ao fim do período, carência, suspensão, expiração, reembolso, revogação e concessões controladas. Uma decisão binária `isPremium` não representa cancelamento pendente, somente leitura após expiração nem a necessidade de confirmação do servidor. Eventos futuros da loja também poderão chegar repetidos ou fora de ordem.

O domínio não pode confiar no relógio do aparelho, em recibos locais ou em identidade owner para autorizar dados de outro UID. A perda do acesso comercial nunca pode apagar ou reescrever o histórico financeiro e patrimonial.

## Decisão

- usar estados canônicos internos `pending`, `trialing`, `active`, `gracePeriod`, `accountHold`, `paused`, `cancelled`, `expired`, `revoked` e `refunded`, sem copiar payload de provedor;
- representar os planos gratuito, Premium mensal e Premium anual sem preço ou moeda; a ausência de entitlement corresponde ao plano gratuito;
- limitar as fontes a `googlePlay`, `administrativeGrant` e `developmentGrant`; concessões serão futuramente criadas somente pelo backend, terão validade, revisão, ambiente e auditoria;
- modelar capabilities tipadas para investimentos manuais, proventos, cotações, calculadoras e análises, mantendo mensal e anual com o mesmo conjunto inicial;
- decidir acesso com entitlement opcional, capability, intenção e instante UTC confiável injetado, produzindo `full`, `readOnly` ou `denied` com motivo estável, validade e sinalização de releitura;
- considerar o limite temporal exclusivo: no instante exatamente igual ao fim do período ou da carência, o acesso integral já terminou;
- fazer revogação e reembolso prevalecerem imediatamente sobre qualquer período futuro;
- preservar leitura de carteira, ativos, operações e proventos após perda de acesso, bloqueando mutações; cotações e outros serviços recorrentes não recebem esse modo;
- validar transições por revisão crescente, instante de verificação não regressivo, ambiente, owner, tabela fechada e período não regressivo;
- tratar `revoked` e `refunded` como terminais. Uma nova compra após `expired` inicia período posterior e não restaura o entitlement antigo;
- expor no cliente apenas leitura, observação confirmada, releitura de servidor e diagnóstico sanitizado. Ativar, renovar, revogar, reembolsar e conceder não pertencem ao contrato cliente;
- manter tokens de compra, recibos completos, payloads, credenciais e identificadores externos de autorização fora da entidade e do diagnóstico.

## Consequências

O cliente futuro poderá explicar ao usuário se há acesso integral, somente leitura, carência, cancelamento pendente ou necessidade de atualização, sem usar o relógio dentro da entidade. A decisão local será apenas projeção de experiência; backend e Security Rules continuarão como autoridade definitiva.

O SUB-1A não altera investimentos, owner, repositórios atuais nem `firestore.rules`. Investimentos seguem acessíveis no ambiente development atual e não existe paywall ativo. A futura persistência proposta exige incremento separado, backend verificador, contrato fechado e regras sem escrita cliente.

Google Play Billing direto, produtos, compra, restauração, Play Developer API, RTDN, Pub/Sub, Functions/Cloud Run, Secret Manager, concessão owner e bloqueios de interface permanecem fora do SUB-1A. A integração B3 e integrações automáticas com corretoras permanecem canceladas; nenhuma pesquisa ou preparação arquitetural está autorizada. Cotações atrasadas por provedor independente continuam bloqueadas por licenciamento e pela conclusão dos incrementos de assinatura.
