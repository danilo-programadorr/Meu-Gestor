// Responsabilidade: registra localmente se a apresentação inicial da Luma já
// foi vista pela conta atual, sem enviar esse estado ao backend ou ao modelo.
abstract interface class AssistantIntroductionRepository {
  Future<bool> hasSeen({required String ownerId});

  Future<void> markSeen({required String ownerId});
}

final class AssistantIntroductionStorageFailure implements Exception {
  const AssistantIntroductionStorageFailure();
}
