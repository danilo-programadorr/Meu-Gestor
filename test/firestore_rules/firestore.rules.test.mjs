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
