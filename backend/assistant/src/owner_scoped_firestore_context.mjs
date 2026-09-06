/**
 * Responsabilidade: lê somente coleções do proprietário usando o token Firebase
 * já validado pela callable; não usa Admin SDK, IAM do banco padrão ou escrita.
 */
import { deny } from './errors.mjs';
import {
  DEFAULT_ASSISTANT_CONTEXT_SCOPE,
  admitOwnFinancialContext,
} from './context_admission.mjs';
import { AssistantFinancialContextBridge } from './financial_context_bridge.mjs';
import { assertAuthorized } from './policy.mjs';
import { ASSISTANT_CIVIL_TIME_ZONE, validateCivilPeriod } from './sao_paulo_civil_time.mjs';

export const ASSISTANT_OWNER_SCOPED_CONTEXT_VERSION = 'assist-owner-scoped-context-v1';

const DEFAULT_PAGE_SIZE = 100;
const ownerCollections = Object.freeze([
  'accounts',
  'transactions',
  'payables',
  'receivables',
  'investmentPortfolios',
  'investmentAssets',
  'investmentOperations',
  'investmentIncomeEvents',
]);

// Responsabilidade: limita a resposta do Firestore aos campos mínimos que podem
// originar fatos efêmeros; descrições, notas e identificadores internos não saem da fonte.
const collectionFieldMasks = Object.freeze({
  accounts: Object.freeze(['ownerId', 'isArchived', 'includeInTotal', 'currencyCode', 'openingBalanceCents']),
  transactions: Object.freeze(['ownerId', 'kind', 'isVoided', 'occurredAt', 'amountCents']),
  payables: Object.freeze(['ownerId', 'status', 'dueAt', 'amountCents']),
  receivables: Object.freeze(['ownerId', 'status', 'dueAt', 'amountCents']),
  investmentPortfolios: Object.freeze(['ownerId', 'isArchived']),
  investmentAssets: Object.freeze(['ownerId', 'currencyCode', 'assetType', 'currentQuantityScaled']),
  investmentOperations: Object.freeze(['ownerId', 'kind', 'isVoided', 'occurredAt']),
  investmentIncomeEvents: Object.freeze(['ownerId', 'status', 'receivedDate', 'netAmountCents']),
});

const isExactObject = (value, keys) => value !== null
  && typeof value === 'object'
  && !Array.isArray(value)
  && Object.keys(value).sort().join('|') === [...keys].sort().join('|');

const invalidContext = () => deny('assistant_invalid_context');

const assertOwnerUid = (uid) => {
  if (typeof uid !== 'string' || uid.trim() !== uid || uid.length < 1 || uid.length > 128 || /[\\/]/u.test(uid)) {
    throw deny('assistant_unauthenticated');
  }
};

const assertProjectId = (projectId) => {
  if (typeof projectId !== 'string' || !/^[a-z][a-z0-9-]{4,62}$/u.test(projectId)) {
    throw invalidContext();
  }
};

const assertAuthorizationHeader = (header) => {
  if (typeof header !== 'string' || !/^Bearer [A-Za-z0-9._-]{20,4096}$/u.test(header)) {
    throw deny('assistant_unauthenticated');
  }
};

const asInteger = (fields, name) => {
  const value = fields?.[name]?.integerValue;
  if (typeof value !== 'string' || !/^-?\d+$/u.test(value)) throw invalidContext();
  const parsed = Number(value);
  if (!Number.isSafeInteger(parsed)) throw invalidContext();
  return parsed;
};

const asString = (fields, name) => {
  const value = fields?.[name]?.stringValue;
  if (typeof value !== 'string') throw invalidContext();
  return value;
};

const asBoolean = (fields, name) => {
  const value = fields?.[name]?.booleanValue;
  if (typeof value !== 'boolean') throw invalidContext();
  return value;
};

const asTimestamp = (fields, name, { nullable = false } = {}) => {
  const field = fields?.[name];
  if (nullable && field?.nullValue === null) return null;
  const value = field?.timestampValue;
  if (typeof value !== 'string' || !value.endsWith('Z') || Number.isNaN(Date.parse(value))) {
    throw invalidContext();
  }
  return new Date(value).toISOString();
};

