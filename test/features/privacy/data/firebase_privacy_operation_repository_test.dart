import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/privacy/data/firebase_privacy_operation_repository.dart';
import 'package:meu_gestor_financeiro/features/privacy/domain/privacy_operation.dart';
import 'package:meu_gestor_financeiro/features/privacy/domain/privacy_operation_failure.dart';

void main() {
  const String ownerId = 'synthetic-owner';
  const String operationId = 'privacy-operation-synthetic-0001';

  test(
    'interpreta progresso persistente sem tratar prepare como conclusão',
    () {
      final PrivacyOperationSnapshot snapshot =
          FirebasePrivacyOperationRepository.parseResponse(<String, Object?>{
            'operationId': operationId,
            'type': 'financialReset',
            'state': 'deleting',
            'revision': 4,
            'createdAt': '2026-10-18T12:00:00.000Z',
            'updatedAt': '2026-10-18T12:01:00.000Z',
          }, ownerId);
      expect(snapshot.isCompleted, isFalse);
      expect(snapshot.state, PrivacyOperationState.deletingFinancialData);
      expect(snapshot.operation?.ownerId, ownerId);
    },
  );

  test('aceita somente recibo concluído com retenção contratada', () {
    final PrivacyOperationSnapshot snapshot =
        FirebasePrivacyOperationRepository.parseResponse(<String, Object?>{
          'operationId': operationId,
          'type': 'accountDeletion',
          'state': 'completed',
          'receipt': <String, Object?>{
            'receiptId': 'privacy-receipt-synthetic-0001',
            'type': 'accountDeletion',
            'result': 'accountDeleted',
            'completedAt': '2026-10-18T12:00:00.000Z',
            'expiresAt': '2026-11-17T12:00:00.000Z',
          },
        }, ownerId);
    expect(snapshot.isCompleted, isTrue);
    expect(snapshot.receipt?.result, PrivacyOperationResult.accountDeleted);
  });

  test('rejeita conclusão sem recibo e retenção divergente', () {
    for (final Map<String, Object?> response in <Map<String, Object?>>[
      <String, Object?>{
        'operationId': operationId,
        'type': 'financialReset',
        'state': 'completed',
      },
      <String, Object?>{
        'operationId': operationId,
        'type': 'financialReset',
        'state': 'completed',
        'receipt': <String, Object?>{
          'receiptId': 'privacy-receipt-synthetic-0001',
          'type': 'financialReset',
          'result': 'resetCompleted',
          'completedAt': '2026-10-18T12:00:00.000Z',
          'expiresAt': '2026-10-19T12:00:00.000Z',
        },
      },
    ]) {
      expect(
        () =>
            FirebasePrivacyOperationRepository.parseResponse(response, ownerId),
        throwsA(
          isA<PrivacyOperationFailure>().having(
            (PrivacyOperationFailure value) => value.kind,
            'kind',
            PrivacyOperationFailureKind.inconsistentState,
          ),
        ),
      );
    }
  });
}
