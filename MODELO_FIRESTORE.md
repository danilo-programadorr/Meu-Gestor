# Modelo completo proposto do Firebase

Este documento detalha a estrutura solicitada na seção 19 de ESPECIFICACAO_FUNCIONAL.md. É uma proposta de planejamento e não cria recursos Firebase.

## 1. Convenções obrigatórias

- Todos os documentos financeiros pertencem a users/{userId}.
- Cada documento de subcoleção contém ownerId: string, igual ao userId do caminho, imutável.
- Valores monetários usam int em centavos e nomes terminados em Cents.
- Percentuais financeiros usam pontos-base inteiros quando precisão decimal for necessária: 100 pontos-base equivalem a 1%.
- Datas de negócio usam Timestamp; a apresentação converte para America/Sao_Paulo e dd/MM/yyyy.
- createdAt e updatedAt são Timestamp de servidor.
- Documentos financeiros mutáveis futuros poderão conter revision: int. As coleções `accounts`, `categories` e `transactions` dos incrementos atuais possuem esquemas exatos aprovados e não contêm `revision`.
- Documentos contêm schemaVersion: int.
- Exclusões que afetem histórico são lógicas por status ou isArchived; exclusão física segue a política LGPD aprovada.
- IDs não contêm e-mail, nome, CPF, descrição financeira ou outro dado pessoal.
- Campos derivados protegidos são escritos somente por Cloud Functions.
- Mapas e listas têm chaves, tipos e limites declarados; mapas arbitrários são proibidos.

## 2. Perfil

### users/{userId} — UserProfileModel

| Campo | Tipo | Obrigatório | Validação e uso |
|---|---|---:|---|
| ownerId | string | sim | Igual a userId e request.auth.uid |
| displayName | string | sim | Texto normalizado e limitado |
| locale | string | sim | pt-BR na primeira versão |
| currencyCode | string | sim | BRL na primeira versão |
| timeZone | string | sim | America/Sao_Paulo na primeira versão |
| emailVerifiedSnapshot | bool | sim | Espelho informativo; Authentication é a fonte oficial |
| termsVersionAccepted | string | sim | Versão não vazia |
| termsAcceptedAt | timestamp | sim | Timestamp do aceite |
| privacyVersionAccepted | string | sim | Versão não vazia |
| privacyAcceptedAt | timestamp | sim | Timestamp do aceite |
| aiConsentEnabled | bool | sim | Desativado até escolha explícita |
| aiConsentUpdatedAt | timestamp | sim | Auditoria da escolha |
| analyticsConsentEnabled | bool | sim | Conforme base legal e decisão pendente |
| analyticsConsentUpdatedAt | timestamp | sim | Auditoria independente da preferência de Analytics |
| createdAt | timestamp | sim | Imutável |
| updatedAt | timestamp | sim | Timestamp de servidor |
| schemaVersion | int | sim | Positivo |

Regra inicial da Etapa 3C: o usuário lê somente o próprio documento por caminho exato e atualiza apenas `displayName`, preferências opcionais, versões jurídicas atuais, snapshot de verificação e `updatedAt`, sempre com transições validadas. `ownerId`, `createdAt`, locale, moeda, fuso e `schemaVersion` são imutáveis. Exclusão, listagem e todas as subcoleções permanecem negadas. Enquanto Firebase Authentication não informar `emailVerified=true` no usuário recarregado e `email_verified=true` no token atualizado, nenhuma leitura ou escrita do perfil é tentada. Provedor Google segue o valor oficial de `emailVerified` do Authentication.

Versões development iniciais: `terms-dev-1.0.0` e `privacy-dev-1.0.0`. Os dois aceites obrigatórios e os consentimentos opcionais usam `FieldValue.serverTimestamp()`. `aiConsentUpdatedAt` e `analyticsConsentUpdatedAt` mudam somente quando suas respectivas preferências mudam. O perfil possui `schemaVersion` 1 e exatamente os campos desta tabela.

## 3. Cadastros e movimentos financeiros

### users/{userId}/accounts/{accountId} — AccountModel

O ID da conta é o ID do documento e não é duplicado como campo.

| Campo | Tipo | Obrigatório | Validação e uso |
|---|---|---:|---|
| ownerId | string | sim | Igual ao userId do caminho e imutável |
| name | string | sim | Normalizado, 2 a 60 caracteres, sem controles ou espaços repetidos |
| type | string | sim | checking, savings, cash, digitalWallet, investment ou other |
| openingBalanceCents | int | sim | Entre -9.999.999.999 e 9.999.999.999 |
| currencyCode | string | sim | BRL e imutável |
| includeInTotal | bool | sim | Define participação no total enquanto ativa |
| isArchived | bool | sim | false na criação; pareado com archivedAt |
| archivedAt | timestamp ou null | sim | null ativa; timestamp do servidor arquivada |
| createdAt | timestamp | sim | Timestamp do servidor e imutável |
| updatedAt | timestamp | sim | Timestamp do servidor em toda alteração |
| schemaVersion | int | sim | 1 e imutável |

