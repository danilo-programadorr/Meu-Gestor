/**
 * Intenção: demonstra que a montagem runtime depende do token já verificado do
 * próprio usuário, sem papel IAM no banco padrão nem vazamento para o contexto.
 */
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

import {
  OwnerScopedFirestoreContextReader,
  OwnerScopedFirestoreRestTransport,
  OwnerScopedFirestoreSourceReaders,
  createOwnerScopedFirestoreAuthority,
} from '../src/owner_scoped_firestore_context.mjs';

const projectId = 'demo-assistant-controls';
const ownerUid = 'synthetic-owner';
const otherUid = 'synthetic-other';
const ownerAuthority = Object.freeze({
  uid: ownerUid,
  authorizationHeader: 'Bearer synthetic.runtime.owner.token.without.pii',
});
const period = Object.freeze({
  timeZone: 'America/Sao_Paulo',
  startDate: '2026-09-01',
  endDateExclusive: '2026-10-01',
});

const string = (value) => ({ stringValue: value });
const integer = (value) => ({ integerValue: String(value) });
const boolean = (value) => ({ booleanValue: value });
const timestamp = (value) => ({ timestampValue: value });
const nullValue = () => ({ nullValue: null });

const document = (collection, id, fields, uid = ownerUid) => Object.freeze({
  name: `projects/${projectId}/databases/(default)/documents/users/${uid}/${collection}/${id}`,
  fields: Object.freeze({ ownerId: string(uid), ...fields }),
});

const documents = Object.freeze({
  accounts: Object.freeze([
    document('accounts', 'account_1', {
      openingBalanceCents: integer(125000), currencyCode: string('BRL'),
      includeInTotal: boolean(true), isArchived: boolean(false),
    }),
  ]),
  transactions: Object.freeze([
    document('transactions', 'transaction_1', {
      kind: string('income'), amountCents: integer(90000),
      occurredAt: timestamp('2026-09-10T03:00:00.000Z'), isVoided: boolean(false),
    }),
    document('transactions', 'transaction_2', {
      kind: string('expense'), amountCents: integer(12000),
      occurredAt: timestamp('2026-09-11T03:00:00.000Z'), isVoided: boolean(false),
    }),
  ]),
  payables: Object.freeze([
    document('payables', 'payable_1', {
      status: string('pending'), amountCents: integer(5000),
      dueAt: timestamp('2026-09-12T03:00:00.000Z'),
    }),
  ]),
  receivables: Object.freeze([
    document('receivables', 'receivable_1', {
      status: string('pending'), amountCents: integer(7500),
      dueAt: timestamp('2026-09-13T03:00:00.000Z'),
    }),
  ]),
  investmentPortfolios: Object.freeze([
    document('investmentPortfolios', 'portfolio_1', { isArchived: boolean(false) }),
  ]),
  investmentAssets: Object.freeze([
    document('investmentAssets', 'asset_1', {
      currencyCode: string('BRL'), assetType: string('stock'),
      currentQuantityScaled: integer(250000000),
    }),
  ]),
  investmentOperations: Object.freeze([
    document('investmentOperations', 'operation_1', {
      kind: string('buy'), isVoided: boolean(false),
      occurredAt: timestamp('2026-09-14T03:00:00.000Z'),
    }),
  ]),
  investmentIncomeEvents: Object.freeze([
    document('investmentIncomeEvents', 'income_1', {
      status: string('received'), netAmountCents: integer(550),
      receivedDate: timestamp('2026-09-15T03:00:00.000Z'),
    }),
  ]),
});

const authorization = (overrides = {}) => ({
  authenticated: true,
  uid: ownerUid,
  requestedOwnerId: ownerUid,
  appCheckVerified: true,
  emailVerified: true,
  legalProfileVerified: true,
  aiConsentEnabled: true,
  profileFromServer: true,
  profileHasPendingWrites: false,
  acceptedPolicyVersion: 'assist-context-v1',
  aiConsentUpdatedAt: '2026-09-01T03:00:00.000Z',
  financialPrivacyActive: false,
  ...overrides,
});

const createTransport = ({ data = documents, failCollection, foreignDocument } = {}) => {
  const calls = [];
  const transport = new OwnerScopedFirestoreRestTransport({
    projectIdReader: () => projectId,
    fetchImpl: async (url, options) => {
      calls.push({ url, options });
      const match = /\/documents\/users\/([^/]+)\/([^?]+)/u.exec(url);
      const [, encodedUid, collection] = match ?? [];
      if (encodedUid !== encodeURIComponent(ownerUid) || failCollection === collection) {
        return { ok: false, json: async () => ({}) };
      }
      return {
        ok: true,
        json: async () => ({
          documents: foreignDocument === collection
            ? [document(collection, 'foreign_1', data[collection][0].fields, otherUid)]
            : data[collection],
        }),
      };
    },
  });
  return { transport, calls };
};

