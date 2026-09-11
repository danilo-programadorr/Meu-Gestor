/**
 * Responsabilidade: conecta autorização e contexto do proprietário sem
 * conceder à identidade runtime acesso administrativo ao banco padrão.
 */
import { GoogleAuth } from 'google-auth-library';
import {
  ASSISTANT_POLICY_VERSION,
  OwnerScopedFirestoreContextReader,
  OwnerScopedFirestoreRestTransport,
  civilPeriodForSingleDay,
  currentCivilDate,
} from '../shared/index.mjs';

const invalid = () => new Error('assistant_runtime_adapter_unavailable');
const exactKeys = (value, keys) => value !== null && typeof value === 'object'
  && !Array.isArray(value) && Object.keys(value).sort().join('|') === [...keys].sort().join('|');
const stringValue = (fields, field) => fields?.[field]?.stringValue;
const boolValue = (fields, field) => fields?.[field]?.booleanValue;
const timestampValue = (fields, field) => fields?.[field]?.timestampValue;

/** Responsabilidade: traduz somente o perfil e a preferência remota confirmados
 * em autorização server-side; qualquer divergência preserva privacidade ativa. */
const authorizationFrom = ({ uid, profile, settings }) => {
  const legalProfileVerified = exactKeys(profile, [
    'ownerId', 'emailVerifiedSnapshot', 'termsVersionAccepted',
    'privacyVersionAccepted', 'aiConsentEnabled', 'aiConsentUpdatedAt',
  ])
    && stringValue(profile, 'ownerId') === uid
    && boolValue(profile, 'emailVerifiedSnapshot') === true
    && stringValue(profile, 'termsVersionAccepted') === 'terms-dev-1.0.0'
    && stringValue(profile, 'privacyVersionAccepted') === 'privacy-dev-1.0.0'
    && typeof timestampValue(profile, 'aiConsentUpdatedAt') === 'string'
    && !Number.isNaN(Date.parse(timestampValue(profile, 'aiConsentUpdatedAt')));
  const settingsValid = exactKeys(settings, ['consentVersion', 'financialContextAllowed', 'updatedAt'])
    && stringValue(settings, 'consentVersion') === ASSISTANT_POLICY_VERSION
    && boolValue(settings, 'financialContextAllowed') === true
    && typeof timestampValue(settings, 'updatedAt') === 'string'
    && !Number.isNaN(Date.parse(timestampValue(settings, 'updatedAt')));
  const allowed = legalProfileVerified && boolValue(profile, 'aiConsentEnabled') === true && settingsValid;
  return Object.freeze({
    legalProfileVerified,
    aiConsentEnabled: allowed,
    acceptedPolicyVersion: allowed ? ASSISTANT_POLICY_VERSION : null,
    aiConsentUpdatedAt: allowed ? timestampValue(settings, 'updatedAt') : null,
    profileFromServer: true,
    profileHasPendingWrites: false,
    financialPrivacyActive: !allowed,
  });
};

/** Responsabilidade: usa ADC somente para resolver o projeto; cada leitura do
 * banco padrão permanece delegada ao bearer do usuário autenticado. */
export const createAssistantRuntimeAdapters = ({
  authFactory = () => new GoogleAuth(), fetchImpl = globalThis.fetch, clock = () => new Date(),
} = {}) => {
  const auth = authFactory();
  if (!auth || typeof auth.getProjectId !== 'function' || typeof fetchImpl !== 'function' || typeof clock !== 'function') throw invalid();
  const transport = new OwnerScopedFirestoreRestTransport({
    projectIdReader: async () => auth.getProjectId(), fetchImpl,
  });
  const context = new OwnerScopedFirestoreContextReader({ transport, clock: { now: clock } });
  return Object.freeze({
    authorizationReader: async ({ uid, ownerAuthority }) => {
      try {
        const [profile, settings] = await Promise.all([
          transport.getOwnAuthorizationDocument({ authority: ownerAuthority, document: 'profile' }),
          transport.getOwnAuthorizationDocument({ authority: ownerAuthority, document: 'remoteSettings' }),
        ]);
        return authorizationFrom({ uid, profile, settings });
      } catch {
        return Object.freeze({ legalProfileVerified: false, aiConsentEnabled: false, acceptedPolicyVersion: null, aiConsentUpdatedAt: null, profileFromServer: false, profileHasPendingWrites: true, financialPrivacyActive: true });
      }
    },
    contextReader: async ({ ownerAuthority, authorization }) => context.readAuthorizedOwnConfirmedContext({
      authorization,
      authority: ownerAuthority,
      period: civilPeriodForSingleDay(currentCivilDate(clock())),
    }),
  });
};
