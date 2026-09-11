/// Representa o único aceite que permite preparar contexto financeiro remoto.
final class AssistantRemoteConsent {
  const AssistantRemoteConsent({
    required this.financialContextAllowed,
    required this.updatedAt,
  });

  static const String version = 'assist-context-v1';
  final bool financialContextAllowed;
  final DateTime updatedAt;
}

/// Define a porta do aceite remoto próprio, sem transportar contexto financeiro.
abstract interface class AssistantRemoteConsentRepository {
  Future<bool> readOwnConsent({required String ownerId});

  Future<void> setOwnConsent({
    required String ownerId,
    required bool financialContextAllowed,
  });
}
