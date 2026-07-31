# Modelo completo proposto do Firebase

Este documento detalha a estrutura solicitada na seção 19 de ESPECIFICACAO_FUNCIONAL.md. É uma proposta de planejamento e não cria recursos Firebase.

## 1. Convenções obrigatórias

- Todos os documentos financeiros pertencem a users/{userId}.
- Cada documento de subcoleção contém ownerId: string, igual ao userId do caminho, imutável.
- Valores monetários usam int em centavos e nomes terminados em Cents.
- Percentuais financeiros usam pontos-base inteiros quando precisão decimal for necessária: 100 pontos-base equivalem a 1%.
- Datas de negócio usam Timestamp; a apresentação converte para America/Sao_Paulo e dd/MM/yyyy.
- createdAt e updatedAt são Timestamp de servidor.
- Documentos financeiros mutáveis contêm revision: int, incrementado em cada alteração confirmada pelo servidor.
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
| createdAt | timestamp | sim | Imutável |
| updatedAt | timestamp | sim | Timestamp de servidor |
| schemaVersion | int | sim | Positivo |

Regra: o usuário lê e atualiza somente campos permitidos do próprio perfil. Campos de auditoria protegidos são atualizados por função. Enquanto Firebase Authentication não informar `emailVerified=true`, nenhuma leitura ou escrita financeira é permitida. O usuário não verificado fica restrito aos fluxos de confirmação, reenvio, atualização do estado, logout, exclusão e consulta de termos/política. Provedor Google segue o valor oficial de `emailVerified` do Authentication.

## 3. Cadastros e movimentos financeiros

### users/{userId}/accounts/{accountId} — AccountModel

Campos obrigatórios: ownerId: string, name: string, type: string, currencyCode: string, openingBalanceCents: int, reservedAmountCents: int, displayOrder: int, isArchived: bool, revision: int, createdAt, updatedAt e schemaVersion.

Enumeração inicial de type: checking, savings, cash, digitalWallet e other. Cartões de crédito ficam em coleção própria e não contam como dinheiro disponível.

Validações: nome limitado; moeda BRL; valores inteiros; conta com referências não pode ser removida diretamente. A fonte canônica do saldo é `openingBalanceCents + entradas confirmadas - saídas confirmadas + transferências recebidas confirmadas - transferências enviadas confirmadas`. Nenhum campo de saldo materializado é fonte de verdade. `reservedAmountCents`, saldos calculados e resumos são protegidos, derivados e totalmente reconstruíveis. Os movimentos de metas de reserva vinculadas permanecem canônicos para a reserva.

### users/{userId}/categories/{categoryId} — CategoryModel

Campos obrigatórios: ownerId, name: string, kind: string, essentiality: string, iconKey: string, colorValue: int, isArchived: bool, createdAt, updatedAt e schemaVersion.

Enumerações: kind é income ou expense; essentiality é essential, nonEssential ou unclassified. Categorias referenciadas são arquivadas, não apagadas.

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
| description | string | sim | Não vazia e limitada |
| debtorOrSource | string ou null | não | Texto opcional e protegido |
| categoryId | string | sim | Categoria pertencente ao usuário |
| totalAmountCents | int | sim | Maior que zero |
| receivedAmountCents | int | sim | Derivado dos recebimentos vinculados |
| remainingAmountCents | int | sim | Derivado e nunca negativo |
| expectedAt | timestamp | sim | Data prevista |
| receivedAt | timestamp ou null | não | Data de quitação integral |
| installmentCount | int | sim | Pelo menos 1 |
| status | string | sim | expected, partiallyReceived, received, late, renegotiated ou cancelled |
| priority | string | sim | Enumeração aprovada |
| notes | string ou null | não | Texto limitado |
| attachmentIds | lista de string | sim | No máximo cinco anexos próprios |
| revision | int | sim | Controle de concorrência |
| createdAt | timestamp | sim | Imutável |
| updatedAt | timestamp | sim | Servidor |
| schemaVersion | int | sim | Positivo |

Pode representar venda, empréstimo feito a outra pessoa, reembolso, aluguel, serviço, crédito parcelado ou outro crédito. Cada recebimento fica em receivables/{receivableId}/receipts/{receiptId}, é imutável e cria ou vincula exatamente um IncomeModel por chave idempotente, sem duplicar valor.