Não existem nesta coleção `currentBalanceCents`, `reservedAmountCents`, `displayOrder`, `revision`, cartão ou fatura. Desde a Etapa 4B, o saldo atual é derivado de `openingBalanceCents` e dos lançamentos ativos confirmados. O total usa somente contas com `isArchived=false` e `includeInTotal=true`.

Quando os movimentos forem implementados, a fonte canônica será `openingBalanceCents + entradas confirmadas - saídas confirmadas + transferências recebidas confirmadas - transferências enviadas confirmadas`. Nenhum saldo materializado será fonte de verdade; caches derivados deverão ser protegidos e reconstruíveis. A correção direta do saldo inicial será então bloqueada ou convertida em ajuste auditável.

Arquivamento substitui exclusão: ativa para arquivada grava `isArchived=true`, `archivedAt=request.time` e `updatedAt=request.time`; restauração grava `isArchived=false`, `archivedAt=null` e `updatedAt=request.time`.

### users/{userId}/categories/{categoryId} — CategoryModel

| Campo | Tipo | Obrigatório | Validação e uso |
|---|---|---:|---|
| ownerId | string | sim | Igual ao UID do caminho e imutável |
| name | string | sim | Normalizado, 2 a 40 caracteres |
| kind | string | sim | income ou expense; imutável |
| iconKey | string | sim | Uma das 14 chaves aprovadas |
| colorKey | string | sim | cyan, blue, green, purple, orange, pink, red, yellow, teal ou gray |
| isArchived | bool | sim | false na criação; pareado com archivedAt |
| archivedAt | timestamp ou null | sim | Timestamp servidor ao arquivar |
| createdAt | timestamp | sim | Servidor e imutável |
| updatedAt | timestamp | sim | Servidor em toda alteração |
| schemaVersion | int | sim | 1 e imutável |

As chaves de ícone são salary, extraIncome, sale, refund, food, home, transport, health, education, leisure, subscription, shopping, bill e other. Categorias são arquivadas, nunca apagadas; uma categoria arquivada permanece disponível para interpretar o histórico, mas não aceita novos lançamentos.

### users/{userId}/transactions/{transactionId} — FinancialTransaction

| Campo | Tipo | Obrigatório | Validação e uso |
|---|---|---:|---|
| ownerId | string | sim | Igual ao UID do caminho e imutável |
| accountId | string | sim | Conta própria ativa na criação; imutável |
| categoryId | string | sim | Categoria própria ativa e compatível com kind |
| kind | string | sim | income ou expense; imutável |
| description | string | sim | Normalizada, 2 a 120 caracteres |
| amountCents | int | sim | 1 a 9.999.999.999; imutável |
| occurredAt | timestamp | sim | Data ocorrida, nunca futura em São Paulo |
| notes | string | sim | Vazia ou até 500 caracteres, sem controles |
| isVoided | bool | sim | false na criação; cancelamento irreversível |
| voidedAt | timestamp ou null | sim | Timestamp servidor ao cancelar |
| createdAt | timestamp | sim | Servidor e imutável |
| updatedAt | timestamp | sim | Servidor em toda alteração |
| schemaVersion | int | sim | 1 ou 2 e imutável |

O esquema 1 contém exatamente os treze campos acima e continua compatível como lançamento manual, sem migração em massa.

O esquema 2 acrescenta os campos obrigatórios `originType` e `originId`. `originType` aceita `manual`, `payable` ou `receivable`. Origem manual exige `originId=null`; as demais exigem o ID válido do compromisso e vínculo bidirecional. Novos documentos usam esquema 2; mappers e regras mantêm o esquema 1 integralmente compatível, sem migração em massa.

O ID é somente o ID do documento. Transferências não usam esta coleção neste incremento. O saldo deriva de lançamentos não cancelados: income soma e expense subtrai. Lançamento esquema 1/manual segue a edição aprovada atual. Lançamento vinculado a compromisso não pode ser editado ou anulado isoladamente.

### users/{userId}/incomes/{incomeId} — IncomeModel

