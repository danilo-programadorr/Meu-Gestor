import { assertAuthorized, assertConfirmedContext, MEMORY_MODE, validateClientRequest, validateProviderResponse } from './policy.mjs';

const buildProviderRequest = ({ message, context }) => Object.freeze({
  schemaVersion: 1,
  locale: 'pt-BR',
  currency: 'BRL',
  civilTimeZone: 'America/Sao_Paulo',
  memoryMode: MEMORY_MODE,
  message,
  generatedAt: context.generatedAt,
  period: context.period,
  facts: context.facts,
  missingSources: context.missingSources,
  responseContract: Object.freeze({ citationsRequired: true, mutationsAllowed: false, explicitConfirmationRequiredForProposals: true }),
});

export class AssistantService {
  constructor({ contextRepository, providerGateway }) {
    if (!contextRepository || !providerGateway) throw new TypeError('assistant_dependencies_required');
    this.contextRepository = contextRepository;
    this.providerGateway = providerGateway;
  }

  async ask({ clientRequest, authorization }) {
    const request = validateClientRequest(clientRequest);
    assertAuthorized(authorization);
    const context = await this.contextRepository.readOwnConfirmedContext(authorization.uid);
    const evidenceIds = assertConfirmedContext(context);
    const providerRequest = buildProviderRequest({ message: request.message, context });
    const response = await this.providerGateway.generate(providerRequest);
    return validateProviderResponse(response, evidenceIds);
  }
}
