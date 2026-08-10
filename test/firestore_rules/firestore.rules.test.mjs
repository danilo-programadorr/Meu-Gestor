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
  deleteDoc,
  doc,
  getDoc,
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

function investmentPortfolioRef(db, id = 'portfolio-1', uid = ownerId) {
  return doc(db, `users/${uid}/investmentPortfolios/${id}`);
}

function investmentAssetRef(db, id = 'portfolio-1__PETR4', uid = ownerId) {
  return doc(db, `users/${uid}/investmentAssets/${id}`);
}

function investmentOperationRef(db, id = 'operation-1', uid = ownerId) {
  return doc(db, `users/${uid}/investmentOperations/${id}`);
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
