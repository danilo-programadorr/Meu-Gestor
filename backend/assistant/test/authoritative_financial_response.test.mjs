/**
 * Intenção: prova que listagens simples preservam os rótulos owner-scoped
 * literalmente e atravessam a mesma admissão usada por respostas do modelo.
 */
import assert from 'node:assert/strict';
import test from 'node:test';

import {
  admitGroundedAssistantResponse,
  buildAuthoritativeAssetListResponse,
} from '../src/index.mjs';

const period = Object.freeze({
  timeZone: 'America/Sao_Paulo',
  startDate: '2026-10-01',
  endDateExclusive: '2026-10-02',
});
const evidenceFact = ({ evidenceId, kind, value }) => Object.freeze({
  evidenceId,
  source: 'investmentAssets',
  kind,
  value,
  civilPeriod: period,
  evidence: Object.freeze({ alias: evidenceId, source: 'investmentAssets', period }),
});
const contextFor = (facts) => Object.freeze({
  ownerVerified: true,
  isFromServer: true,
  hasPendingWrites: false,
  generatedAt: '2026-10-02T03:00:00.000Z',
  civilPeriod: period,
  technicalWindow: Object.freeze({
    start: '2026-10-01T03:00:00.000Z',
    endExclusive: '2026-10-02T03:00:00.000Z',
  }),
  availableDataWindow: Object.freeze({
    start: '2026-10-01T03:00:00.000Z',
    endExclusive: '2026-10-02T03:00:00.000Z',
  }),
  periodComplete: true,
  facts: Object.freeze(facts),
  missingSources: Object.freeze([]),
});

test('renderiza nomes e tickers validados sem segunda composição generativa', () => {
  const context = contextFor([
    evidenceFact({ evidenceId: 'ev_assets_001', kind: 'integer', value: 2 }),
    evidenceFact({ evidenceId: 'ev_assets_002', kind: 'safeLabel', value: 'PETR4 · Petrobras PN' }),
    evidenceFact({ evidenceId: 'ev_assets_003', kind: 'safeLabel', value: 'HGLG11 · CSHG Logística' }),
  ]);
  const response = buildAuthoritativeAssetListResponse(context);
  const admission = admitGroundedAssistantResponse({ response, context });

  assert.equal(admission.finalStatus, 'grounded');
  assert.equal(
    admission.response.answer,
    'Seus ativos cadastrados atualmente são: PETR4 · Petrobras PN e HGLG11 · CSHG Logística.',
  );
  assert.deepEqual(
    admission.response.assertions.map((item) => item.evidence.alias),
    ['ev_assets_002', 'ev_assets_003'],
  );
});

test('não renderiza lista parcial, duplicada ou incompatível com a contagem', () => {
  const context = contextFor([
    evidenceFact({ evidenceId: 'ev_assets_001', kind: 'integer', value: 2 }),
    evidenceFact({ evidenceId: 'ev_assets_002', kind: 'safeLabel', value: 'PETR4 · Petrobras PN' }),
  ]);
  assert.equal(buildAuthoritativeAssetListResponse(context), null);
});

test('ausência confirmada de ativos produz resposta grounded sem inventar nome', () => {
  const context = contextFor([
    evidenceFact({ evidenceId: 'ev_assets_001', kind: 'integer', value: 0 }),
  ]);
  const admission = admitGroundedAssistantResponse({
    response: buildAuthoritativeAssetListResponse(context),
    context,
  });
  assert.equal(admission.finalStatus, 'grounded');
  assert.equal(admission.response.answer, 'Você não possui ativos cadastrados atualmente.');
});