const assertDocument = ({ document, projectId, ownerUid, collection }) => {
  if (!document || typeof document !== 'object' || Array.isArray(document)
      || typeof document.name !== 'string' || !document.fields || typeof document.fields !== 'object') {
    throw invalidContext();
  }
  const prefix = `projects/${projectId}/databases/(default)/documents/users/${ownerUid}/${collection}/`;
  if (!document.name.startsWith(prefix) || document.name.slice(prefix.length).includes('/')) {
    throw invalidContext();
  }
  if (asString(document.fields, 'ownerId') !== ownerUid) throw invalidContext();
  return document.fields;
};

const isInsideWindow = (timestamp, technicalWindow) => {
  const instant = Date.parse(timestamp);
  return instant >= Date.parse(technicalWindow.start) && instant < Date.parse(technicalWindow.endExclusive);
};

const sum = (values) => values.reduce((total, value) => {
  const next = total + value;
  if (!Number.isSafeInteger(next)) throw invalidContext();
  return next;
}, 0);

const fact = (source, kind, value) => Object.freeze({ source, kind, value });

/**
 * Responsabilidade: representa a identidade temporária que o perímetro da
 * callable já verificou. Ela só atravessa a fronteira HTTP para Firestore.
 */
export const createOwnerScopedFirestoreAuthority = ({ uid, authorizationHeader }) => {
  assertOwnerUid(uid);
  assertAuthorizationHeader(authorizationHeader);
  return Object.freeze({ uid, authorizationHeader });
};

/**
 * Responsabilidade: chama exclusivamente o endpoint de leitura Firestore da
 * coleção do próprio UID, com GET, token delegado e limite que evita contexto parcial.
 */
export class OwnerScopedFirestoreRestTransport {
  constructor({ projectIdReader, fetchImpl = globalThis.fetch, pageSize = DEFAULT_PAGE_SIZE }) {
    if (typeof projectIdReader !== 'function' || typeof fetchImpl !== 'function'
        || !Number.isInteger(pageSize) || pageSize < 1 || pageSize > DEFAULT_PAGE_SIZE) {
      throw new TypeError('assistant_owner_scoped_transport_dependencies_invalid');
    }
    this.projectIdReader = projectIdReader;
    this.fetchImpl = fetchImpl;
    this.pageSize = pageSize;
  }

  async listOwnCollection({ authority, collection }) {
    if (!ownerCollections.includes(collection)) throw invalidContext();
    const { uid, authorizationHeader } = authority ?? {};
    assertOwnerUid(uid);
    assertAuthorizationHeader(authorizationHeader);
    const projectId = this.projectIdReader();
    assertProjectId(projectId);
    const path = `users/${encodeURIComponent(uid)}/${collection}`;
    const query = new URLSearchParams({ pageSize: String(this.pageSize) });
    for (const fieldPath of collectionFieldMasks[collection]) {
      query.append('mask.fieldPaths', fieldPath);
    }
    const url = `https://firestore.googleapis.com/v1/projects/${encodeURIComponent(projectId)}/databases/(default)/documents/${path}?${query.toString()}`;
    const response = await this.fetchImpl(url, Object.freeze({
      method: 'GET',
      headers: Object.freeze({ Authorization: authorizationHeader }),
    }));
    if (!response || response.ok !== true || typeof response.json !== 'function') throw invalidContext();
    const body = await response.json();
    if (!body || typeof body !== 'object' || Array.isArray(body)
        || (body.nextPageToken !== undefined && body.nextPageToken !== '')
        || (body.documents !== undefined && !Array.isArray(body.documents))) {
      throw invalidContext();
    }
    return Object.freeze((body.documents ?? []).map((document) => Object.freeze({
      fields: assertDocument({ document, projectId, ownerUid: uid, collection }),
    })));
  }
}

const confirmedAccounts = (documents) => {
  const active = documents.filter(({ fields }) => !asBoolean(fields, 'isArchived') && asBoolean(fields, 'includeInTotal'));
  for (const { fields } of documents) {
    if (asString(fields, 'currencyCode') !== 'BRL') throw invalidContext();
  }
  return Object.freeze({
    confirmed: true,
    facts: Object.freeze([
      fact('accounts', 'integer', active.length),
      fact('accounts', 'moneyCentsBrl', sum(active.map(({ fields }) => asInteger(fields, 'openingBalanceCents')))),
    ]),
  });
};

