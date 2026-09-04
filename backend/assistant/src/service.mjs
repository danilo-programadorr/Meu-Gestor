import { assertAuthorized, assertConfirmedContext, enforceAssistantSafetyGate, MEMORY_MODE, validateClientRequest } from './policy.mjs';

const buildProviderRequest = ({ message, context, routing }) => Object.freeze({
  schemaVersion: 1,
  locale: 'pt-BR',
  currency: 'BRL',
  civilTimeZone: 'America/Sao_Paulo',
  memoryMode: MEMORY_MODE,
  message,
  generatedAt: context.generatedAt,
  civilPeriod: context.civilPeriod,
  technicalWindow: context.technicalWindow,
  facts: context.facts,
  missingSources: context.missingSources,
  routing,
  responseContract: Object.freeze({ citationsRequired: true, mutationsAllowed: false, explicitConfirmationRequiredForProposals: true }),
});

export class AssistantService {
  constructor({ contextRepository, providerGateway, modelRouter, usageRepository }) {
    if (!contextRepository || !providerGateway || !modelRouter || !usageRepository) throw new TypeError('assistant_dependencies_required');
    this.contextRepository = contextRepository;
    this.providerGateway = providerGateway;
    this.modelRouter = modelRouter;
    this.usageRepository = usageRepository;
  }

  async ask({ clientRequest, authorization }) {
    const request = validateClientRequest(clientRequest);
    assertAuthorized(authorization);
    const context = await this.contextRepository.readOwnConfirmedContext(authorization.uid);
    const evidenceIds = assertConfirmedContext(context);
    const usage = await this.usageRepository.readOwnWindow(authorization.uid);
    const routing = this.modelRouter.route({ message: request.message, context, usage });
    const providerRequest = buildProviderRequest({ message: request.message, context, routing });
    const response = await this.providerGateway.generate(providerRequest);
    return enforceAssistantSafetyGate({
      response,
      evidenceIds,
      facts: context.facts,
      financialPrivacyActive: authorization.financialPrivacyActive === true,
    });
  }
}