| Campo | Tipo | Obrigatório | Validação e uso |
|---|---|---:|---|
| ownerId | string | sim | Imutável e igual ao caminho |
| description | string | sim | Não vazia e limitada |
| categoryId | string | sim | Categoria de renda pertencente ao usuário |
| amountCents | int | sim | Maior que zero |
| expectedAt | timestamp | sim | Data prevista |
| receivedAt | timestamp ou null | não | Exigida quando recebida |
| recurrenceRuleId | string ou null | não | Regra ativa do usuário |
| occurrenceKey | string ou null | não | Chave idempotente de ocorrência |
| status | string | sim | expected, received, late ou cancelled |
| receiptMethod | string | sim | pix, bankTransfer, cash, card, boleto, check ou other |
| destinationAccountId | string | sim | Conta ativa do usuário |
| notes | string ou null | não | Texto limitado |
| attachmentIds | lista de string | sim | Até cinco comprovantes pertencentes ao usuário |
| confidenceLevel | string | sim | confirmed, high, medium ou low |
| createdAt | timestamp | sim | Imutável |
| updatedAt | timestamp | sim | Servidor |
| schemaVersion | int | sim | Positivo |

Pesos centralizados: confirmed 100%, high 80%, medium 50% e low 20%. Renda cancelada ou atrasada sem nova previsão recebe peso efetivo zero. O documento guarda o nível, não cópias dispersas do peso.

### users/{userId}/receivables/{receivableId} — ReceivableModel

| Campo | Tipo | Obrigatório | Validação e uso |
|---|---|---:|---|
| ownerId | string | sim | Imutável e igual ao caminho |
| description | string | sim | Normalizada, 2 a 120 caracteres |
| categoryId | string | sim | Categoria de renda própria e ativa na criação/edição |
| amountCents | int | sim | 1 a 9.999.999.999 |
| dueAt | timestamp | sim | Data civil de vencimento em São Paulo |
| status | string | sim | pending, received, cancelled ou voided |
| receivedAt | timestamp ou null | sim | Data civil do movimento quando received/voided |
| settlementAccountId | string ou null | sim | Conta do lançamento quando received/voided |
| linkedTransactionId | string ou null | sim | Obrigatório quando received/voided |
| cancelledAt | timestamp ou null | sim | Servidor somente em cancelled |
| voidedAt | timestamp ou null | sim | Servidor somente em voided |
| notes | string | sim | Vazia ou até 500 caracteres |
| revision | int | sim | Começa em 1 e cresce a cada mutação |
| createdAt | timestamp | sim | Servidor e imutável |
| updatedAt | timestamp | sim | Servidor em toda alteração |
| schemaVersion | int | sim | 1 e imutável |

O atraso é derivado quando `status=pending` e `dueAt` antecede a data civil atual de São Paulo. Confirmação integral cria exatamente um `FinancialTransaction` de receita esquema 2 na mesma transação Firestore. Liquidação parcial, contraparte, prioridade, parcelas, anexos e recorrência permanecem fora de FIN-5A.

### users/{userId}/payables/{payableId} — PayableModel

| Campo | Tipo | Obrigatório | Validação e uso |
|---|---|---:|---|
| ownerId | string | sim | Imutável e igual ao caminho |
| description | string | sim | Normalizada, 2 a 120 caracteres |
| categoryId | string | sim | Categoria de despesa própria e ativa na criação/edição |
| amountCents | int | sim | 1 a 9.999.999.999 |
| dueAt | timestamp | sim | Data civil de vencimento em São Paulo |
| status | string | sim | pending, paid, cancelled ou voided |
| paidAt | timestamp ou null | sim | Data civil do movimento quando paid/voided |
| settlementAccountId | string ou null | sim | Conta do lançamento quando paid/voided |
| linkedTransactionId | string ou null | sim | Obrigatório quando paid/voided |
| cancelledAt | timestamp ou null | sim | Servidor somente em cancelled |
| voidedAt | timestamp ou null | sim | Servidor somente em voided |
| notes | string | sim | Vazia ou até 500 caracteres |
| revision | int | sim | Começa em 1 e cresce a cada mutação |
| createdAt | timestamp | sim | Servidor e imutável |
| updatedAt | timestamp | sim | Servidor em toda alteração |
| schemaVersion | int | sim | 1 e imutável |

O atraso é derivado e nunca persistido. Confirmação integral cria exatamente um `FinancialTransaction` de despesa esquema 2 na mesma transação Firestore. Recorrência, parcelas, pagamento parcial, juros, multa, desconto, forma de pagamento, código de barras, anexos e notificações permanecem fora de FIN-5A.

### users/{userId}/adjustments/{adjustmentId} — AdjustmentModel

Campos obrigatórios: ownerId, adjustmentType, fixedAmountCents, percentageBasisPoints, effectiveFrom, description, relatedEntityType, relatedEntityId, appliesToFutureOnly, createdAt, updatedAt e schemaVersion.

