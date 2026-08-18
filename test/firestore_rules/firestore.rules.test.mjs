import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import assert from 'node:assert/strict';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  Timestamp,
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  serverTimestamp,
  setDoc,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';

const projectId = 'demo-meu-gestor-financeiro';
const ownerId = 'owner-1';
const otherId = 'owner-2';
const rulesSource = readFileSync('firestore.rules', 'utf8');
const past = Timestamp.fromDate(new Date('2026-08-01T12:00:00Z'));
const dueAt = Timestamp.fromDate(new Date('2026-08-05T03:00:00Z'));
const movementAt = Timestamp.fromDate(new Date('2026-08-02T03:00:00Z'));

let testEnv;

function profile(uid, overrides = {}) {
  return {
    ownerId: uid,
    displayName: 'Pessoa Teste',
    locale: 'pt-BR',
    currencyCode: 'BRL',
    timeZone: 'America/Sao_Paulo',
    emailVerifiedSnapshot: true,
    termsVersionAccepted: 'terms-dev-1.0.0',
    termsAcceptedAt: past,
    privacyVersionAccepted: 'privacy-dev-1.0.0',
    privacyAcceptedAt: past,
    aiConsentEnabled: false,
    aiConsentUpdatedAt: past,
    analyticsConsentEnabled: false,
    analyticsConsentUpdatedAt: past,
    createdAt: past,
    updatedAt: past,
    schemaVersion: 1,
    ...overrides,
  };
}

function account(uid, overrides = {}) {
  return {
    ownerId: uid,
    name: 'Conta principal',
    type: 'checking',
    openingBalanceCents: 0,
    currencyCode: 'BRL',
    includeInTotal: true,
    isArchived: false,
    archivedAt: null,
    createdAt: past,
    updatedAt: past,
    schemaVersion: 1,
    ...overrides,
  };
}

function category(uid, kind, overrides = {}) {
  return {
    ownerId: uid,
    name: kind === 'expense' ? 'Moradia' : 'Salário',
    kind,
    iconKey: kind === 'expense' ? 'home' : 'salary',
    colorKey: kind === 'expense' ? 'orange' : 'green',
    isArchived: false,
    archivedAt: null,
    createdAt: past,
    updatedAt: past,
    schemaVersion: 1,
    ...overrides,
  };
}

function commitment(uid, type, overrides = {}) {
  const payable = type === 'payable';
  return {
    ownerId: uid,
    description: payable ? 'Conta de luz' : 'Serviço prestado',
    categoryId: payable ? 'expense-category' : 'income-category',
    amountCents: 12345,
    dueAt,
    status: 'pending',
    [payable ? 'paidAt' : 'receivedAt']: null,
    settlementAccountId: null,
    linkedTransactionId: null,
    cancelledAt: null,
    voidedAt: null,
    notes: '',
    revision: 1,
    createdAt: past,
    updatedAt: past,
    schemaVersion: 1,
    ...overrides,
  };
}

function manualTransaction(uid, overrides = {}) {
  return {
    ownerId: uid,
    accountId: 'account-1',
    categoryId: 'expense-category',
    kind: 'expense',
    description: 'Compra manual',
    amountCents: 5000,
    occurredAt: movementAt,
    notes: '',
    isVoided: false,
    voidedAt: null,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    schemaVersion: 2,
    originType: 'manual',
    originId: null,
    ...overrides,
  };
}

function legacyTransaction(uid, overrides = {}) {
  return {
    ownerId: uid,
    accountId: 'account-1',
    categoryId: 'expense-category',
    kind: 'expense',
    description: 'Lançamento legado',
    amountCents: 7000,
    occurredAt: movementAt,
    notes: '',
    isVoided: false,
    voidedAt: null,
    createdAt: past,
    updatedAt: past,
    schemaVersion: 1,
    ...overrides,
  };
}

function linkedTransaction(uid, type, commitmentId, overrides = {}) {
  const payable = type === 'payable';
  return {
    ownerId: uid,
    accountId: 'account-1',
    categoryId: payable ? 'expense-category' : 'income-category',
    kind: payable ? 'expense' : 'income',
    description: payable ? 'Conta de luz' : 'Serviço prestado',
    amountCents: 12345,
    occurredAt: movementAt,
    notes: '',
    isVoided: false,
    voidedAt: null,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    schemaVersion: 2,
    originType: type,
    originId: commitmentId,
    ...overrides,
  };
}

function verifiedDb(uid = ownerId) {
  return testEnv.authenticatedContext(uid, { email_verified: true }).firestore();
}

function unverifiedDb(uid = ownerId) {
  return testEnv.authenticatedContext(uid, { email_verified: false }).firestore();
}

function commitmentRef(db, type, id) {
  return doc(db, `users/${ownerId}/${type === 'payable' ? 'payables' : 'receivables'}/${id}`);
}

function transactionRef(db, id) {
  return doc(db, `users/${ownerId}/transactions/${id}`);
}

function investmentPortfolio(uid, overrides = {}) {
  return {
    ownerId: uid,
    name: 'Longo prazo',
    description: 'Acompanhamento manual',
    isArchived: false,
    archivedAt: null,
    createdAt: past,
    updatedAt: past,
    schemaVersion: 1,
    revision: 1,
    ...overrides,
  };
}

function investmentAsset(uid, overrides = {}) {
  return {
    ownerId: uid,
    portfolioId: 'portfolio-1',
    ticker: 'PETR4',
    name: 'Petrobras PN',
    assetType: 'stock',
    currencyCode: 'BRL',
    currentQuantityScaled: 0,
    lastOperationId: null,
    lastOperationAt: null,
    createdAt: past,
    updatedAt: past,
    schemaVersion: 1,
    revision: 1,
    ...overrides,
  };
}

function investmentOperation(uid, overrides = {}) {
  return {
    ownerId: uid,
    portfolioId: 'portfolio-1',
    assetId: 'portfolio-1__PETR4',
    previousOperationId: null,
    previousOperationAt: null,
    kind: 'buy',
    occurredAt: movementAt,
    quantityScaled: 100000000,
    unitPriceScaled: 32000000,
    feesCents: 25,
    notes: '',
    isVoided: false,
    voidedAt: null,
    mutationId: 'operation-1',
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    schemaVersion: 1,
    revision: 1,
    ...overrides,
  };
}

function investmentIncome(uid, overrides = {}) {
  return {
    ownerId: uid,
    portfolioId: 'portfolio-1',
    assetId: 'portfolio-1__PETR4',
    incomeType: 'dividend',
    status: 'expected',
    inputMode: 'total',
    exDate: null,
    expectedPaymentDate: dueAt,
    receivedDate: null,
    eligibleQuantityScaled: null,
    unitAmountScaled: null,
    grossAmountCents: 10000,
    withholdingTaxCents: 1500,
    netAmountCents: 8500,
    notes: '',
    originType: 'manual',
    externalId: null,
    cancelledAt: null,
    voidedAt: null,
    mutationId: 'income-1',
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    schemaVersion: 1,
    revision: 1,
    ...overrides,
  };
}

function investmentPortfolioRef(db, id = 'portfolio-1', uid = ownerId) {
  return doc(db, `users/${uid}/investmentPortfolios/${id}`);
}

function investmentAssetRef(db, id = 'portfolio-1__PETR4', uid = ownerId) {
  return doc(db, `users/${uid}/investmentAssets/${id}`);
}

function investmentOperationRef(db, id = 'operation-1', uid = ownerId) {
  return doc(db, `users/${uid}/investmentOperations/${id}`);
}

function investmentIncomeRef(db, id = 'income-1', uid = ownerId) {
  return doc(db, `users/${uid}/investmentIncomeEvents/${id}`);
}

async function seedInvestments({ assetOverrides = {}, operation = null } = {}) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(investmentPortfolioRef(db), investmentPortfolio(ownerId));
    await setDoc(investmentAssetRef(db), investmentAsset(ownerId, assetOverrides));
    if (operation != null) {
      await setDoc(
        investmentOperationRef(db, operation.id),
        investmentOperation(ownerId, operation.data),
      );
    }
  });
}

async function seedInvestmentIncome({
  id = 'income-1',
  incomeOverrides = {},
  assetOverrides = {},
} = {}) {
  await seedInvestments({ assetOverrides });
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      investmentIncomeRef(context.firestore(), id),
      investmentIncome(ownerId, {
        mutationId: id,
        createdAt: past,
        updatedAt: past,
        ...incomeOverrides,
      }),
    );
  });
}

