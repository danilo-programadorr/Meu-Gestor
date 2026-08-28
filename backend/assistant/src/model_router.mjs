import { deny } from './errors.mjs';

export const ASSISTANT_ROUTER_POLICY_VERSION = 'assist-router-2026-08-25';

export const MODEL_TIER = Object.freeze({ flash: 'flash', pro: 'pro' });

export const DEFAULT_ROUTER_LIMITS = Object.freeze({
  maxContextFacts: 128,
  flashMaxInputUnits: 2_500,
  flashMaxOutputUnits: 800,
  proMaxInputUnits: 6_000,
  proMaxOutputUnits: 1_500,
  proCallsPerWindow: 4,
  costUnitsPerWindow: 32,
  flashCostUnits: 1,
  proCostUnits: 8,
});

const complexSignals = Object.freeze([
  /\bcompar(?:e|ar|ação|acoes|ações)\b/iu,
  /\bcen[aá]rios?\b/iu,
  /\bproje(?:te|tar|ção|coes|ções)\b/iu,
  /\btrade-?offs?\b/iu,
  /\bcorrela(?:ção|coes|ções)\b/iu,
  /\bm[uú]ltipl(?:as|os) (?:fontes|per[ií]odos|hip[oó]teses)\b/iu,
]);

const estimateInputUnits = ({ message, context }) =>
  message.length + JSON.stringify(context.facts).length + JSON.stringify(context.missingSources).length;

const assertUsage = (usage) => {
  const exactKeys = ['costUnitsInWindow', 'proCallsInWindow'];
  if (!usage || typeof usage !== 'object' || Object.keys(usage).sort().join('|') !== exactKeys.sort().join('|')) {
    throw deny('assistant_invalid_usage');
  }
  for (const value of Object.values(usage)) {
    if (!Number.isSafeInteger(value) || value < 0) throw deny('assistant_invalid_usage');
  }
};

export class AssistantModelRouter {
  constructor({ limits = DEFAULT_ROUTER_LIMITS } = {}) {
    this.limits = limits;
  }

  route({ message, context, usage }) {
    assertUsage(usage);
    if (context.facts.length > this.limits.maxContextFacts) throw deny('assistant_context_limit_exceeded');

    const inputUnits = estimateInputUnits({ message, context });
    const signalCount = complexSignals.reduce((total, pattern) => total + Number(pattern.test(message)), 0);
    const requiresPro = signalCount >= 2;
    if (!requiresPro) {
      if (inputUnits > this.limits.flashMaxInputUnits) throw deny('assistant_context_limit_exceeded');
      if (usage.costUnitsInWindow + this.limits.flashCostUnits > this.limits.costUnitsPerWindow) {
        throw deny('assistant_usage_limit_reached');
      }
      return Object.freeze({
        policyVersion: ASSISTANT_ROUTER_POLICY_VERSION,
        tier: MODEL_TIER.flash,
        maxInputUnits: this.limits.flashMaxInputUnits,
        maxOutputUnits: this.limits.flashMaxOutputUnits,
        costUnits: this.limits.flashCostUnits,
        reason: 'common_explanation',
      });
    }

    if (inputUnits > this.limits.proMaxInputUnits) throw deny('assistant_context_limit_exceeded');
    if (
      usage.proCallsInWindow >= this.limits.proCallsPerWindow ||
      usage.costUnitsInWindow + this.limits.proCostUnits > this.limits.costUnitsPerWindow
    ) {
      throw deny('assistant_pro_limit_reached');
    }
    return Object.freeze({
      policyVersion: ASSISTANT_ROUTER_POLICY_VERSION,
      tier: MODEL_TIER.pro,
      maxInputUnits: this.limits.proMaxInputUnits,
      maxOutputUnits: this.limits.proMaxOutputUnits,
      costUnits: this.limits.proCostUnits,
      reason: 'complex_analysis',
    });
  }
}