const createReader = (options = {}) => {
  const { transport, calls } = createTransport(options);
  return {
    calls,
    reader: new OwnerScopedFirestoreContextReader({
      transport,
      clock: { now: () => new Date('2026-10-01T03:00:00.000Z') },
    }),
  };
};

test('monta somente fatos confirmados do proprietário e não expõe token ou UID', async () => {
  const { reader, calls } = createReader();

  const context = await reader.readAuthorizedOwnConfirmedContext({
    authorization: authorization(), authority: ownerAuthority, period,
  });

  assert.equal(calls.length, 8);
  for (const call of calls) {
    assert.match(call.url, new RegExp(`/users/${ownerUid}/`));
    assert.match(call.url, /mask\.fieldPaths=ownerId/u);
    assert.doesNotMatch(call.url, /description|note|name|email|uid/u);
    assert.equal(call.options.method, 'GET');
    assert.equal(call.options.headers.Authorization, ownerAuthority.authorizationHeader);
  }
  assert.equal(context.civilPeriod.timeZone, 'America/Sao_Paulo');
  assert.deepEqual(context.facts.map((item) => item.source), [
    'accounts', 'accounts', 'transactions', 'transactions', 'payables',
    'receivables', 'financialCalendar', 'financialCalendar',
    'investmentPortfolios', 'investmentAssets', 'investmentOperations',
    'investmentIncome',
  ]);
  assert.equal(context.facts.find((item) => item.source === 'accounts' && item.kind === 'moneyCentsBrl').value, 125000);
  assert.doesNotMatch(JSON.stringify(context), /synthetic-owner|synthetic\.runtime|uid|email|token|secret/i);
});

test('recusa UID cruzado antes de ler qualquer coleção', async () => {
  const { transport, calls } = createTransport();
  const readers = new OwnerScopedFirestoreSourceReaders({ authority: ownerAuthority, transport });

  await assert.rejects(
    readers.readOwnSource({
      ownerUid: otherUid,
      reader: 'accounts',
      period,
      technicalWindow: {
        start: '2026-09-01T03:00:00.000Z', endExclusive: '2026-10-01T03:00:00.000Z',
      },
    }),
    /assistant_invalid_context/,
  );
  assert.equal(calls.length, 0);
});

test('recusa ausência de autorização, privacidade e fonte indisponível sem contexto parcial', async () => {
  const { reader } = createReader({ failCollection: 'investmentIncomeEvents' });

  await assert.rejects(
    reader.readAuthorizedOwnConfirmedContext({
      authorization: authorization(),
      authority: { uid: ownerUid, authorizationHeader: 'Bearer short' },
      period,
    }),
    /assistant_unauthenticated/,
  );
  await assert.rejects(
    reader.readAuthorizedOwnConfirmedContext({
      authorization: authorization({ financialPrivacyActive: true }),
      authority: ownerAuthority,
      period,
    }),
    /assistant_financial_privacy_active/,
  );
  await assert.rejects(
    reader.readAuthorizedOwnConfirmedContext({
      authorization: authorization(), authority: ownerAuthority, period,
    }),
    /assistant_invalid_context/,
  );
});

test('recusa documento de outro proprietário e dado financeiro inválido', async () => {
  const foreign = createReader({ foreignDocument: 'accounts' });
  await assert.rejects(
    foreign.reader.readAuthorizedOwnConfirmedContext({
      authorization: authorization(), authority: ownerAuthority, period,
    }),
    /assistant_invalid_context/,
  );

  const invalidData = structuredClone(documents);
  invalidData.transactions[0] = document('transactions', 'transaction_invalid', {
    kind: string('income'), amountCents: { doubleValue: 90 },
    occurredAt: timestamp('2026-09-10T03:00:00.000Z'), isVoided: boolean(false),
  });
  const invalid = createReader({ data: invalidData });
  await assert.rejects(
    invalid.reader.readAuthorizedOwnConfirmedContext({
      authorization: authorization(), authority: ownerAuthority, period,
    }),
    /assistant_invalid_context/,
  );
});

test('a camada não importa Admin nem concede acesso IAM ao banco padrão', async () => {
  const source = await readFile(new URL('../src/owner_scoped_firestore_context.mjs', import.meta.url), 'utf8');
  assert.doesNotMatch(source, /firebase-admin|getFirestore\(|datastore\.user|serviceAccount/iu);
  assert.match(source, /firestore\.googleapis\.com\/v1\/projects/iu);
  assert.match(source, /method: 'GET'/u);
  assert.match(source, /mask\.fieldPaths/u);
  assert.doesNotMatch(source, /method:\s*'(?:POST|PUT|PATCH|DELETE)'/u);
  assert.deepEqual(
    createOwnerScopedFirestoreAuthority(ownerAuthority),
    ownerAuthority,
  );
});