function receiveInvestmentIncome(db, {
  id = 'income-1',
  mutationId = 'receive-income-1',
  overrides = {},
} = {}) {
  return updateDoc(investmentIncomeRef(db, id), {
    status: 'received',
    receivedDate: movementAt,
    mutationId,
    updatedAt: serverTimestamp(),
    revision: 2,
    ...overrides,
  });
}

function cancelInvestmentIncome(db, {
  id = 'income-1',
  mutationId = 'cancel-income-1',
  overrides = {},
} = {}) {
  return updateDoc(investmentIncomeRef(db, id), {
    status: 'cancelled',
    cancelledAt: serverTimestamp(),
    mutationId,
    updatedAt: serverTimestamp(),
    revision: 2,
    ...overrides,
  });
}

function voidInvestmentIncome(db, {
  id = 'income-1',
  mutationId = 'void-income-1',
  overrides = {},
} = {}) {
  return updateDoc(investmentIncomeRef(db, id), {
    status: 'voided',
    voidedAt: serverTimestamp(),
    mutationId,
    updatedAt: serverTimestamp(),
    revision: 3,
    ...overrides,
  });
}

function appendInvestmentOperation(db, {
  id = 'operation-1',
  kind = 'buy',
  quantityScaled = 100000000,
  occurredAt = movementAt,
  previousOperationId = null,
  previousOperationAt = null,
  currentQuantityScaled = 100000000,
  assetRevision = 2,
  operationOverrides = {},
  assetOverrides = {},
} = {}) {
  const batch = writeBatch(db);
  batch.set(
    investmentOperationRef(db, id),
    investmentOperation(ownerId, {
      mutationId: id,
      kind,
      quantityScaled,
      occurredAt,
      previousOperationId,
      previousOperationAt,
      ...operationOverrides,
    }),
  );
  batch.update(investmentAssetRef(db), {
    currentQuantityScaled,
    lastOperationId: id,
    lastOperationAt: occurredAt,
    updatedAt: serverTimestamp(),
    revision: assetRevision,
    ...assetOverrides,
  });
  return batch.commit();
}

function voidInvestmentOperation(db, {
  id = 'operation-1',
  mutationId = 'void-1',
  currentQuantityScaled = 0,
  previousOperationId = null,
  previousOperationAt = null,
  operationOverrides = {},
  assetOverrides = {},
} = {}) {
  const batch = writeBatch(db);
  batch.update(investmentOperationRef(db, id), {
    isVoided: true,
    voidedAt: serverTimestamp(),
    mutationId,
    updatedAt: serverTimestamp(),
    revision: 2,
    ...operationOverrides,
  });
  batch.update(investmentAssetRef(db), {
    currentQuantityScaled,
    lastOperationId: previousOperationId,
    lastOperationAt: previousOperationAt,
    updatedAt: serverTimestamp(),
    revision: 3,
    ...assetOverrides,
  });
  return batch.commit();
}

function ruleFunctionSource(name) {
  const marker = `function ${name}(`;
  const start = rulesSource.indexOf(marker);
  assert.notEqual(start, -1, `função ${name} não encontrada nas regras`);
  const openingBrace = rulesSource.indexOf('{', start);
  let depth = 0;
  for (let index = openingBrace; index < rulesSource.length; index += 1) {
    if (rulesSource[index] === '{') depth += 1;
    if (rulesSource[index] === '}') depth -= 1;
    if (depth === 0) return rulesSource.slice(start, index + 1);
  }
  assert.fail(`função ${name} não foi encerrada nas regras`);
}

function assertSameTimestamp(left, right, message) {
  assert.ok(left instanceof Timestamp, `${message}: primeiro valor não é timestamp`);
  assert.ok(right instanceof Timestamp, `${message}: segundo valor não é timestamp`);
  assert.ok(left.isEqual(right), message);
}

async function seedBase(extra = async () => {}) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await Promise.all([
      setDoc(doc(db, `users/${ownerId}`), profile(ownerId)),
      setDoc(doc(db, `users/${otherId}`), profile(otherId)),
      setDoc(doc(db, `users/${ownerId}/accounts/account-1`), account(ownerId)),
      setDoc(doc(db, `users/${ownerId}/accounts/account-2`), account(ownerId, { name: 'Conta secundária' })),
      setDoc(doc(db, `users/${ownerId}/categories/expense-category`), category(ownerId, 'expense')),
      setDoc(doc(db, `users/${ownerId}/categories/income-category`), category(ownerId, 'income')),
      setDoc(doc(db, `system_admins/${ownerId}`), {
        role: 'owner',
        active: true,
        environment: 'development',
        schemaVersion: 1,
        grantedAt: past,
      }),
    ]);
    await extra(db);
  });
}

async function seedPending(type, id) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(commitmentRef(context.firestore(), type, id), commitment(ownerId, type));
  });
}

function premiumEntitlement(uid, overrides = {}) {
  return {
    ownerId: uid,
    planId: 'monthly',
    status: 'active',
    source: 'googlePlay',
    environment: 'development',
    capabilities: ['investmentsManual', 'investmentIncome'],
    startedAt: past,
    currentPeriodStart: past,
    currentPeriodEnd: Timestamp.fromDate(new Date('2026-09-01T00:00:00Z')),
    graceUntil: null,
    cancelAtPeriodEnd: false,
    cancelledAt: null,
    expiredAt: null,
    revokedAt: null,
    refundedAt: null,
    lastVerifiedAt: past,
    revision: 1,
    schemaVersion: 1,
    createdAt: past,
    updatedAt: past,
    ...overrides,
  };
}

async function seedPremium(uid = ownerId, overrides = {}) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), `users/${uid}/entitlements/premium`),
      premiumEntitlement(uid, overrides),
    );
  });
}

function marketQuoteSnapshot(overrides = {}) {
  return {
    ticker: 'PETR4',
    assetType: 'stock',
    currencyCode: 'BRL',
    market: 'B3',
    source: 'brapi',
    priceScaled: 31450000,
    variationBasisPoints: -123,
    observedAt: past,
    capturedAt: past,
    declaredDelaySeconds: 900,
    staleAfter: Timestamp.fromDate(new Date('2026-09-01T00:00:00Z')),
    status: 'delayed',
    schemaVersion: 1,
    ...overrides,
  };
}

async function seedMarketQuote(overrides = {}) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), 'marketQuoteSnapshots/PETR4'),
      marketQuoteSnapshot(overrides),
    );
  });
}

async function settle(db, { type = 'payable', id, transactionId, commitmentOverrides = {}, transactionOverrides = {} }) {
  const batch = writeBatch(db);
  const settledStatus = type === 'payable' ? 'paid' : 'received';
  const movementField = type === 'payable' ? 'paidAt' : 'receivedAt';
  batch.update(commitmentRef(db, type, id), {
    status: settledStatus,
    [movementField]: movementAt,
    settlementAccountId: 'account-1',
    linkedTransactionId: transactionId,
    revision: 2,
    updatedAt: serverTimestamp(),
    ...commitmentOverrides,
  });
  batch.set(
    transactionRef(db, transactionId),
    linkedTransaction(ownerId, type, id, transactionOverrides),
  );
  return batch.commit();
}

async function voidSettlement(db, {
  type = 'payable',
  id,
  transactionId,
  commitmentOverrides = {},
  transactionOverrides = {},
}) {
  const batch = writeBatch(db);
  batch.update(commitmentRef(db, type, id), {
    status: 'voided',
    voidedAt: serverTimestamp(),
    revision: 3,
    updatedAt: serverTimestamp(),
    ...commitmentOverrides,
  });
  batch.update(transactionRef(db, transactionId), {
    isVoided: true,
    voidedAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    ...transactionOverrides,
  });
  return batch.commit();
}

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId,
    firestore: {
      rules: rulesSource,
    },
  });
});

beforeEach(async () => {
  await testEnv.clearFirestore();
  await seedBase();
});

after(async () => {
  await testEnv.cleanup();
});

describe('autenticação e isolamento por UID', () => {
  test('proprietário verificado lê somente os próprios compromissos', async () => {
    await seedPending('payable', 'payable-auth');
    await assertSucceeds(getDoc(commitmentRef(verifiedDb(), 'payable', 'payable-auth')));
    await assertFails(getDoc(doc(verifiedDb(otherId), `users/${ownerId}/payables/payable-auth`)));
  });

  test('nega usuário não autenticado e e-mail não confirmado', async () => {
    await seedPending('receivable', 'receivable-auth');
    const anonymous = testEnv.unauthenticatedContext().firestore();
    await assertFails(getDoc(commitmentRef(anonymous, 'receivable', 'receivable-auth')));
    await assertFails(getDoc(commitmentRef(unverifiedDb(), 'receivable', 'receivable-auth')));
  });
});