`adjustmentType` é fixedAmount ou percentage. Exatamente um entre `fixedAmountCents` e `percentageBasisPoints` deve ser informado e positivo. `effectiveFrom` define a vigência. O reajuste é aplicado somente a ocorrências futuras. Aplicação retroativa exige confirmação explícita e gera operações individualizadas, idempotentes e auditáveis; o documento original não é reescrito silenciosamente.

### users/{userId}/recurrenceRules/{ruleId} — RecurrenceRuleModel

Campos obrigatórios: ownerId, targetType, frequency, interval, dayOfMonth, startAt, nextRunAt, timeZone, isActive, templateSnapshot, createdAt, updatedAt e schemaVersion.

templateSnapshot tem esquema fechado por targetType. A função usa ruleId e competência como chave idempotente em America/Sao_Paulo. Se dayOfMonth não existir, usa o último dia do mês.

### users/{userId}/transfers/{transferId} — TransferModel

Campos obrigatórios: ownerId, sourceAccountId, destinationAccountId, amountCents, occurredAt, status, notes, createdAt, updatedAt e schemaVersion.

Origem e destino devem ser diferentes e pertencer ao usuário. Transferência nunca é renda ou despesa e deve ser gravada atomicamente.

### users/{userId}/investmentPortfolios/{portfolioId} — InvestmentPortfolio

| Campo | Tipo | Obrigatório | Validação e uso |
|---|---|---:|---|
| ownerId | string | sim | UID do caminho e imutável |
| name | string | sim | Normalizado, 1 a 60 caracteres |
| description | string | sim | Vazia ou até 160 caracteres |
| isArchived | bool | sim | Pareado com archivedAt |
| archivedAt | timestamp ou null | sim | `request.time` ao arquivar; null ativa |
| createdAt | timestamp | sim | Servidor e imutável |
| updatedAt | timestamp | sim | Servidor em toda alteração |
| schemaVersion | int | sim | 1 e imutável |
| revision | int | sim | Começa em 1 e cresce uma unidade |

Carteiras são arquivadas e restauradas, nunca excluídas. Carteira arquivada preserva ativos e histórico, mas não aceita novo ativo ou operação.

### users/{userId}/investmentAssets/{assetId} — TrackedInvestmentAsset

O ID é determinístico: `portfolioId__TICKER`, impedindo ticker duplicado na mesma carteira.

| Campo | Tipo | Obrigatório | Validação e uso |
|---|---|---:|---|
| ownerId | string | sim | UID do caminho e imutável |
| portfolioId | string | sim | Carteira própria ativa |
| ticker | string | sim | Maiúsculo, padrão de ação/FII brasileiro |
| name | string | sim | Normalizado, 1 a 80 caracteres |
| assetType | string | sim | `stock` ou `fii` |
| currencyCode | string | sim | BRL e imutável |
| currentQuantityScaled | int | sim | Quantidade atual em escala 8, não negativa |
| lastOperationId | string ou null | sim | Topo ativo da cadeia de operações |
| lastOperationAt | timestamp ou null | sim | Data civil do topo, pareada com o ID |
| createdAt | timestamp | sim | Servidor e imutável |
| updatedAt | timestamp | sim | Servidor em toda alteração |
| schemaVersion | int | sim | 1 e imutável |
| revision | int | sim | Controle otimista e atômico |

Quantidade e topo só mudam junto de uma criação ou anulação válida em `investmentOperations`. Custo, preço médio, resultado realizado, cotação e valor atual não são persistidos no ativo.

### users/{userId}/investmentOperations/{operationId} — InvestmentOperation

| Campo | Tipo | Obrigatório | Validação e uso |
|---|---|---:|---|
| ownerId | string | sim | UID do caminho e imutável |
| portfolioId | string | sim | Carteira própria ativa na criação |
| assetId | string | sim | Ativo próprio da carteira |
| previousOperationId | string ou null | sim | Topo ativo anterior |
| previousOperationAt | timestamp ou null | sim | Data do topo anterior, pareada com o ID |
| kind | string | sim | `buy` ou `sell` |
| occurredAt | timestamp | sim | Data civil São Paulo, não futura e não anterior ao topo |
| quantityScaled | int | sim | Positiva, escala 8 |
| unitPriceScaled | int | sim | Positivo, escala 6 |
| feesCents | int | sim | Taxas não negativas em centavos |
| notes | string | sim | Vazia ou até 240 caracteres |
| isVoided | bool | sim | false na criação; terminal quando true |
| voidedAt | timestamp ou null | sim | `request.time` na anulação |
| mutationId | string | sim | ID de criação ou tentativa idempotente de anulação |
| createdAt | timestamp | sim | Servidor e imutável |
| updatedAt | timestamp | sim | Servidor na criação/anulação |
| schemaVersion | int | sim | 1 e imutável |
| revision | int | sim | 1 na criação; incrementa na anulação |