### users/{userId}/expenses/{expenseId} — ExpenseModel

| Campo | Tipo | Obrigatório | Validação e uso |
|---|---|---:|---|
| ownerId | string | sim | Imutável |
| name | string | sim | Não vazio e limitado |
| description | string ou null | não | Texto limitado |
| categoryId | string | sim | Categoria de despesa do usuário |
| expectedAmountCents | int | sim | Não negativo |
| paidAmountCents | int | sim | Não negativo e coerente com status |
| dueAt | timestamp | sim | Vencimento |
| paidAt | timestamp ou null | não | Exigido conforme status |
| recurrenceRuleId | string ou null | não | Regra do usuário |
| occurrenceKey | string ou null | não | Chave idempotente |
| installmentCount | int | sim | Pelo menos 1 |
| currentInstallment | int | sim | Entre 1 e o total |
| priority | string | sim | essential, high, medium, low ou deferrable |
| status | string | sim | pending, paid, partiallyPaid, late, renegotiated ou cancelled |
| interestCents | int | sim | Não negativo |
| fineCents | int | sim | Não negativo |
| discountCents | int | sim | Não negativo |
| interestRateBasisPoints | int ou null | não | Taxa informada, nunca inferida |
| paymentMethod | string | sim | pix, bankTransfer, cash, debitCard, creditCard, boleto, automaticDebit ou other |
| accountId | string ou null | não | Conta usada quando aplicável |
| creditCardId | string ou null | não | Cartão do usuário quando aplicável |
| invoiceId | string ou null | não | Fatura coerente com o cartão |
| barcode | string ou null | não | Sanitizado, limitado e ausente de logs |
| notes | string ou null | não | Texto limitado |
| attachmentIds | lista de string | sim | Até cinco anexos pertencentes ao usuário |
| subscriptionReviewStatus | string ou null | não | unknown, stillUsed ou unused |
| subscriptionLastAskedAt | timestamp ou null | não | Controle de pergunta periódica |
| createdAt | timestamp | sim | Imutável |
| updatedAt | timestamp | sim | Servidor |
| schemaVersion | int | sim | Positivo |

Pagamentos parciais exigem histórico. Cada pagamento fica em users/{userId}/expenses/{expenseId}/payments/{paymentId} com ownerId, amountCents, paidAt, accountId, interestCents, fineCents, status, cancellationOfPaymentId, compensationForPaymentId, createdAt e schemaVersion. O registro é imutável; correções usam cancelamento ou lançamento compensatório auditável.

### users/{userId}/adjustments/{adjustmentId} — AdjustmentModel

Campos obrigatórios: ownerId, adjustmentType, fixedAmountCents, percentageBasisPoints, effectiveFrom, description, relatedEntityType, relatedEntityId, appliesToFutureOnly, createdAt, updatedAt e schemaVersion.

`adjustmentType` é fixedAmount ou percentage. Exatamente um entre `fixedAmountCents` e `percentageBasisPoints` deve ser informado e positivo. `effectiveFrom` define a vigência. O reajuste é aplicado somente a ocorrências futuras. Aplicação retroativa exige confirmação explícita e gera operações individualizadas, idempotentes e auditáveis; o documento original não é reescrito silenciosamente.

### users/{userId}/recurrenceRules/{ruleId} — RecurrenceRuleModel

Campos obrigatórios: ownerId, targetType, frequency, interval, dayOfMonth, startAt, nextRunAt, timeZone, isActive, templateSnapshot, createdAt, updatedAt e schemaVersion.

templateSnapshot tem esquema fechado por targetType. A função usa ruleId e competência como chave idempotente em America/Sao_Paulo. Se dayOfMonth não existir, usa o último dia do mês.

### users/{userId}/transfers/{transferId} — TransferModel

Campos obrigatórios: ownerId, sourceAccountId, destinationAccountId, amountCents, occurredAt, status, notes, createdAt, updatedAt e schemaVersion.

Origem e destino devem ser diferentes e pertencer ao usuário. Transferência nunca é renda ou despesa e deve ser gravada atomicamente.

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
| receivables | status, expectedAt crescente |
| receivables | categoryId, expectedAt decrescente |
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
| Rendas, contas a receber, despesas e transferências | sim | sim, com invariantes | recorrência, atraso e resumos |
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