describe('contrato estrito e referências', () => {
  test('cria pendências válidas nas duas coleções', async () => {
    const db = verifiedDb();
    const payable = commitment(ownerId, 'payable', {
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
    const receivable = commitment(ownerId, 'receivable', {
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
    await assertSucceeds(setDoc(commitmentRef(db, 'payable', 'payable-create'), payable));
    await assertSucceeds(setDoc(commitmentRef(db, 'receivable', 'receivable-create'), receivable));
  });

  test('nega campos ausentes e extras', async () => {
    const db = verifiedDb();
    const missing = commitment(ownerId, 'payable', {
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
    delete missing.notes;
    const extra = commitment(ownerId, 'payable', {
      overdue: true,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
    await assertFails(setDoc(commitmentRef(db, 'payable', 'payable-missing'), missing));
    await assertFails(setDoc(commitmentRef(db, 'payable', 'payable-extra'), extra));
  });

  test('nega categoria ausente, arquivada ou de tipo divergente', async () => {
    const db = verifiedDb();
    for (const [id, categoryId] of [
      ['missing-reference', 'does-not-exist'],
      ['wrong-kind', 'income-category'],
    ]) {
      await assertFails(setDoc(commitmentRef(db, 'payable', id), commitment(ownerId, 'payable', {
        categoryId,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      })));
    }
  });
});

describe('liquidação atômica e idempotência', () => {
  test('confirma pagamento e recebimento com exatamente um vínculo bidirecional', async () => {
    await seedPending('payable', 'payable-valid');
    await seedPending('receivable', 'receivable-valid');
    const db = verifiedDb();
    await assertSucceeds(settle(db, { id: 'payable-valid', transactionId: 'tx-payable-valid' }));
    await assertSucceeds(settle(db, { type: 'receivable', id: 'receivable-valid', transactionId: 'tx-receivable-valid' }));
    const paid = (await getDoc(commitmentRef(db, 'payable', 'payable-valid'))).data();
    assert.equal(paid.linkedTransactionId, 'tx-payable-valid');
    assert.equal(paid.settlementAccountId, 'account-1');
  });

  test('nega confirmação sem lançamento e lançamento sem atualização do compromisso', async () => {
    await seedPending('payable', 'payable-half');
    const db = verifiedDb();
    await assertFails(updateDoc(commitmentRef(db, 'payable', 'payable-half'), {
      status: 'paid',
      paidAt: movementAt,
      settlementAccountId: 'account-1',
      linkedTransactionId: 'tx-missing',
      revision: 2,
      updatedAt: serverTimestamp(),
    }));
    await assertFails(setDoc(transactionRef(db, 'tx-orphan'), linkedTransaction(ownerId, 'payable', 'payable-half')));
  });

  for (const divergence of ['value', 'category', 'account', 'date', 'type', 'origin']) {
    test(`nega divergência de ${divergence}`, async () => {
      const id = `payable-${divergence}`;
      const transactionId = `tx-${divergence}`;
      await seedPending('payable', id);
      const transactionOverrides = {
        value: { amountCents: 999 },
        category: { categoryId: 'income-category' },
        account: { accountId: 'account-2' },
        date: { occurredAt: Timestamp.fromDate(new Date('2026-08-01T03:00:00Z')) },
        type: { kind: 'income' },
        origin: { originId: 'another-payable' },
      }[divergence];
      await assertFails(settle(verifiedDb(), { id, transactionId, transactionOverrides }));
    });
  }

  test('nega confirmação repetida e mantém um único lançamento', async () => {
    await seedPending('payable', 'payable-repeat');
    const db = verifiedDb();
    await assertSucceeds(settle(db, { id: 'payable-repeat', transactionId: 'tx-repeat' }));
    await assertFails(settle(db, { id: 'payable-repeat', transactionId: 'tx-repeat-2' }));
    await assertFails(setDoc(transactionRef(db, 'tx-repeat-3'), linkedTransaction(ownerId, 'payable', 'payable-repeat')));
  });

  test('duas confirmações concorrentes produzem somente um vencedor', async () => {
    await seedPending('payable', 'payable-race');
    const db = verifiedDb();
    const results = await Promise.allSettled([
      settle(db, { id: 'payable-race', transactionId: 'tx-race-a' }),
      settle(db, { id: 'payable-race', transactionId: 'tx-race-b' }),
    ]);
    assert.equal(results.filter((result) => result.status === 'fulfilled').length, 1);
    assert.equal(results.filter((result) => result.status === 'rejected').length, 1);
  });
});

describe('cancelamento, anulação e preservação de histórico', () => {
  test('cancela pendência sem lançamento e bloqueia restauração', async () => {
    await seedPending('payable', 'payable-cancel');
    const db = verifiedDb();
    const ref = commitmentRef(db, 'payable', 'payable-cancel');
    await assertSucceeds(updateDoc(ref, {
      status: 'cancelled',
      cancelledAt: serverTimestamp(),
      revision: 2,
      updatedAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(ref, {
      status: 'pending',
      cancelledAt: null,
      revision: 3,
      updatedAt: serverTimestamp(),
    }));
    await assertFails(deleteDoc(ref));
  });

  test('anula liquidação somente com atualização atômica dos dois documentos', async () => {
    await seedPending('payable', 'payable-void');
    const db = verifiedDb();
    await assertSucceeds(settle(db, { id: 'payable-void', transactionId: 'tx-void' }));
    await assertFails(updateDoc(transactionRef(db, 'tx-void'), {
      isVoided: true,
      voidedAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }));
    await assertSucceeds(voidSettlement(db, { id: 'payable-void', transactionId: 'tx-void' }));
  });

  test('nega edição, cancelamento isolado e restauração do lançamento vinculado', async () => {
    await seedPending('receivable', 'receivable-locked');
    const db = verifiedDb();
    await assertSucceeds(settle(db, { type: 'receivable', id: 'receivable-locked', transactionId: 'tx-locked' }));
    await assertFails(updateDoc(transactionRef(db, 'tx-locked'), {
      description: 'Descrição adulterada',
      updatedAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(transactionRef(db, 'tx-locked'), {
      isVoided: true,
      voidedAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }));
    await assertSucceeds(voidSettlement(db, { type: 'receivable', id: 'receivable-locked', transactionId: 'tx-locked' }));
    await assertFails(updateDoc(transactionRef(db, 'tx-locked'), {
      isVoided: false,
      voidedAt: null,
      updatedAt: serverTimestamp(),
    }));
    await assertFails(deleteDoc(transactionRef(db, 'tx-locked')));
  });
});

describe('compatibilidade e regressões das regras existentes', () => {
  test('mantém lançamento esquema 1 manual legível, editável e anulável imediatamente', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(transactionRef(context.firestore(), 'legacy-1'), legacyTransaction(ownerId));
    });
    const db = verifiedDb();
    await assertSucceeds(getDoc(transactionRef(db, 'legacy-1')));
    await assertSucceeds(updateDoc(transactionRef(db, 'legacy-1'), {
      description: 'Lançamento legado corrigido',
      updatedAt: serverTimestamp(),
    }));
    await assertSucceeds(updateDoc(transactionRef(db, 'legacy-1'), {
      isVoided: true,
      voidedAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }));
    const data = (await getDoc(transactionRef(db, 'legacy-1'))).data();
    assertSameTimestamp(data.voidedAt, data.updatedAt, 'anulação esquema 1 deve compartilhar request.time');
  });

  test('mantém criação e anulação imediata de lançamento manual esquema 2', async () => {
    const db = verifiedDb();
    await assertSucceeds(setDoc(transactionRef(db, 'manual-v2'), manualTransaction(ownerId)));
    await assertSucceeds(updateDoc(transactionRef(db, 'manual-v2'), {
      isVoided: true,
      voidedAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }));
    const data = (await getDoc(transactionRef(db, 'manual-v2'))).data();
    assertSameTimestamp(data.voidedAt, data.updatedAt, 'anulação esquema 2 deve compartilhar request.time');
  });

  test('mantém perfil, contas, categorias e owner protegidos', async () => {
    const db = verifiedDb();
    await assertSucceeds(getDoc(doc(db, `users/${ownerId}`)));
    await assertSucceeds(getDoc(doc(db, `users/${ownerId}/accounts/account-1`)));
    await assertSucceeds(getDoc(doc(db, `users/${ownerId}/categories/expense-category`)));
    await assertSucceeds(getDoc(doc(db, `system_admins/${ownerId}`)));
    await assertSucceeds(updateDoc(doc(db, `users/${ownerId}`), {
      displayName: 'Pessoa Atualizada',
      updatedAt: serverTimestamp(),
    }));
    await assertSucceeds(updateDoc(doc(db, `users/${ownerId}/accounts/account-1`), {
      name: 'Conta atualizada',
      updatedAt: serverTimestamp(),
    }));
    await assertSucceeds(updateDoc(doc(db, `users/${ownerId}/categories/expense-category`), {
      name: 'Casa atualizada',
      updatedAt: serverTimestamp(),
    }));
    await assertFails(setDoc(doc(db, `system_admins/forged-owner`), {
      role: 'owner',
      active: true,
      environment: 'development',
      schemaVersion: 1,
      grantedAt: serverTimestamp(),
    }));
    await assertFails(getDoc(doc(verifiedDb(otherId), `system_admins/${ownerId}`)));
  });
});

describe('regressão de estabilidade temporal', () => {
  test('updatedAt permanece obrigatório sem depender de affectedKeys', () => {
    const functions = [
      'isValidUpdate',
      'isValidAccountUpdate',
      'isValidCategoryUpdate',
      'isValidTransactionDescriptiveUpdate',
      'isValidTransactionVoid',
      'isValidPendingCommitmentEdit',
      'isValidPendingCommitmentCancellation',
      'isValidCommitmentSettlement',
      'isValidCommitmentVoid',
    ];
    for (const name of functions) {
      const source = ruleFunctionSource(name);
      assert.match(source, /data\.updatedAt == request\.time/);
      assert.match(source, /changed\.hasOnly\(\[[^\]]*['"]updatedAt['"]/s);
      assert.doesNotMatch(source, /changed\.hasAll\(\[[^\]]*['"]updatedAt['"]/s);
    }
  });

  test('liquida e anula imediatamente compromisso pago e recebido com timestamps iguais', async () => {
    await seedPending('payable', 'payable-immediate');
    await seedPending('receivable', 'receivable-immediate');
    const db = verifiedDb();
    await assertSucceeds(settle(db, {
      id: 'payable-immediate',
      transactionId: 'tx-payable-immediate',
    }));
    await assertSucceeds(settle(db, {
      type: 'receivable',
      id: 'receivable-immediate',
      transactionId: 'tx-receivable-immediate',
    }));
    await assertSucceeds(voidSettlement(db, {
      id: 'payable-immediate',
      transactionId: 'tx-payable-immediate',
    }));
    await assertSucceeds(voidSettlement(db, {
      type: 'receivable',
      id: 'receivable-immediate',
      transactionId: 'tx-receivable-immediate',
    }));

    for (const [type, id, transactionId] of [
      ['payable', 'payable-immediate', 'tx-payable-immediate'],
      ['receivable', 'receivable-immediate', 'tx-receivable-immediate'],
    ]) {
      const commitmentData = (await getDoc(commitmentRef(db, type, id))).data();
      const transactionData = (await getDoc(transactionRef(db, transactionId))).data();
      assert.equal(commitmentData.status, 'voided');
      assert.equal(transactionData.isVoided, true);
      assertSameTimestamp(
        commitmentData.voidedAt,
        commitmentData.updatedAt,
        `${type}: compromisso deve compartilhar request.time`,
      );
      assertSameTimestamp(
        transactionData.voidedAt,
        transactionData.updatedAt,
        `${type}: lançamento deve compartilhar request.time`,
      );
      assertSameTimestamp(
        commitmentData.updatedAt,
        transactionData.updatedAt,
        `${type}: vínculo atômico deve compartilhar request.time`,
      );
    }
  });

  test('nega revision incorreta na liquidação e na anulação', async () => {
    await seedPending('payable', 'payable-bad-settlement-revision');
    await seedPending('payable', 'payable-bad-void-revision');
    const db = verifiedDb();
    await assertFails(settle(db, {
      id: 'payable-bad-settlement-revision',
      transactionId: 'tx-bad-settlement-revision',
      commitmentOverrides: { revision: 3 },
    }));
    await assertSucceeds(settle(db, {
      id: 'payable-bad-void-revision',
      transactionId: 'tx-bad-void-revision',
    }));
    await assertFails(voidSettlement(db, {
      id: 'payable-bad-void-revision',
      transactionId: 'tx-bad-void-revision',
      commitmentOverrides: { revision: 4 },
    }));
  });

  test('nega updatedAt diferente de request.time', async () => {
    await seedPending('payable', 'payable-stale-updated-at');
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        transactionRef(context.firestore(), 'legacy-stale-updated-at'),
        legacyTransaction(ownerId),
      );
    });
    const db = verifiedDb();
    await assertFails(updateDoc(commitmentRef(db, 'payable', 'payable-stale-updated-at'), {
      status: 'cancelled',
      cancelledAt: serverTimestamp(),
      revision: 2,
      updatedAt: past,
    }));
    await assertFails(updateDoc(transactionRef(db, 'legacy-stale-updated-at'), {
      isVoided: true,
      voidedAt: serverTimestamp(),
      updatedAt: past,
    }));
  });

  test('nega atualização sem alteração semântica', async () => {
    await seedPending('payable', 'payable-no-semantic-change');
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        transactionRef(context.firestore(), 'legacy-no-semantic-change'),
        legacyTransaction(ownerId),
      );
    });
    const db = verifiedDb();
    await assertFails(updateDoc(transactionRef(db, 'legacy-no-semantic-change'), {
      updatedAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(commitmentRef(db, 'payable', 'payable-no-semantic-change'), {
      revision: 2,
      updatedAt: serverTimestamp(),
    }));
  });

  test('nega campos extras e imutáveis nas transições', async () => {
    await seedPending('payable', 'payable-immutable-transition');
    const db = verifiedDb();
    await assertSucceeds(setDoc(
      transactionRef(db, 'manual-immutable-transition'),
      manualTransaction(ownerId),
    ));
    await assertFails(updateDoc(transactionRef(db, 'manual-immutable-transition'), {
      accountId: 'account-2',
      unexpectedField: true,
      isVoided: true,
      voidedAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }));
    await assertFails(settle(db, {
      id: 'payable-immutable-transition',
      transactionId: 'tx-immutable-transition',
      commitmentOverrides: { description: 'Alteração não permitida' },
    }));
  });
});

describe('INV-1A carteiras e ativos de acompanhamento', () => {
  beforeEach(async () => seedPremium());

  test('cria, edita, arquiva e restaura carteira sem permitir exclusão', async () => {
    const db = verifiedDb();
    await assertSucceeds(setDoc(investmentPortfolioRef(db), investmentPortfolio(ownerId, {
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    })));
    await assertSucceeds(updateDoc(investmentPortfolioRef(db), {
      name: 'Longo prazo BR',
      updatedAt: serverTimestamp(),
      revision: 2,
    }));
    await assertSucceeds(updateDoc(investmentPortfolioRef(db), {
      isArchived: true,
      archivedAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
      revision: 3,
    }));
    await assertSucceeds(updateDoc(investmentPortfolioRef(db), {
      isArchived: false,
      archivedAt: null,
      updatedAt: serverTimestamp(),
      revision: 4,
    }));
    await assertFails(deleteDoc(investmentPortfolioRef(db)));
  });

  test('isola UID e nega acesso anônimo ou com e-mail não confirmado', async () => {
    await seedInvestments();
    await assertSucceeds(getDoc(investmentPortfolioRef(verifiedDb())));
    await assertFails(getDoc(investmentPortfolioRef(verifiedDb(otherId))));
    await assertFails(getDoc(investmentPortfolioRef(unverifiedDb())));
    await assertFails(getDoc(investmentPortfolioRef(testEnv.unauthenticatedContext().firestore())));
  });

  test('nega perfil jurídico inválido e owner em acesso cruzado', async () => {
    await seedInvestments();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await updateDoc(doc(db, `users/${ownerId}`), {
        termsVersionAccepted: 'terms-obsoleto',
      });
      await setDoc(doc(db, `users/${otherId}`), profile(otherId));
      await setDoc(doc(db, `system_admins/${otherId}`), {
        role: 'owner',
        status: 'active',
        environment: 'development',
        capabilitiesVersion: 1,
        grantedAt: past,
      });
    });
    await assertFails(getDoc(investmentPortfolioRef(verifiedDb())));
    await assertFails(getDoc(investmentPortfolioRef(verifiedDb(otherId))));
  });

  test('nega revisão incorreta, campo imutável e caminho desconhecido', async () => {
    await seedInvestments();
    const db = verifiedDb();
    await assertFails(updateDoc(investmentPortfolioRef(db), {
      name: 'Revisão forjada',
      updatedAt: serverTimestamp(),
      revision: 99,
    }));
    await assertFails(updateDoc(investmentAssetRef(db), {
      ticker: 'VALE3',
      updatedAt: serverTimestamp(),
      revision: 2,
    }));
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), `users/${ownerId}/investmentUnknown/item-1`),
        { ownerId },
      );
    });
    await assertFails(getDoc(doc(db, `users/${ownerId}/investmentUnknown/item-1`)));
  });

  test('nega campos extras, ticker/id divergente e carteira inexistente', async () => {
    const db = verifiedDb();
    await assertFails(setDoc(investmentPortfolioRef(db), investmentPortfolio(ownerId, {
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
      extra: true,
    })));
    await assertFails(setDoc(investmentAssetRef(db), investmentAsset(ownerId, {
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    })));
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(investmentPortfolioRef(context.firestore()), investmentPortfolio(ownerId));
    });
    await assertFails(setDoc(
      investmentAssetRef(db, 'portfolio-1__VALE3'),
      investmentAsset(ownerId, {
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      }),
    ));
    await assertSucceeds(setDoc(investmentAssetRef(db), investmentAsset(ownerId, {
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    })));
  });
});

describe('INV-1A operações atômicas e projeção protegida', () => {
  beforeEach(async () => seedPremium());

  test('aceita compra válida somente com atualização atômica do ativo', async () => {
    await seedInvestments();
    const db = verifiedDb();
    await assertSucceeds(appendInvestmentOperation(db));
    const asset = (await getDoc(investmentAssetRef(db))).data();
    assert.equal(asset.currentQuantityScaled, 100000000);
    assert.equal(asset.lastOperationId, 'operation-1');
  });

  test('nega operação isolada e atualização isolada da projeção', async () => {
    await seedInvestments();
    const db = verifiedDb();
    await assertFails(setDoc(
      investmentOperationRef(db),
      investmentOperation(ownerId),
    ));
    await assertFails(updateDoc(investmentAssetRef(db), {
      currentQuantityScaled: 100000000,
      lastOperationId: 'operation-1',
      lastOperationAt: movementAt,
      updatedAt: serverTimestamp(),
      revision: 2,
    }));
  });

  test('nega venda acima da posição, quantidade zero e data futura', async () => {
    await seedInvestments();
    const db = verifiedDb();
    await assertFails(appendInvestmentOperation(db, {
      kind: 'sell',
      quantityScaled: 1,
      currentQuantityScaled: -1,
    }));
    await assertFails(appendInvestmentOperation(db, {
      quantityScaled: 0,
      currentQuantityScaled: 0,
    }));
    await assertFails(appendInvestmentOperation(db, {
      occurredAt: Timestamp.fromDate(new Date('2099-01-01T03:00:00Z')),
    }));
  });

  test('nega taxa de venda superior ao valor bruto da operação', async () => {
    await seedInvestments({
      assetOverrides: {
        currentQuantityScaled: 100000000,
        lastOperationId: 'operation-0',
        lastOperationAt: movementAt,
        revision: 2,
      },
      operation: {
        id: 'operation-0',
        data: {
          mutationId: 'operation-0',
          quantityScaled: 100000000,
          createdAt: past,
          updatedAt: past,
        },
      },
    });
    await assertFails(appendInvestmentOperation(verifiedDb(), {
      id: 'operation-fee-over-gross',
      kind: 'sell',
      quantityScaled: 100000000,
      previousOperationId: 'operation-0',
      previousOperationAt: movementAt,
      currentQuantityScaled: 0,
      assetRevision: 3,
      operationOverrides: {
        unitPriceScaled: 1000000,
        feesCents: 101,
      },
    }));
  });

  test('aceita venda parcial e nega cadeia ou cronologia divergente', async () => {
    await seedInvestments({
      assetOverrides: {
        currentQuantityScaled: 200000000,
        lastOperationId: 'operation-0',
        lastOperationAt: movementAt,
        revision: 2,
      },
      operation: {
        id: 'operation-0',
        data: {
          mutationId: 'operation-0',
          quantityScaled: 200000000,
          createdAt: past,
          updatedAt: past,
        },
      },
    });
    const db = verifiedDb();
    const later = Timestamp.fromDate(new Date('2026-08-03T03:00:00Z'));
    await assertSucceeds(appendInvestmentOperation(db, {
      id: 'operation-2',
      kind: 'sell',
      quantityScaled: 50000000,
      occurredAt: later,
      previousOperationId: 'operation-0',
      previousOperationAt: movementAt,
      currentQuantityScaled: 150000000,
      assetRevision: 3,
    }));
    await assertFails(appendInvestmentOperation(db, {
      id: 'operation-bad-chain',
      previousOperationId: 'forged',
      previousOperationAt: later,
      occurredAt: later,
      currentQuantityScaled: 250000000,
      assetRevision: 4,
    }));
    await assertFails(appendInvestmentOperation(db, {
      id: 'operation-old',
      previousOperationId: 'operation-2',
      previousOperationAt: later,
      occurredAt: movementAt,
      currentQuantityScaled: 250000000,
      assetRevision: 4,
    }));
  });

  test('concorrência e repetição têm somente um vencedor', async () => {
    await seedInvestments();
    const db = verifiedDb();
    const outcomes = await Promise.allSettled([
      appendInvestmentOperation(db, { id: 'operation-a' }),
      appendInvestmentOperation(db, { id: 'operation-b' }),
    ]);
    assert.equal(outcomes.filter((value) => value.status === 'fulfilled').length, 1);
    await assertFails(appendInvestmentOperation(db, { id: 'operation-repeat' }));
  });

  test('anula a última operação e restaura atomicamente o topo anterior', async () => {
    await seedInvestments();
    const db = verifiedDb();
    await assertSucceeds(appendInvestmentOperation(db));
    await assertSucceeds(voidInvestmentOperation(db));
    const operation = (await getDoc(investmentOperationRef(db))).data();
    const asset = (await getDoc(investmentAssetRef(db))).data();
    assert.equal(operation.isVoided, true);
    assert.equal(asset.currentQuantityScaled, 0);
    assert.equal(asset.lastOperationId, null);
  });

  test('nega anulação isolada, restauração, edição, exclusão e operação não mais recente', async () => {
    await seedInvestments();
    const db = verifiedDb();
    await assertSucceeds(appendInvestmentOperation(db));
    await assertFails(updateDoc(investmentOperationRef(db), {
      isVoided: true,
      voidedAt: serverTimestamp(),
      mutationId: 'void-isolated',
      updatedAt: serverTimestamp(),
      revision: 2,
    }));
    await assertFails(updateDoc(investmentOperationRef(db), { notes: 'editado' }));
    await assertFails(deleteDoc(investmentOperationRef(db)));
    await assertFails(deleteDoc(investmentAssetRef(db)));
    await assertSucceeds(appendInvestmentOperation(db, {
      id: 'operation-2',
      previousOperationId: 'operation-1',
      previousOperationAt: movementAt,
      currentQuantityScaled: 200000000,
      assetRevision: 3,
    }));
    await assertFails(voidInvestmentOperation(db, { id: 'operation-1' }));
    await assertSucceeds(voidInvestmentOperation(db, {
      id: 'operation-2',
      mutationId: 'void-2',
      currentQuantityScaled: 100000000,
      previousOperationId: 'operation-1',
      previousOperationAt: movementAt,
      assetOverrides: { revision: 4 },
    }));
    await assertFails(updateDoc(investmentOperationRef(db, 'operation-2'), {
      isVoided: false,
      voidedAt: null,
      mutationId: 'restore',
      updatedAt: serverTimestamp(),
      revision: 3,
    }));
  });
});

describe('INV-PROV-1 proventos manuais protegidos', () => {
  beforeEach(async () => seedPremium());

  test('cria provento total e por unidade com referências ativas', async () => {
    await seedInvestments();
    const db = verifiedDb();
    await assertSucceeds(setDoc(
      investmentIncomeRef(db),
      investmentIncome(ownerId),
    ));
    await assertSucceeds(setDoc(
      investmentIncomeRef(db, 'income-unit'),
      investmentIncome(ownerId, {
        inputMode: 'perUnit',
        eligibleQuantityScaled: 1000000000,
        unitAmountScaled: 1250000,
        grossAmountCents: 1250,
        withholdingTaxCents: 0,
        netAmountCents: 1250,
        mutationId: 'income-unit',
      }),
    ));
  });

  test('isola UID e nega anônimo, e-mail não confirmado e owner cruzado', async () => {
    await seedInvestmentIncome();
    await assertSucceeds(getDoc(investmentIncomeRef(verifiedDb())));
    await assertFails(getDoc(investmentIncomeRef(verifiedDb(otherId))));
    await assertFails(getDoc(investmentIncomeRef(unverifiedDb())));
    await assertFails(getDoc(investmentIncomeRef(
      testEnv.unauthenticatedContext().firestore(),
    )));
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), `system_admins/${otherId}`), {
        role: 'owner',
        active: true,
        environment: 'development',
        schemaVersion: 1,
        grantedAt: past,
      });
    });
    await assertFails(getDoc(investmentIncomeRef(verifiedDb(otherId))));
  });

  test('nega perfil jurídico inválido, campos extras, ausentes e owner divergente', async () => {
    await seedInvestments();
    const db = verifiedDb();
    await assertFails(setDoc(
      investmentIncomeRef(db),
      investmentIncome(ownerId, { unexpected: true }),
    ));
    const missing = investmentIncome(ownerId);
    delete missing.netAmountCents;
    await assertFails(setDoc(investmentIncomeRef(db, 'income-missing'), missing));
    await assertFails(setDoc(
      investmentIncomeRef(db, 'income-owner'),
      investmentIncome(otherId, { mutationId: 'income-owner' }),
    ));
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await updateDoc(doc(context.firestore(), `users/${ownerId}`), {
        termsVersionAccepted: 'terms-obsoleto',
      });
    });
    await assertFails(setDoc(
      investmentIncomeRef(db, 'income-legal'),
      investmentIncome(ownerId, { mutationId: 'income-legal' }),
    ));
  });

  test('nega referências inexistentes, carteira arquivada e tipo incompatível', async () => {
    const db = verifiedDb();
    await assertFails(setDoc(
      investmentIncomeRef(db),
      investmentIncome(ownerId),
    ));
    await seedInvestments({ assetOverrides: { assetType: 'stock' } });
    await assertFails(setDoc(
      investmentIncomeRef(db),
      investmentIncome(ownerId, { incomeType: 'fiiIncome' }),
    ));
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await updateDoc(investmentPortfolioRef(context.firestore()), {
        isArchived: true,
        archivedAt: past,
      });
    });
    await assertFails(setDoc(
      investmentIncomeRef(db, 'income-archived'),
      investmentIncome(ownerId, { mutationId: 'income-archived' }),
    ));
  });

  test('edita somente previsão, com revisão e campos financeiros coerentes', async () => {
    await seedInvestmentIncome();
    const db = verifiedDb();
    await assertSucceeds(updateDoc(investmentIncomeRef(db), {
      grossAmountCents: 20000,
      withholdingTaxCents: 3000,
      netAmountCents: 17000,
      notes: 'Revisado manualmente',
      mutationId: 'edit-income-1',
      updatedAt: serverTimestamp(),
      revision: 2,
    }));
    await assertFails(updateDoc(investmentIncomeRef(db), {
      grossAmountCents: 21000,
      netAmountCents: 18000,
      mutationId: 'edit-bad-revision',
      updatedAt: serverTimestamp(),
      revision: 9,
    }));
    await assertFails(updateDoc(investmentIncomeRef(db), {
      portfolioId: 'forged',
      mutationId: 'edit-immutable',
      updatedAt: serverTimestamp(),
      revision: 3,
    }));
  });

  test('confirma recebimento válido e nega data futura ou mutação incompleta', async () => {
    await seedInvestmentIncome();
    const db = verifiedDb();
    await assertFails(receiveInvestmentIncome(db, {
      overrides: {
        receivedDate: Timestamp.fromDate(new Date('2099-01-01T03:00:00Z')),
      },
    }));
    await assertFails(updateDoc(investmentIncomeRef(db), {
      status: 'received',
      receivedDate: movementAt,
      updatedAt: serverTimestamp(),
      revision: 2,
    }));
    await assertSucceeds(receiveInvestmentIncome(db));
    const data = (await getDoc(investmentIncomeRef(db))).data();
    assert.equal(data.status, 'received');
    assert.equal(data.netAmountCents, 8500);
  });

  test('cancelamento preserva histórico e impede restauração', async () => {
    await seedInvestmentIncome();
    const db = verifiedDb();
    await assertSucceeds(cancelInvestmentIncome(db));
    await assertFails(updateDoc(investmentIncomeRef(db), {
      status: 'expected',
      cancelledAt: null,
      mutationId: 'restore-cancelled',
      updatedAt: serverTimestamp(),
      revision: 3,
    }));
    await assertFails(deleteDoc(investmentIncomeRef(db)));
  });

  test('anulação preserva recebimento e impede edição, restauração e exclusão', async () => {
    await seedInvestmentIncome();
    const db = verifiedDb();
    await assertSucceeds(receiveInvestmentIncome(db));
    await assertFails(updateDoc(investmentIncomeRef(db), {
      grossAmountCents: 9999,
      netAmountCents: 8499,
      mutationId: 'edit-received',
      updatedAt: serverTimestamp(),
      revision: 3,
    }));
    await assertSucceeds(voidInvestmentIncome(db));
    const data = (await getDoc(investmentIncomeRef(db))).data();
    assert.equal(data.status, 'voided');
    assert.ok(data.receivedDate.isEqual(movementAt));
    assert.equal(data.grossAmountCents, 10000);
    await assertFails(updateDoc(investmentIncomeRef(db), {
      status: 'received',
      voidedAt: null,
      mutationId: 'restore-voided',
      updatedAt: serverTimestamp(),
      revision: 4,
    }));
    await assertFails(deleteDoc(investmentIncomeRef(db)));
  });

  test('concorrência e repetição permitem somente uma transição', async () => {
    await seedInvestmentIncome();
    const db = verifiedDb();
    const outcomes = await Promise.allSettled([
      receiveInvestmentIncome(db, { mutationId: 'receive-a' }),
      cancelInvestmentIncome(db, { mutationId: 'cancel-b' }),
    ]);
    assert.equal(outcomes.filter((value) => value.status === 'fulfilled').length, 1);
    const current = (await getDoc(investmentIncomeRef(db))).data();
    if (current.status === 'received') {
      await assertFails(receiveInvestmentIncome(db, { mutationId: 'repeat' }));
    } else {
      await assertFails(cancelInvestmentIncome(db, { mutationId: 'repeat' }));
    }
  });

  test('não altera contas, lançamentos nem projeção de posição', async () => {
    await seedInvestmentIncome();
    const db = verifiedDb();
    const accountBefore = (await getDoc(doc(db, `users/${ownerId}/accounts/account-1`))).data();
    const assetBefore = (await getDoc(investmentAssetRef(db))).data();
    await assertSucceeds(receiveInvestmentIncome(db));
    const accountAfter = (await getDoc(doc(db, `users/${ownerId}/accounts/account-1`))).data();
    const assetAfter = (await getDoc(investmentAssetRef(db))).data();
    assert.deepEqual(accountAfter, accountBefore);
    assert.deepEqual(assetAfter, assetBefore);
    assert.equal((await getDoc(transactionRef(db, 'income-1'))).exists(), false);
  });
});