Operações confirmadas não são editadas nem excluídas. A criação atualiza o ativo na mesma transação; venda acima da quantidade é negada. Somente o topo ativo pode ser anulado, restaurando atomicamente o elo e a quantidade anteriores. Operação anulada não volta ao estado ativo.

### users/{userId}/investmentIncomeEvents/{eventId} — InvestmentIncomeEvent

| Campo | Tipo | Obrigatório | Validação e uso |
|---|---|---:|---|
| ownerId | string | sim | UID do caminho e imutável |
| portfolioId | string | sim | Carteira própria ativa na criação/edição/recebimento |
| assetId | string | sim | Ativo próprio e compatível com a carteira |
| incomeType | string | sim | `dividend`, `jcp` ou `fiiIncome`; ação aceita os dois primeiros, FII aceita o último |
| status | string | sim | `expected`, `received`, `cancelled` ou `voided` |
| inputMode | string | sim | `total` ou `perUnit` |
| exDate | timestamp ou null | sim | Data-com civil opcional |
| expectedPaymentDate | timestamp | sim | Data civil prevista, pode ser futura |
| receivedDate | timestamp ou null | sim | Obrigatória em recebido/anulado e nunca futura |
| eligibleQuantityScaled | int ou null | sim | Escala 8 somente no modo por unidade |
| unitAmountScaled | int ou null | sim | Escala 6 somente no modo por unidade |
| grossAmountCents | int | sim | Positivo; informado no total ou calculado half-up por unidade |
| withholdingTaxCents | int | sim | Imposto retido conhecido, de zero até o bruto |
| netAmountCents | int | sim | Exatamente bruto menos imposto retido |
| notes | string | sim | Vazia ou até 240 caracteres normalizados |
| originType | string | sim | `manual` nesta versão |
| externalId | null | sim | Reservado; integração externa não implementada |
| cancelledAt | timestamp ou null | sim | Servidor somente em cancelamento terminal |
| voidedAt | timestamp ou null | sim | Servidor somente em anulação terminal |
| mutationId | string | sim | ID/mutação idempotente; muda a cada transição |
| createdAt | timestamp | sim | Servidor e imutável |
| updatedAt | timestamp | sim | Servidor em toda mutação |
| schemaVersion | int | sim | 1 e imutável |
| revision | int | sim | 1 na criação e incremento unitário |

Transições permitidas: `expected -> received`, `expected -> cancelled` e `received -> voided`. Somente uma previsão pode ser editada; recebidos preservam dados financeiros e estados terminais não restauram nem excluem. Nenhum índice composto foi criado porque as consultas implementadas leem somente a coleção do próprio UID e filtram localmente.

Essas coleções são exclusivamente patrimoniais e não referenciam `accounts`, `transactions`, `payables` ou `receivables`. Elas não alteram saldo, receitas, despesas, posição do ativo ou resumo mensal.

## 4. Cartões, faturas, parcelas e dívidas

### users/{userId}/creditCards/{cardId} — CreditCardModel

Campos obrigatórios: ownerId, name, totalLimitCents, closingDay, dueDay, paymentAccountId, isArchived, createdAt, updatedAt e schemaVersion.

Campos derivados protegidos: usedLimitCents, availableLimitCents, currentInvoiceCents, bestPurchaseDate e calculatedAt. Compras anteriores ao closingDay entram na fatura atual; compras no closingDay ou depois entram na próxima. bestPurchaseDate é o dia seguinte ao fechamento. invoiceId pode ser corrigido manualmente com auditoria. Limites nunca integram saldo disponível.

### users/{userId}/creditCardInvoices/{invoiceId} — CreditCardInvoiceModel

Campos obrigatórios: ownerId, creditCardId, periodKey, closingAt, dueAt, status, purchasesTotalCents, interestCents, fineCents, paymentsTotalCents, totalCents, createdAt, updatedAt e schemaVersion.

Status: open, closed, partiallyPaid, paid, late ou cancelled. Pagamentos ficam em subcoleção payments. Pagamento de fatura reduz conta e obrigação, sem criar nova despesa.

### users/{userId}/installments/{installmentId} — InstallmentModel

Campos obrigatórios: ownerId, parentType, parentId, sequence, totalInstallments, principalCents, interestCents, fineCents, discountCents, amountCents, dueAt, paidAt, status, occurrenceKey, createdAt, updatedAt e schemaVersion.

parentType referencia compra, despesa, fatura, financiamento ou dívida. occurrenceKey impede duplicação.

### users/{userId}/debts/{debtId} — DebtModel

Campos obrigatórios: ownerId, name, creditor, debtType, originalPrincipalCents, outstandingBalanceCents, interestRateBasisPoints, ratePeriod, effectiveCostBasisPoints, minimumPaymentCents, startAt, dueDay, installmentCount, status, priority, isEssential, createdAt, updatedAt e schemaVersion.

