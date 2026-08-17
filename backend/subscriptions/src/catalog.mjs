import { deny, requireExactObject, requireText } from './errors.mjs';

/// Catálogo comercial aprovado. Preços não pertencem a este contrato: a loja
/// continua sendo a única autoridade para preço localizado e elegibilidade.
export const PREMIUM_GOOGLE_PLAY_CATALOG = Object.freeze({
  subscriptionId: 'meu_gestor_premium',
  monthlyBasePlanId: 'mensal',
  annualBasePlanId: 'anual',
  monthlyTrialOfferId: 'teste-3d',
  monthlyTrialDurationHours: 72,
});

const CATALOG_FIELDS = Object.freeze([
  'subscriptionId',
  'monthlyBasePlanId',
  'annualBasePlanId',
  'monthlyTrialOfferId',
  'monthlyTrialDurationHours',
]);

/// Aceita somente a configuração comercial aprovada. Retornar o singleton
/// canônico evita que uma cópia mutável recebida por configuração altere o
/// catálogo usado na verificação.
export function resolvePremiumGooglePlayCatalog(configuration) {
  requireExactObject(configuration, CATALOG_FIELDS, 'invalid_google_play_catalog');
  for (const field of CATALOG_FIELDS.filter((field) => field !== 'monthlyTrialDurationHours')) {
    requireText(configuration[field], `invalid_google_play_catalog_${field}`);
  }
  if (!Number.isInteger(configuration.monthlyTrialDurationHours)) {
    throw deny('invalid_google_play_catalog_monthlyTrialDurationHours');
  }
  for (const field of CATALOG_FIELDS) {
    if (configuration[field] !== PREMIUM_GOOGLE_PLAY_CATALOG[field]) {
      throw deny('unsupported_google_play_catalog');
    }
  }
  return PREMIUM_GOOGLE_PLAY_CATALOG;
}

export function planIdForBasePlan(basePlanId) {
  if (basePlanId === PREMIUM_GOOGLE_PLAY_CATALOG.monthlyBasePlanId) return 'monthly';
  if (basePlanId === PREMIUM_GOOGLE_PLAY_CATALOG.annualBasePlanId) return 'annual';
  throw deny('unsupported_google_play_base_plan');
}

export function validatePremiumOffer({ basePlanId, offerId, status }) {
  if (status === 'trialing' && (
    basePlanId !== PREMIUM_GOOGLE_PLAY_CATALOG.monthlyBasePlanId ||
    offerId !== PREMIUM_GOOGLE_PLAY_CATALOG.monthlyTrialOfferId
  )) {
    throw deny('invalid_google_play_trial_offer');
  }
  if (offerId === null) return null;
  requireText(offerId, 'invalid_google_play_offer_id');
  if (
    basePlanId !== PREMIUM_GOOGLE_PLAY_CATALOG.monthlyBasePlanId ||
    offerId !== PREMIUM_GOOGLE_PLAY_CATALOG.monthlyTrialOfferId
  ) {
    throw deny('unsupported_google_play_offer');
  }
  return offerId;
}

export function validatePremiumTrialPeriod({ offerId, status, periodStart, periodEnd }) {
  if (offerId === null) return;
  // A API verificada pode preservar a oferta de entrada no estado ativo após
  // o fim do teste. A duração de 72h é exigida apenas enquanto está trialing.
  if (status === 'active') return;
  if (status !== 'trialing' || periodStart === null || periodEnd === null) {
    throw deny('invalid_google_play_trial_period');
  }
  const durationHours = (periodEnd.valueOf() - periodStart.valueOf()) / (60 * 60 * 1000);
  if (durationHours !== PREMIUM_GOOGLE_PLAY_CATALOG.monthlyTrialDurationHours) {
    throw deny('invalid_google_play_trial_period');
  }
}