const confirmedTransactions = (documents, technicalWindow) => {
  const confirmed = documents.filter(({ fields }) => {
    const kind = asString(fields, 'kind');
    if (!['income', 'expense'].includes(kind)) throw invalidContext();
    return !asBoolean(fields, 'isVoided') && isInsideWindow(asTimestamp(fields, 'occurredAt'), technicalWindow);
  });
  return Object.freeze({
    confirmed: true,
    facts: Object.freeze([
      fact('transactions', 'moneyCentsBrl', sum(confirmed.filter(({ fields }) => asString(fields, 'kind') === 'income').map(({ fields }) => asInteger(fields, 'amountCents')))),
      fact('transactions', 'moneyCentsBrl', -sum(confirmed.filter(({ fields }) => asString(fields, 'kind') === 'expense').map(({ fields }) => asInteger(fields, 'amountCents')))),
    ]),
  });
};

const commitmentFacts = ({ payables, receivables, technicalWindow }) => {
  const read = (documents, expectedStatus, source) => documents.filter(({ fields }) => {
    if (!['pending', expectedStatus, 'cancelled', 'voided'].includes(asString(fields, 'status'))) throw invalidContext();
    return asString(fields, 'status') === 'pending' && isInsideWindow(asTimestamp(fields, 'dueAt'), technicalWindow);
  }).map(({ fields }) => ({ source, amount: asInteger(fields, 'amountCents'), dueAt: asTimestamp(fields, 'dueAt') }));
  return Object.freeze([...read(payables, 'paid', 'payables'), ...read(receivables, 'received', 'receivables')]);
};

const confirmedCommitments = (commitments) => Object.freeze({
  confirmed: true,
  facts: Object.freeze([
    fact('payables', 'moneyCentsBrl', sum(commitments.filter(({ source }) => source === 'payables').map(({ amount }) => amount))),
    fact('receivables', 'moneyCentsBrl', sum(commitments.filter(({ source }) => source === 'receivables').map(({ amount }) => amount))),
  ]),
});

const confirmedCalendar = (commitments) => Object.freeze({
  confirmed: true,
  facts: Object.freeze([
    fact('financialCalendar', 'integer', commitments.length),
    ...(commitments.length === 0
      ? []
      : [
          fact(
            'financialCalendar',
            'utcInstant',
            commitments.map(({ dueAt }) => dueAt).sort()[0],
          ),
        ]),
  ]),
});

const confirmedInvestments = ({ portfolios, assets, operations, technicalWindow }) => {
  const activePortfolios = portfolios.filter(({ fields }) => !asBoolean(fields, 'isArchived'));
  const activeAssets = assets.filter(({ fields }) => {
    if (asString(fields, 'currencyCode') !== 'BRL' || !['stock', 'fii'].includes(asString(fields, 'assetType'))) throw invalidContext();
    return asInteger(fields, 'currentQuantityScaled') >= 0;
  });
  const activeOperations = operations.filter(({ fields }) => {
    if (!['buy', 'sell'].includes(asString(fields, 'kind'))) throw invalidContext();
    return !asBoolean(fields, 'isVoided') && isInsideWindow(asTimestamp(fields, 'occurredAt'), technicalWindow);
  });
  return Object.freeze({
    confirmed: true,
    facts: Object.freeze([
      fact('investmentPortfolios', 'integer', activePortfolios.length),
      fact('investmentAssets', 'integer', activeAssets.length),
      fact('investmentOperations', 'integer', activeOperations.length),
    ]),
  });
};

const confirmedIncome = (documents, technicalWindow) => {
  const received = documents.filter(({ fields }) => {
    const status = asString(fields, 'status');
    if (!['expected', 'received', 'cancelled', 'voided'].includes(status)) throw invalidContext();
    const receivedAt = asTimestamp(fields, 'receivedDate', { nullable: true });
    return status === 'received' && receivedAt !== null && isInsideWindow(receivedAt, technicalWindow);
  });
  return Object.freeze({
    confirmed: true,
    facts: Object.freeze([
      fact('investmentIncome', 'moneyCentsBrl', sum(received.map(({ fields }) => asInteger(fields, 'netAmountCents')))),
    ]),
  });
};

