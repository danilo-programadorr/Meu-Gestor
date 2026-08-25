# ADR-033 — ASSIST-0: contrato seguro do Assistente Financeiro Pessoal

- Status: aceito localmente
- Data: 24/08/2026

## Contexto

Uma assistência útil precisa interpretar dados próprios sem transformar um modelo generativo em fonte de verdade financeira, autorização ou executor de operações. O aplicativo já possui consentimento opcional de IA, mas ainda não possui serviço de IA, memória, endpoint, segredo ou interface do assistente.

## Decisão

1. O cliente envia somente a pergunta. Auth, UID, App Check, perfil, consentimento e contexto são derivados e confirmados server-side.
2. O contexto usa fatos tipados, dinheiro em centavos, aliases efêmeros de evidência e lacunas explícitas. UID, e-mail, nome pessoal, IDs persistidos, tokens e configuração técnica não chegam ao provedor.
3. O consentimento de IA deve estar ativo, na versão `assist-context-v1`, confirmado pelo servidor e sem escrita pendente. Owner não ignora consentimento nem isolamento por UID.
4. ASSIST-0 usa memória `none`. Memória persistente futura exige consentimento separado, resumo estruturado, retenção máxima de 90 dias e exclusão na revogação ou exclusão da conta. Reset financeiro invalida memória financeira.
5. O modelo pode explicar, comparar, perguntar e sugerir. Mutações são apenas propostas com prévia; exigirão confirmação explícita, recente e vinculada ao conteúdo, seguida de revalidação pelas regras normais do domínio. O assistente não recebe um gateway de escrita.
6. Reset, exclusão de conta, autenticação, entitlement, owner, segurança, segredos e administração nunca podem ser executados pelo assistente.
7. Toda observação da resposta deve apontar para evidência existente. Dados ausentes permanecem ausentes; dívida, orçamento, metas, reserva, projeção e série histórica não são simulados.
8. O contrato server-side é neutro de provedor. ASSIST-0 não escolhe nem conecta API de IA.

## Consequências

- A experiência pode futuramente oferecer análise ampla e explicável sem entregar autoridade financeira ao modelo.
- Uma Function, provedor, orçamento, rate limit, avaliação de qualidade e publicação de Rules ainda exigem incrementos e autorizações próprios.
- Perguntas com provável segredo ou dado pessoal de terceiro falham antes do provedor, com mensagem segura para correção.
