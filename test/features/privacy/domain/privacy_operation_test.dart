import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/privacy/domain/privacy_data_manifest.dart';
import 'package:meu_gestor_financeiro/features/privacy/domain/privacy_operation.dart';
import 'package:meu_gestor_financeiro/features/privacy/domain/privacy_operation_failure.dart';
import 'package:meu_gestor_financeiro/features/privacy/domain/privacy_operation_policy.dart';

void main() {
  const PrivacyOperationPolicy policy = PrivacyOperationPolicy();
  final DateTime instant = DateTime.utc(2026, 8, 17, 15);

  PrivacyOperation operation({
    PrivacyOperationType type = PrivacyOperationType.financialReset,
    PrivacyOperationState state = PrivacyOperationState.prepared,
    PrivacyOperationState? resumeState,
  }) => PrivacyOperation(
    id: PrivacyOperationId('operation-synthetic-0001'),
    type: type,
    ownerId: 'synthetic-user',
    state: state,
    revision: 1,
    createdAt: instant,
    updatedAt: instant,
    resumeState: resumeState,
  );

  PrivacyOperationAuthorization authorization({
    bool authenticated = true,
    bool appCheckVerified = true,
    bool emailVerified = true,
    bool legalProfileVerified = true,
    String? authenticatedUid = 'synthetic-user',
    DateTime? authenticatedAt,
  }) => PrivacyOperationAuthorization(
    authenticated: authenticated,
    appCheckVerified: appCheckVerified,
    emailVerified: emailVerified,
    legalProfileVerified: legalProfileVerified,
    authenticatedUid: authenticatedUid,
    authenticatedAt:
        authenticatedAt ?? instant.subtract(const Duration(minutes: 5)),
    serverNow: instant,
  );

  group('PrivacyDataManifest', () {
    test('reset contém somente os nove conjuntos financeiros aprovados', () {
      expect(PrivacyDataManifest.financialResetTargets, hasLength(9));
      expect(
        PrivacyDataManifest.financialResetTargets.every(
          (target) => target.isFinancial,
        ),
        isTrue,
      );
      expect(
        PrivacyDataManifest.financialResetTargets,
        isNot(contains(PrivacyDataTarget.premiumEntitlement)),
      );
    });

    test('exclusão inclui perfil e referências Premium fechadas', () {
      expect(
        PrivacyDataManifest.accountDeletionTargets,
        containsAll(<PrivacyDataTarget>[
          PrivacyDataTarget.userProfile,
          PrivacyDataTarget.systemAdmin,
          PrivacyDataTarget.premiumEntitlement,
          PrivacyDataTarget.premiumClosedTestTesters,
          PrivacyDataTarget.premiumClosedTestGrants,
        ]),
      );
    });
  });

  group('PrivacyOperationPolicy', () {
    test('exige frase correta e autorização inteiramente verificada', () {
      policy.assertCanStart(
        type: PrivacyOperationType.financialReset,
        confirmationPhrase: 'RESETAR DADOS FINANCEIROS',
        requestedOwnerId: 'synthetic-user',
        authorization: authorization(),
      );

      expect(
        () => policy.assertCanStart(
          type: PrivacyOperationType.accountDeletion,
          confirmationPhrase: 'resetar dados financeiros',
          requestedOwnerId: 'synthetic-user',
          authorization: authorization(),
        ),
        throwsA(
          isA<PrivacyOperationFailure>().having(
            (failure) => failure.kind,
            'kind',
            PrivacyOperationFailureKind.invalidConfirmation,
          ),
        ),
      );
    });

    test('nega ausência de autenticação, App Check, e-mail e UID próprio', () {
      final List<PrivacyOperationAuthorization> cases =
          <PrivacyOperationAuthorization>[
            authorization(authenticated: false, authenticatedUid: null),
            authorization(appCheckVerified: false),
            authorization(emailVerified: false),
            authorization(legalProfileVerified: false),
            authorization(authenticatedUid: 'another-synthetic-user'),
          ];
      for (final PrivacyOperationAuthorization value in cases) {
        expect(
          () => policy.assertCanStart(
            type: PrivacyOperationType.financialReset,
            confirmationPhrase: 'RESETAR DADOS FINANCEIROS',
            requestedOwnerId: 'synthetic-user',
            authorization: value,
          ),
          throwsA(isA<PrivacyOperationFailure>()),
        );
      }
    });

    test('usa auth_time do servidor com máximo de cinco minutos', () {
      policy.assertCanStart(
        type: PrivacyOperationType.accountDeletion,
        confirmationPhrase: 'EXCLUIR MINHA CONTA',
        requestedOwnerId: 'synthetic-user',
        authorization: authorization(),
      );
      expect(
        () => policy.assertCanStart(
          type: PrivacyOperationType.accountDeletion,
          confirmationPhrase: 'EXCLUIR MINHA CONTA',
          requestedOwnerId: 'synthetic-user',
          authorization: authorization(
            authenticatedAt: instant.subtract(
              const Duration(minutes: 5, seconds: 1),
            ),
          ),
        ),
        throwsA(
          isA<PrivacyOperationFailure>().having(
            (failure) => failure.kind,
            'kind',
            PrivacyOperationFailureKind.recentAuthenticationRequired,
          ),
        ),
      );
    });

    test('percorre reset e exclusão sem permitir restauração terminal', () {
      expect(
        policy.transition(
          operation: operation(),
          next: PrivacyOperationState.confirmed,
        ),
        PrivacyOperationState.confirmed,
      );
      expect(
        policy.transition(
          operation: operation(
            state: PrivacyOperationState.deletingFinancialData,
          ),
          next: PrivacyOperationState.completed,
        ),
        PrivacyOperationState.completed,
      );
      expect(
        policy.transition(
          operation: operation(
            type: PrivacyOperationType.accountDeletion,
            state: PrivacyOperationState.deletingFinancialData,
          ),
          next: PrivacyOperationState.deletingIdentityData,
        ),
        PrivacyOperationState.deletingIdentityData,
      );
      expect(
        () => policy.transition(
          operation: operation(state: PrivacyOperationState.completed),
          next: PrivacyOperationState.confirmed,
        ),
        throwsA(isA<PrivacyOperationFailure>()),
      );
    });

    test('retry só pode retomar a etapa persistida', () {
      final PrivacyOperation retry = operation(
        state: PrivacyOperationState.retryableFailure,
        resumeState: PrivacyOperationState.deletingFinancialData,
      );
      expect(
        policy.transition(
          operation: retry,
          next: PrivacyOperationState.deletingFinancialData,
        ),
        PrivacyOperationState.deletingFinancialData,
      );
      expect(
        () => policy.transition(
          operation: retry,
          next: PrivacyOperationState.deletingIdentityData,
        ),
        throwsA(isA<PrivacyOperationFailure>()),
      );
    });
  });

  group('AnonymousPrivacyReceipt', () {
    test('não carrega UID e expira após os trinta dias planejados', () {
      final AnonymousPrivacyReceipt receipt = AnonymousPrivacyReceipt.create(
        receiptId: 'anonymous-receipt-0001',
        type: PrivacyOperationType.accountDeletion,
        result: PrivacyOperationResult.accountDeleted,
        completedAt: instant,
      );
      expect(receipt.expiresAt, instant.add(const Duration(days: 30)));
      expect(receipt.result, PrivacyOperationResult.accountDeleted);
    });
  });
}
