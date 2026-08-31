import assert from 'node:assert/strict';
import test from 'node:test';

import { enforceAssistantSafetyGate } from '../src/index.mjs';

const facts = [{ evidenceId: 'saldo_confirmado', value: 75000 }];
const evidenceIds = new Set(['saldo_confirmado']);
const response = (overrides = {}) => ({
  schemaVersion: 1,
  answer: 'O saldo confirmado é 75000.',
  observations: [{ statement: 'O valor vem da fonte confirmada.', evidenceIds: ['saldo_confirmado'] }],
  missingData: [],
  proposedActions: [],
  disclaimer: 'Conteúdo informativo; revise os dados antes de decidir.',
  ...overrides,
});

const blocked = (value) => {
  assert.equal(value.answer, 'Não posso fornecer essa orientação com segurança neste momento.');
  assert.deepEqual(value.observations, []);
  assert.deepEqual(value.proposedActions, []);
};

test('entrega somente resposta informativa fundamentada', () => {
  assert.deepEqual(
    enforceAssistantSafetyGate({ response: response(), evidenceIds, facts }),
    response(),
  );
});

for (const unsafeAnswer of [
  'Compre este ativo agora.',
  'Pague a conta automaticamente.',
  'Use token=segredo para consultar.',
  'O saldo confirmado é 99999.',
]) {
  test('bloqueia saída maliciosa ou sem evidência', () => {
    blocked(enforceAssistantSafetyGate({ response: response({ answer: unsafeAnswer }), evidenceIds, facts }));
  });
}

test('bloqueia propostas de mutação mesmo com confirmação declarada pelo modelo', () => {
  blocked(enforceAssistantSafetyGate({
    response: response({
      proposedActions: [{ proposalId: 'proposal_123456789', kind: 'draftCreate', target: 'payable_1', preview: 'Criar depois.', previewDigest: 'digest_1234567890', requiresExplicitConfirmation: true }],
    }),
    evidenceIds,
    facts,
  }));
});

test('privacidade financeira bloqueia valores antes da entrega', () => {
  blocked(enforceAssistantSafetyGate({ response: response(), evidenceIds, facts, financialPrivacyActive: true }));
});

test('resposta sem citação permitida falha fechada', () => {
  blocked(enforceAssistantSafetyGate({
    response: response({ observations: [{ statement: 'Fonte desconhecida.', evidenceIds: ['other_fact'] }] }),
    evidenceIds,
    facts,
  }));
});