Campos de taxa podem ser nulos quando desconhecidos; análises devem declarar a limitação. Taxas conhecidas são pontos-base inteiros e têm periodicidade explícita. Juros, multas, descontos e custo efetivo vêm do usuário ou de regra cadastrada, nunca de inferência. Status: active, renegotiated, settled ou cancelled.

## 5. Planejamento, simulação e inteligência

### users/{userId}/budgets/{budgetId} — BudgetModel

Campos obrigatórios: ownerId, categoryId, periodKey, limitCents, warningThresholdsPercent, usedCents, forecastCents, status, calculatedAt, createdAt, updatedAt e schemaVersion.

Limiares iniciais: 70, 90 e 100; excedente é estado adicional. usedCents e forecastCents são projeções reconstruíveis protegidas.

### users/{userId}/goals/{goalId} — GoalModel

Campos obrigatórios: ownerId, name, targetAmountCents, accumulatedAmountCents, deadline, priority, monthlyContributionCents, linkedAccountId, status, createdAt, updatedAt e schemaVersion.

Campos derivados: progressBasisPoints, suggestedContributionCents, feasibility e calculatedAt. Aportes e retiradas ficam em goals/{goalId}/movements/{movementId}.

### users/{userId}/simulations/{simulationId} — SimulationModel

Campos obrigatórios: ownerId, name, scenarioType, baseCalculatedAt, assumptions, horizons, resultSummary, applicationPreview, status, revision, createdAt, updatedAt e schemaVersion.

assumptions e resultSummary têm esquema fechado por tipo. applicationPreview lista operações a criar/alterar e impactos em saldos, projeções e metas. Simulação nunca escreve em coleções reais antes de confirmação explícita; a aplicação confirmada é atômica, idempotente e auditável.

### users/{userId}/financialAnalyses/{analysisId} — FinancialAnalysisModel

Campos obrigatórios: ownerId, analysisType, periodStart, periodEnd, modelName, modelVersion, inputDataHash, consentVersion, status, structuredResult, disclaimerVersion, createdAt, expiresAt e schemaVersion. expiresAt é inicialmente 90 dias após createdAt.

Não guardar chave, prompt bruto, anexos ou identificadores desnecessários. structuredResult é validado e contém problema, evidências, ação, impacto, urgência, riscos, alternativas e dados ausentes. Escrita somente por Cloud Function; usuário pode ler e solicitar exclusão. Limite inicial configurável: 10 análises por usuário/dia e aproximadamente 2.000 tokens máximos de saída.

### users/{userId}/monthlySummaries/{summaryId} — MonthlyFinancialSummaryModel

Campos protegidos: ownerId, periodKey, receitas, despesas e saldos em centavos, nominalProjectionCents, conservativeProjectionCents, committedIncomeBasisPoints, freeMoneyCents, riskLevel, riskFacts, totais por categoria, sourceWatermark, calculatedAt e schemaVersion.

É cache protegido e totalmente reconstruível para dashboard, relatórios e IA, escrito somente por função idempotente. Nunca substitui os lançamentos canônicos usados na fórmula oficial do saldo.

Risco usa precedência critical, risk, attention e healthy. riskFacts registra condições determinísticas que causaram a classificação. Crítico cobre saldo atual negativo, projeção negativa em 30 dias, essencial atrasada ou falta para essenciais. Risco cobre projeção negativa de 31 a 90 dias, comprometimento acima de 90%, cartão acima de 90% ou dívida atrasada com juros elevados. Atenção cobre comprometimento de 70% a 90%, dinheiro livre abaixo de 10%, orçamento acima de 90% ou ausência de reserva.

### configuration/financialRules/current — FinancialRulesConfigModel

Documento global, autenticado e somente leitura para clientes; escrita administrativa controlada. Centraliza:

- pesos de confiança 100%, 80%, 50% e 20%;
- limiares de risco;
- média de gasto baseada nos três meses completos anteriores;
- alerta de gasto acima da média em 20% e diferença mínima de 5.000 centavos;
- limite Gemini de 10 análises por dia e aproximadamente 2.000 tokens de saída;
- versões das regras e data de vigência.

Despesas recorrentes classificadas como assinatura contêm subscriptionReviewStatus e subscriptionLastAskedAt. O sistema apenas pergunta “Você ainda utiliza esta assinatura?” e somente sugere manter/cancelar após resposta.

## 6. Notificações, dispositivos, anexos, exportações e auditoria

### users/{userId}/notifications/{notificationId} — NotificationModel