describe('SUB-1B entitlement Premium somente leitura', () => {
  test('usuário verificado com perfil jurídico lê apenas o próprio premium', async () => {
    await seedPremium();
    await assertSucceeds(
      getDoc(doc(verifiedDb(), `users/${ownerId}/entitlements/premium`)),
    );
    await assertFails(
      getDoc(doc(verifiedDb(otherId), `users/${ownerId}/entitlements/premium`)),
    );
  });

  test('nega leitura anônima, e-mail não confirmado e perfil jurídico inválido', async () => {
    await seedPremium();
    const path = `users/${ownerId}/entitlements/premium`;
    await assertFails(getDoc(doc(testEnv.unauthenticatedContext().firestore(), path)));
    await assertFails(getDoc(doc(unverifiedDb(), path)));
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await updateDoc(doc(context.firestore(), `users/${ownerId}`), {
        termsVersionAccepted: 'obsolete-synthetic-version',
      });
    });
    await assertFails(getDoc(doc(verifiedDb(), path)));
  });

  test('owner não recebe acesso cruzado', async () => {
    await seedPremium(otherId);
    await assertFails(
      getDoc(doc(verifiedDb(ownerId), `users/${otherId}/entitlements/premium`)),
    );
  });

  test('nega listagem, criação, atualização e exclusão pelo cliente', async () => {
    await seedPremium();
    const db = verifiedDb();
    const reference = doc(db, `users/${ownerId}/entitlements/premium`);
    await assertFails(getDocs(collection(db, `users/${ownerId}/entitlements`)));
    await assertFails(setDoc(doc(db, `users/${ownerId}/entitlements/other`), premiumEntitlement(ownerId)));
    await assertFails(updateDoc(reference, { status: 'expired' }));
    await assertFails(deleteDoc(reference));
  });

  test('nega entitlement desconhecido e qualquer subcoleção', async () => {
    const db = verifiedDb();
    await assertFails(getDoc(doc(db, `users/${ownerId}/entitlements/other`)));
    await assertFails(getDoc(doc(db, `users/${ownerId}/entitlements/premium/history/event-1`)));
    await assertFails(setDoc(doc(db, `users/${ownerId}/entitlements/premium/history/event-1`), { synthetic: true }));
  });

  test('nega integralmente coleções internas de billing', async () => {
    const collections = [
      '_premiumBillingEvents',
      '_premiumPurchaseBindings',
      '_premiumRtdnInbox',
      '_premiumAcknowledgementOutbox',
      '_premiumAdministrativeGrants',
    ];
    for (const name of collections) {
      const reference = doc(verifiedDb(), `${name}/synthetic-document`);
      await assertFails(getDoc(reference));
      await assertFails(setDoc(reference, { synthetic: true }));
      await assertFails(deleteDoc(reference));
    }
  });

  test('entitlement continua sem escrita pelo cliente', async () => {
    await seedPremium();
    await assertFails(updateDoc(
      doc(verifiedDb(), `users/${ownerId}/entitlements/premium`),
      { status: 'expired' },
    ));
  });

  test('batch cliente não pode criar entitlement e elevar investimento atomicamente', async () => {
    await seedInvestmentIncome();
    const db = verifiedDb();
    const batch = writeBatch(db);
    batch.set(
      doc(db, `users/${ownerId}/entitlements/premium`),
      premiumEntitlement(ownerId),
    );
    batch.update(investmentPortfolioRef(db), {
      name: 'Elevação inválida',
      updatedAt: serverTimestamp(),
      revision: 2,
    });
    await assertFails(batch.commit());
    await assertFails(getDoc(investmentPortfolioRef(db)));
  });
});

