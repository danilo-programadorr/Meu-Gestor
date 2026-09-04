import { admitOwnFinancialContext } from './context_admission.mjs';
import { deny } from './errors.mjs';

export const ASSISTANT_AUTHORIZED_CONTEXT_ASSEMBLER_VERSION = 'assist-authorized-context-assembler-v1';

/** Source readers are injected server-side; this boundary knows no network or provider. */
export class AssistantAuthorizedContextAssembler {
  constructor({ bridge }) {
    if (!bridge || typeof bridge.buildOwnConfirmedContext !== 'function') {
      throw new TypeError('assistant_context_assembler_dependency_invalid');
    }
    this.bridge = bridge;
  }

  async assemble({ authorization, civilPeriod, scope }) {
    if (!authorization?.authenticated || typeof authorization.uid !== 'string' || authorization.uid.length === 0) {
      throw deny('assistant_unauthenticated');
    }
    const admitted = admitOwnFinancialContext({ authorization, civilPeriod, scope });
    return Object.freeze(await this.bridge.buildOwnConfirmedContext({
      actor: { uid: authorization.uid }, period: admitted.civilPeriod,
    }));
  }
}