Campos obrigatórios: ownerId, type, relatedEntityType, relatedEntityId, scheduledAt, sentAt, readAt, status, deduplicationKey, safeTitle, safeBody, createdAt, updatedAt, expiresAt e schemaVersion. expiresAt é inicialmente 90 dias após a data aplicável.

Criação e envio são de servidor. Cliente pode ler e marcar como lida. deduplicationKey é única por evento, canal e antecedência. Na tela bloqueada, safeBody padrão é “Você possui um novo alerta financeiro.”; detalhes financeiros exigem abertura autenticada. Preferência mais detalhada exige aviso de privacidade.

### users/{userId}/devices/{deviceId} — DeviceModel

Campos obrigatórios: ownerId, platform, fcmToken, localNotificationsEnabled, notificationPreferences, isActive, lastSeenAt, createdAt, updatedAt e schemaVersion.

Token nunca aparece em logs. O usuário acessa somente dispositivos próprios; funções invalidam tokens rejeitados.

### users/{userId}/attachments/{attachmentId} — AttachmentModel

Campos obrigatórios: ownerId, entityType, entityId, storagePath, generatedFileName, contentType, sizeBytes, sha256, signatureValidationStatus, scanStatus, status, createdAt, updatedAt, orphanedAt e schemaVersion.

Binários ficam no Cloud Storage em users/{userId}/attachments/{attachmentId}/{fileName}. Somente PDF, JPEG e PNG; máximo 10 MB e cinco anexos por entidade. Extensão, MIME e assinatura básica devem concordar. Executáveis e compactados são proibidos. Nome gerado não contém dado pessoal. Não existe URL pública permanente. Download exige proprietário autenticado e App Check quando suportado. Anexo acompanha entidade ativa; órfão expira 30 dias após orphanedAt. Storage e faturamento não serão ativados sem autorização.

### Exportações locais na primeira versão

CSV e planilha compatível com Excel são gerados localmente. PDF é local quando couber com segurança na memória. Os arquivos ficam sob controle do usuário e não são enviados ao Cloud Storage apenas para exportar. A coleção exports e a geração por Cloud Function ficam fora da primeira versão e exigem nova aprovação para exportações muito grandes.

### users/{userId}/auditLogs/{auditId} — AuditLogModel

Campos obrigatórios protegidos: ownerId, action, entityType, entityId, actorType, requestId, result, createdAt, expiresAt e schemaVersion. expiresAt é inicialmente 180 dias após createdAt.

Somente Cloud Functions escrevem. Não armazena valores financeiros completos, tokens, anexos, prompts ou descrições pessoais.

### Proposta futura — users/{userId}/entitlements/premium

Este caminho é somente proposta do SUB-1A. Nenhuma coleção, documento, índice, regra ou implementação Firebase foi criada.

O documento fixo futuro poderá conter ownerId, planId, status, source, environment, capabilities, entitlementStartedAt, currentPeriodStartedAt, currentPeriodEndsAt, graceUntil, cancelAtPeriodEnd, cancelledAt, expiredAt, revokedAt, refundedAt, lastVerifiedAt, revision e schemaVersion. O contrato será fechado, versionado e escrito exclusivamente por backend após validação autoritativa.

O aplicativo poderá ler somente o entitlement do próprio UID e nunca poderá criar, ativar, renovar, revogar, reembolsar ou conceder. Purchase token, recibo bruto, payload do provedor, credenciais, dados de cartão, preço e auditoria confidencial não pertencerão ao documento legível pelo cliente. Grants administrativos e de development terão validade, ambiente e trilha de auditoria server-side; owner não recebe acesso cruzado.

Ausência do documento representará plano gratuito. Expiração não apagará investimentos: leitura histórica será preservada, mutações serão negadas e serviços recorrentes como cotação serão interrompidos. Persistência, backend, mappers, regras, testes e custos exigem incremento e autorização separados.

## 7. Conversores Dart

Cada coleção terá modelo Dart imutável e conversor tipado:

- fromFirestore com DocumentSnapshot tipado;
- toFirestore com opções explícitas;
- validação de enumerações antes da construção;
- conversão explícita de Timestamp para tipos de domínio;
- conversão explícita de centavos para objeto de valor monetário;
- rejeição de campo ausente, tipo inesperado e versão não suportada;
- separação entre DTO Firestore e entidade de domínio;
- nenhuma conversão silenciosa de double para dinheiro.

## 8. Índices compostos previstos