describe('SUB-1C enforcement Premium em investimentos', () => {
  async function seedHistory() {
    await seedInvestmentIncome();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        investmentOperationRef(context.firestore()),
        investmentOperation(ownerId, {
          createdAt: past,
          updatedAt: past,
        }),
      );
    });
  }

  async function assertAllInvestmentReadsFail(db) {
    for (const path of [
      'investmentPortfolios',
      'investmentAssets',
      'investmentOperations',
      'investmentIncomeEvents',
    ]) {
      await assertFails(getDocs(collection(db, `users/${ownerId}/${path}`)));
    }
    await assertFails(getDoc(investmentPortfolioRef(db)));
    await assertFails(getDoc(investmentAssetRef(db)));
    await assertFails(getDoc(investmentOperationRef(db)));
    await assertFails(getDoc(investmentIncomeRef(db)));
  }

  async function assertAllInvestmentReadsSucceed(db) {
    for (const path of [
      'investmentPortfolios',
      'investmentAssets',
      'investmentOperations',
      'investmentIncomeEvents',
    ]) {
      await assertSucceeds(getDocs(collection(db, `users/${ownerId}/${path}`)));
    }
  }

  test('ausência de entitlement nega get, list e todas as escritas', async () => {
    await seedHistory();
    const db = verifiedDb();
    await assertAllInvestmentReadsFail(db);
    await assertFails(setDoc(
      investmentPortfolioRef(db, 'portfolio-new'),
      investmentPortfolio(ownerId, {
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      }),
    ));
    await assertFails(updateDoc(investmentPortfolioRef(db), {
      name: 'Bloqueada',
      updatedAt: serverTimestamp(),
      revision: 2,
    }));
    await assertFails(deleteDoc(investmentIncomeRef(db)));
  });

  test('pending nega leitura e escrita sem ser tratado como expiração', async () => {
    await seedHistory();
    await seedPremium(ownerId, {
      status: 'pending',
      startedAt: null,
      currentPeriodStart: null,
      currentPeriodEnd: null,
    });
    const db = verifiedDb();
    await assertAllInvestmentReadsFail(db);
    await assertFails(updateDoc(investmentPortfolioRef(db), {
      name: 'Pendente',
      updatedAt: serverTimestamp(),
      revision: 2,
    }));
  });

  test('trial, active, grace e cancelled vigente mantêm acesso integral', async () => {
    const cases = [
      { status: 'trialing' },
      { status: 'active' },
      {
        status: 'gracePeriod',
        graceUntil: Timestamp.fromDate(new Date('2026-10-01T00:00:00Z')),
      },
      {
        status: 'cancelled',
        cancelAtPeriodEnd: true,
        cancelledAt: past,
      },
    ];
    for (let index = 0; index < cases.length; index += 1) {
      await testEnv.clearFirestore();
      await seedBase();
      await seedPremium(ownerId, cases[index]);
      const db = verifiedDb();
      await assertSucceeds(setDoc(
        investmentPortfolioRef(db, `portfolio-full-${index}`),
        investmentPortfolio(ownerId, {
          createdAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        }),
      ));
    }
  });

  test('estados de perda preservam leitura histórica e negam mutações', async () => {
    const endedAt = Timestamp.fromDate(new Date('2026-08-05T00:00:00Z'));
    const verifiedAt = Timestamp.fromDate(new Date('2026-08-06T00:00:00Z'));
    const cases = [
      {
        status: 'expired',
        currentPeriodEnd: endedAt,
        expiredAt: endedAt,
        lastVerifiedAt: verifiedAt,
        updatedAt: verifiedAt,
      },
      { status: 'accountHold' },
      { status: 'paused' },
      { status: 'revoked', revokedAt: past },
      { status: 'refunded', refundedAt: past },
      {
        status: 'cancelled',
        currentPeriodEnd: endedAt,
        cancelAtPeriodEnd: true,
        cancelledAt: past,
      },
    ];
    for (const value of cases) {
      await testEnv.clearFirestore();
      await seedBase();
      await seedHistory();
      await seedPremium(ownerId, value);
      const db = verifiedDb();
      await assertAllInvestmentReadsSucceed(db);
      await assertFails(updateDoc(investmentPortfolioRef(db), {
        name: 'Não deve alterar',
        updatedAt: serverTimestamp(),
        revision: 2,
      }));
      await assertFails(receiveInvestmentIncome(db));
    }
  });

  test('capability manual não concede proventos', async () => {
    await seedHistory();
    await seedPremium(ownerId, { capabilities: ['investmentsManual'] });
    const db = verifiedDb();
    await assertSucceeds(getDoc(investmentPortfolioRef(db)));
    await assertFails(getDoc(investmentIncomeRef(db)));
    await assertSucceeds(updateDoc(investmentPortfolioRef(db), {
      name: 'Manual permitido',
      updatedAt: serverTimestamp(),
      revision: 2,
    }));
    await assertFails(receiveInvestmentIncome(db));
  });

  test('capability de proventos não concede carteiras, ativos ou operações', async () => {
    await seedHistory();
    await seedPremium(ownerId, { capabilities: ['investmentIncome'] });
    const db = verifiedDb();
    await assertSucceeds(getDoc(investmentIncomeRef(db)));
    await assertFails(getDoc(investmentPortfolioRef(db)));
    await assertFails(getDoc(investmentAssetRef(db)));
    await assertFails(getDoc(investmentOperationRef(db)));
    await assertSucceeds(receiveInvestmentIncome(db));
    await assertFails(updateDoc(investmentPortfolioRef(db), {
      name: 'Sem manual',
      updatedAt: serverTimestamp(),
      revision: 2,
    }));
  });

  test('capability inválida ou duplicada falha fechado', async () => {
    await seedHistory();
    const cases = [
      ['investmentsManual', 'unknownSyntheticCapability'],
      ['investmentsManual', 'investmentsManual'],
    ];
    for (const capabilities of cases) {
      await seedPremium(ownerId, { capabilities });
      await assertAllInvestmentReadsFail(verifiedDb());
    }
  });

  test('schema, revisão, owner, ambiente e timestamps inválidos negam', async () => {
    await seedHistory();
    const cases = [
      { schemaVersion: 99 },
      { revision: 0 },
      { ownerId: otherId },
      { environment: 'production' },
      { planId: 'unsupported-plan' },
      { source: 'unknown-source' },
      { currentPeriodStart: Timestamp.fromDate(new Date('2027-01-01T00:00:00Z')) },
    ];
    for (const value of cases) {
      await seedPremium(ownerId, value);
      await assertAllInvestmentReadsFail(verifiedDb());
      await assertFails(updateDoc(investmentPortfolioRef(verifiedDb()), {
        name: 'Documento inválido',
        updatedAt: serverTimestamp(),
        revision: 2,
      }));
    }
  });

  test('fronteira temporal usa request.time e o vencimento já é somente leitura', async () => {
    await seedHistory();
    const now = Timestamp.now();
    await seedPremium(ownerId, {
      status: 'cancelled',
      currentPeriodEnd: now,
      cancelAtPeriodEnd: true,
      cancelledAt: past,
      lastVerifiedAt: now,
      updatedAt: now,
    });
    const db = verifiedDb();
    await assertAllInvestmentReadsSucceed(db);
    await assertFails(updateDoc(investmentPortfolioRef(db), {
      name: 'Exatamente no limite',
      updatedAt: serverTimestamp(),
      revision: 2,
    }));
  });

  test('antes do vencimento permite e depois nega mutação sem apagar dados', async () => {
    await seedHistory();
    const future = Timestamp.fromMillis(Date.now() + 60_000);
    await seedPremium(ownerId, {
      status: 'cancelled',
      currentPeriodEnd: future,
      cancelAtPeriodEnd: true,
      cancelledAt: past,
    });
    const db = verifiedDb();
    await assertSucceeds(updateDoc(investmentPortfolioRef(db), {
      name: 'Antes do vencimento',
      updatedAt: serverTimestamp(),
      revision: 2,
    }));
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await updateDoc(
        doc(context.firestore(), `users/${ownerId}/entitlements/premium`),
        { currentPeriodEnd: Timestamp.fromMillis(Date.now() - 1_000) },
      );
    });
    await assertSucceeds(getDoc(investmentPortfolioRef(db)));
    await assertFails(updateDoc(investmentPortfolioRef(db), {
      name: 'Depois do vencimento',
      updatedAt: serverTimestamp(),
      revision: 3,
    }));
  });

  test('delete e caminhos desconhecidos continuam sempre negados', async () => {
    await seedHistory();
    await seedPremium();
    const db = verifiedDb();
    await assertFails(deleteDoc(investmentPortfolioRef(db)));
    await assertFails(deleteDoc(investmentAssetRef(db)));
    await assertFails(deleteDoc(investmentOperationRef(db)));
    await assertFails(deleteDoc(investmentIncomeRef(db)));
    await assertFails(getDoc(doc(
      db,
      `users/${ownerId}/investmentPortfolios/portfolio-1/private/item-1`,
    )));
  });
});