/**
 * Responsabilidade: mantém a autoridade do proprietário encapsulada nos
 * leitores de fonte e libera ao bridge apenas fatos mínimos já confirmados.
 */
export class OwnerScopedFirestoreSourceReaders {
  constructor({ authority, transport }) {
    if (!transport || typeof transport.listOwnCollection !== 'function') {
      throw new TypeError('assistant_owner_scoped_reader_dependencies_invalid');
    }
    this.authority = createOwnerScopedFirestoreAuthority(authority ?? {});
    this.transport = transport;
    this.cache = new Map();
  }

  async readOwnSource({ ownerUid, reader, technicalWindow }) {
    if (ownerUid !== this.authority.uid || !technicalWindow) throw invalidContext();
    switch (reader) {
      case 'accounts':
        return confirmedAccounts(await this.#collection('accounts'));
      case 'transactions':
        return confirmedTransactions(
          await this.#collection('transactions'),
          technicalWindow,
        );
      case 'commitments':
      case 'financialCalendar': {
        const [payables, receivables] = await Promise.all([
          this.#collection('payables'),
          this.#collection('receivables'),
        ]);
        const commitments = commitmentFacts({
          payables,
          receivables,
          technicalWindow,
        });
        return reader === 'commitments'
          ? confirmedCommitments(commitments)
          : confirmedCalendar(commitments);
      }
      case 'investments': {
        const [portfolios, assets, operations] = await Promise.all([
          this.#collection('investmentPortfolios'),
          this.#collection('investmentAssets'),
          this.#collection('investmentOperations'),
        ]);
        return confirmedInvestments({
          portfolios,
          assets,
          operations,
          technicalWindow,
        });
      }
      case 'income':
        return confirmedIncome(
          await this.#collection('investmentIncomeEvents'),
          technicalWindow,
        );
      default: throw invalidContext();
    }
  }

  async #collection(collection) {
    if (!ownerCollections.includes(collection)) throw invalidContext();
    if (!this.cache.has(collection)) {
      this.cache.set(
        collection,
        this.transport.listOwnCollection({ authority: this.authority, collection }),
      );
    }
    return this.cache.get(collection);
  }
}

/**
 * Responsabilidade: monta contexto somente depois da admissão server-side,
 * mantendo o bearer temporário fora do resultado, provider e qualquer log.
 */
export class OwnerScopedFirestoreContextReader {
  constructor({ transport, clock = { now: () => new Date() } }) {
    if (!transport || typeof transport.listOwnCollection !== 'function') {
      throw new TypeError('assistant_owner_scoped_context_dependencies_invalid');
    }
    if (!clock || typeof clock.now !== 'function') {
      throw new TypeError('assistant_owner_scoped_clock_invalid');
    }
    this.transport = transport;
    this.clock = clock;
  }

  async readOwnConfirmedContext({ authority, period }) {
    const normalizedPeriod = validateCivilPeriod(period);
    const ownerAuthority = createOwnerScopedFirestoreAuthority(authority ?? {});
    const sourceReaders = new OwnerScopedFirestoreSourceReaders({
      authority: ownerAuthority,
      transport: this.transport,
    });
    const bridge = new AssistantFinancialContextBridge({
      sourceReaders,
      clock: this.clock,
    });
    return bridge.buildOwnConfirmedContext({
      actor: { uid: ownerAuthority.uid },
      period: {
        timeZone: normalizedPeriod.timeZone,
        startDate: normalizedPeriod.startDate,
        endDateExclusive: normalizedPeriod.endDateExclusive,
      },
    });
  }

  async readAuthorizedOwnConfirmedContext({
    authorization,
    authority,
    period,
    scope = DEFAULT_ASSISTANT_CONTEXT_SCOPE,
  }) {
    assertAuthorized(authorization);
    const ownerAuthority = createOwnerScopedFirestoreAuthority(authority ?? {});
    if (authorization.uid !== ownerAuthority.uid) throw deny('assistant_owner_mismatch');
    const admitted = admitOwnFinancialContext({
      authorization,
      scope,
      civilPeriod: period,
    });
    return this.readOwnConfirmedContext({
      authority: ownerAuthority,
      period: admitted.civilPeriod,
    });
  }
}