| Coleção | Campos do índice |
|---|---|
| incomes | status, expectedAt crescente |
| incomes | destinationAccountId, receivedAt decrescente |
| incomes | categoryId, expectedAt decrescente |
| receivables | status, dueAt crescente |
| receivables | categoryId, dueAt decrescente |
| payables | status, dueAt crescente |
| payables | categoryId, dueAt decrescente |
| expenses | status, dueAt crescente |
| expenses | accountId, paidAt decrescente |
| expenses | categoryId, dueAt decrescente |
| expenses | creditCardId, invoiceId, dueAt crescente |
| creditCardInvoices | creditCardId, dueAt decrescente |
| installments | parentType, parentId, sequence crescente |
| debts | status, interestRateBasisPoints decrescente |
| budgets | periodKey, categoryId crescente |
| goals | status, deadline crescente |
| notifications | status, scheduledAt crescente |
| financialAnalyses | analysisType, createdAt decrescente |
| simulations | status, updatedAt decrescente |
| monthlySummaries | periodKey decrescente |
| exports | status, requestedAt decrescente |

Os índices serão confirmados pelas consultas reais. Índices não utilizados serão evitados por custo de armazenamento e escrita.

## 9. Matriz de acesso

| Recurso | Leitura do proprietário | Alteração pelo proprietário | Escrita por Functions |
|---|---:|---:|---:|
| Perfil | sim | campos permitidos | campos protegidos e exclusão |
| Contas e categorias | sim | sim, com validação | migração e auditoria |
| Rendas, contas a pagar, contas a receber e transferências | sim | sim, com invariantes | recorrência e resumos futuros |
| Cartões e dívidas | sim | sim, com validação | campos derivados |
| Faturas e parcelas | sim | operações permitidas | geração e campos derivados |
| Orçamentos e metas | sim | configuração e movimentos | projeções derivadas |
| Simulações | sim | sim | cálculo protegido opcional |
| Análises financeiras | sim | não diretamente | sim |
| Notificações | sim | somente estado permitido | sim |
| Dispositivos | sim | registro e preferências | invalidação |
| Anexos | sim | metadados e arquivo próprios | varredura e remoção |
| Exportações locais | não persistidas por padrão | sob controle do usuário | função futura exige nova aprovação |
| Resumos e auditoria | conforme política | não | sim |
| `system_admins/{uid}` | somente o próprio documento, por `get` e e-mail verificado | não | criação/revogação manual nesta etapa |

### 9.1 Documento administrativo de development

`system_admins/{uid}` usa o UID somente como ID do documento e contém exatamente:

| Campo | Tipo | Obrigatório | Validação |
|---|---|---:|---|
| role | string | sim | `owner` |
| active | bool | sim | true ou false |
| environment | string | sim | `development` |
| grantedAt | timestamp | sim | timestamp válido |
| schemaVersion | int | sim | 1 |

Não há consulta de coleção, índice composto, listener, escrita cliente ou duplicação do UID. Documento ausente significa usuário comum. Cache não confirma owner. O documento é criado, alterado, revogado ou excluído somente de forma manual no Console durante esta etapa.

## 10. Regras Firestore e Storage

- Negar tudo antes das regras específicas.
- Exigir request.auth não nulo e request.auth.uid igual a userId.
- Exigir `request.auth.token.email_verified == true` para ler ou gravar qualquer coleção financeira; as exceções pré-verificação ficam fora desses caminhos e limitadas ao fluxo aprovado.
- Exigir ownerId igual a userId na criação e impedir alteração posterior.
- Usar listas fechadas de campos permitidos e obrigatórios.
- Validar tipos, comprimentos, enumerações, centavos, datas e transições.
- Validar referências críticas dentro dos limites das regras.
- Proibir escrita cliente em campos derivados, auditoria, análises e resultados de exportação.
- Impedir consultas que não satisfaçam as restrições de proprietário.
- Aplicar regras equivalentes no Cloud Storage, com proprietário, caminho, tipo e tamanho.
- Testar leitura e escrita permitidas e negadas no Emulator Suite.
- App Check complementa, mas não substitui Authentication e Security Rules.
- O Admin SDK ignora Security Rules; cada Function valida usuário, App Check, payload, autorização e idempotência.
- Operações críticas preparadas offline não recebem status confirmado até sincronização e validação de revision/updatedAt. Conflitos exibem versões; last-write-wins silencioso é proibido.

## 11. Migração e exclusão

- schemaVersion determina conversor e migração.
- Migrações são idempotentes, auditadas e testadas em development.
- Exclusão LGPD usa função autenticada, reautenticação quando necessária, marcação de processo, remoção de subcoleções, arquivos, tokens, análises, exportações e conta Auth.
- Retenção inicial: análises 90 dias, auditoria técnica 180 dias, notificações 90 dias, anexos enquanto vinculados e órfãos por 30 dias.
- Backups de produção são planejados para 30 dias, sem ativação paga antes de autorização. Processo, teste, acesso, custo e autorizador da restauração devem estar documentados antes do lançamento.
- Exclusão interrompe novas operações, remove dados ativos/anexos, revoga dispositivos e informa a janela de remoção dos backups.