describe('SUB-1F-1 diretório interno do teste fechado', () => {
  test('nega leitura, listagem e escrita do diretório e das concessões para qualquer UID', async () => {
    const db = verifiedDb();
    const testerRef = doc(db, '_premiumClosedTestTesters/synthetic-tester');
    const grantRef = doc(db, '_premiumClosedTestGrants/synthetic-grant');
    await assertFails(getDoc(testerRef));
    await assertFails(getDocs(collection(db, '_premiumClosedTestTesters')));
    await assertFails(setDoc(testerRef, {
      environment: 'development', track: 'closed', status: 'active', schemaVersion: 1,
      authorizedAt: serverTimestamp(), revision: 1,
    }));
    await assertFails(getDoc(grantRef));
    await assertFails(getDocs(collection(db, '_premiumClosedTestGrants')));
    await assertFails(setDoc(grantRef, { status: 'active' }));
    await assertFails(getDoc(doc(verifiedDb(otherId), '_premiumClosedTestTesters/synthetic-tester')));
  });
});

describe('INV-2C snapshots globais de cotações atrasadas', () => {
  test('Premium vigente com capability lê somente snapshot conhecido por ticker', async () => {
    await seedMarketQuote();
    await seedPremium(ownerId, { capabilities: ['investmentQuotes'] });
    const db = verifiedDb();
    await assertSucceeds(getDoc(doc(db, 'marketQuoteSnapshots/PETR4')));
    await assertFails(getDocs(collection(db, 'marketQuoteSnapshots')));
    // Um get de ID inexistente é uma leitura vazia, não uma enumeração. A
    // aplicação só solicita tickers vindos dos próprios ativos confirmados.
    await assertSucceeds(getDoc(doc(db, 'marketQuoteSnapshots/HGLG11')));
  });

  test('nega anônimo, e-mail não confirmado, perfil inválido, capability ausente e Premium expirado', async () => {
    await seedMarketQuote();
    const reference = doc(verifiedDb(), 'marketQuoteSnapshots/PETR4');
    await assertFails(getDoc(reference));
    await seedPremium(ownerId, { capabilities: ['investmentQuotes'] });
    await assertFails(getDoc(doc(testEnv.unauthenticatedContext().firestore(), 'marketQuoteSnapshots/PETR4')));
    await assertFails(getDoc(doc(unverifiedDb(), 'marketQuoteSnapshots/PETR4')));
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await updateDoc(doc(context.firestore(), `users/${ownerId}`), { termsVersionAccepted: 'invalid' });
    });
    await assertFails(getDoc(doc(verifiedDb(), 'marketQuoteSnapshots/PETR4')));
    await testEnv.clearFirestore();
    await seedBase();
    await seedMarketQuote();
    await seedPremium(ownerId, {
      capabilities: ['investmentQuotes'],
      status: 'expired',
      currentPeriodEnd: Timestamp.fromDate(new Date('2026-08-01T00:00:00Z')),
      expiredAt: Timestamp.fromDate(new Date('2026-08-01T00:00:00Z')),
      lastVerifiedAt: past,
      updatedAt: past,
    });
    await assertFails(getDoc(doc(verifiedDb(), 'marketQuoteSnapshots/PETR4')));
  });

  test('cliente e owner não escrevem snapshots, leases, requests ou circuit breakers', async () => {
    await seedMarketQuote();
    await seedPremium(ownerId, { capabilities: ['investmentQuotes'] });
    const db = verifiedDb();
    await assertFails(setDoc(doc(db, 'marketQuoteSnapshots/PETR4'), marketQuoteSnapshot()));
    await assertFails(deleteDoc(doc(db, 'marketQuoteSnapshots/PETR4')));
    for (const path of [
      '_marketQuoteLeases/PETR4',
      '_marketQuoteRefreshRequests/synthetic-request',
      '_marketQuoteCircuitBreakers/PETR4',
    ]) {
      await assertFails(getDoc(doc(db, path)));
      await assertFails(setDoc(doc(db, path), { synthetic: true }));
    }
  });
});

