export const syntheticPackageName = 'com.example.meugestor.development';
export const syntheticProjectId = 'demo-meu-gestor-subscriptions';
export const syntheticAccountId = 'synthetic-obfuscated-account';

export function instant(day, hour = 0) {
  return `2026-08-${String(day).padStart(2, '0')}T${String(hour).padStart(2, '0')}:00:00.000Z`;
}

/// Resposta normalizada que o futuro adaptador da Play Developer API deverá
/// produzir após autenticação server-side. Todos os valores são sintéticos.
export function googlePlaySubscriptionResponse(overrides = {}) {
  return {
    eventId: 'synthetic-event-1',
    eventTime: instant(10),
    packageName: syntheticPackageName,
    subscriptionId: 'meu_gestor_premium',
    basePlanId: 'mensal',
    offerId: null,
    subscriptionState: 'ACTIVE',
    periodStart: instant(1),
    periodEnd: '2026-09-01T00:00:00.000Z',
    graceUntil: null,
    autoRenewEnabled: true,
    cancelledAt: null,
    expiredAt: null,
    revokedAt: null,
    refundedAt: null,
    acknowledgementState: 'PENDING',
    linkedPurchaseToken: null,
    obfuscatedExternalAccountId: syntheticAccountId,
    ...overrides,
  };
}

/// Mensagem RTDN já decodificada pelo futuro perímetro autenticado. O token é
/// transitório e só existe na fixture de teste.
export function rtdnNotification(overrides = {}) {
  return {
    messageId: 'synthetic-rtdn-message-1',
    projectId: syntheticProjectId,
    packageName: syntheticPackageName,
    purchaseToken: 'synthetic-purchase-token-1',
    ...overrides,
  };
}
