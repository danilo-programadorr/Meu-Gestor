import 'privacy_operation.dart';
import 'privacy_operation_policy.dart';

/// Comando sem UID, relógio de aparelho, App Check ou dados financeiros.
/// A fronteira autenticada deriva esses valores no servidor.
final class PrivacyOperationStartCommand {
  PrivacyOperationStartCommand({
    required this.type,
    required this.confirmationPhrase,
    required this.idempotencyKey,
  }) {
    if (confirmationPhrase.trim().isEmpty) {
      throw ArgumentError.value(
        confirmationPhrase,
        'confirmationPhrase',
        'A frase de confirmação é obrigatória.',
      );
    }
  }

  final PrivacyOperationType type;
  final String confirmationPhrase;
  final PrivacyIdempotencyKey idempotencyKey;
}

/// Contrato de backend futuro. A implementação deverá executar todas as
/// deleções, lock, cursor e limpeza local posterior; o cliente nunca recebe um
/// comando de exclusão direta para Firestore ou Authentication.
abstract interface class PrivacyOperationBackend {
  Future<PrivacyOperation> start({
    required PrivacyOperationStartCommand command,
    required PrivacyOperationAuthorization authorization,
  });

  Future<PrivacyOperation> retry({
    required PrivacyOperationId operationId,
    required PrivacyOperationAuthorization authorization,
  });

  Future<AnonymousPrivacyReceipt?> findAnonymousReceipt(String receiptId);
}

/// A interface de leitura do aplicativo permite recuperar somente seu estado
/// confirmado. Ela não contém métodos para apagar dados, escrever grants ou
/// consultar operações de terceiros.
abstract interface class PrivacyOperationRepository {
  Future<PrivacyOperation> request(PrivacyOperationStartCommand command);

  Future<PrivacyOperation> retry(PrivacyOperationId operationId);

  Future<PrivacyOperation> status(PrivacyOperationId operationId);
}