describe('PRIV-1C/PRIV-1D locks privados', () => {
  test('cliente não lê/escreve operação, lock ou recibo e reset bloqueia mutação financeira', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), `users/${ownerId}/privacyLocks/current`), {
        scope: 'financialReset', ownerId, createdAt: past, schemaVersion: 1,
      });
    });
    const db = verifiedDb();
    await assertFails(getDoc(doc(db, `users/${ownerId}/privacyLocks/current`)));
    await assertFails(getDoc(doc(db, `users/${ownerId}/privacyOperations/operation-1`)));
    await assertFails(setDoc(doc(db, `users/${ownerId}/privacyReceipts/receipt-1`), { status: 'completed' }));
    await assertFails(setDoc(transactionRef(db, 'locked-financial-write'), manualTransaction(ownerId)));
    await assertFails(setDoc(doc(verifiedDb(otherId), `users/${ownerId}/privacyLocks/current`), { scope: 'accountDeletion' }));
  });

  test('lock de exclusão bloqueia atualização do perfil e delete direto segue negado sem bypass owner', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), `users/${ownerId}/privacyLocks/current`), {
        scope: 'accountDeletion', ownerId, createdAt: past, schemaVersion: 1,
      });
    });
    const db = verifiedDb();
    await assertFails(updateDoc(doc(db, `users/${ownerId}`), { displayName: 'Pessoa Alterada', updatedAt: serverTimestamp() }));
    await assertFails(deleteDoc(doc(db, `users/${ownerId}/accounts/account-1`)));
  });
});
