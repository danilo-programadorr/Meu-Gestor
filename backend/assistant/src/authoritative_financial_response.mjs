/**
 * Responsabilidade: renderiza respostas simples diretamente de fatos
 * owner-scoped já admitidos, sem permitir que texto gerado altere identidades.
 */
const MAX_DIRECT_ASSET_LABELS = 18;

const joinedLabels = (labels) => labels.length === 1
  ? labels[0]
  : `${labels.slice(0, -1).join(', ')} e ${labels.at(-1)}`;

export const buildAuthoritativeAssetListResponse = (context) => {
  const countFact = context?.facts?.find((fact) => fact.source === 'investmentAssets'
    && fact.kind === 'integer');
  const labelFacts = context?.facts?.filter((fact) => fact.source === 'investmentAssets'
    && fact.kind === 'safeLabel') ?? [];
  if (!countFact || !Number.isSafeInteger(countFact.value)
      || countFact.value < 0 || labelFacts.length !== countFact.value
      || labelFacts.length > MAX_DIRECT_ASSET_LABELS
      || new Set(labelFacts.map((fact) => fact.value)).size !== labelFacts.length) {
    return null;
  }
  if (labelFacts.length === 0) {
    return Object.freeze({
      schemaVersion: 1,
      status: 'grounded',
      intent: 'investment_assets',
      clarificationCode: 'none',
      answer: 'Você não possui ativos cadastrados atualmente.',
      assertions: Object.freeze([Object.freeze({
        statement: 'Não há ativos cadastrados atualmente.',
        evidence: countFact.evidence,
      })]),
      missingData: Object.freeze([]),
    });
  }
  const labels = labelFacts.map((fact) => fact.value);
  return Object.freeze({
    schemaVersion: 1,
    status: 'grounded',
    intent: 'investment_assets',
    clarificationCode: 'none',
    answer: `Seus ativos cadastrados atualmente são: ${joinedLabels(labels)}.`,
    assertions: Object.freeze(labelFacts.map((fact) => Object.freeze({
      statement: `Ativo cadastrado: ${fact.value}.`,
      evidence: fact.evidence,
    }))),
    missingData: Object.freeze([]),
  });
};
