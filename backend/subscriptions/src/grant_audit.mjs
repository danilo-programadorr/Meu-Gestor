export function sanitizeGrantAudit({ request, action, revision, at }) {
  return Object.freeze({
    action,
    source: request.source,
    environment: request.environment,
    planId: request.planId,
    capabilityCount: request.capabilities.length,
    revision,
    at,
  });
}
