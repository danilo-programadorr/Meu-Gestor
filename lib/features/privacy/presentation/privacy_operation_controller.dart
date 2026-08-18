import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_gestor_financeiro/features/authentication/data/auth_providers.dart';
import 'package:meu_gestor_financeiro/features/authentication/domain/auth_failure.dart';
import 'package:meu_gestor_financeiro/features/authentication/domain/auth_repository.dart';
import 'package:meu_gestor_financeiro/features/privacy/data/firebase_privacy_operation_repository.dart';
import 'package:meu_gestor_financeiro/features/privacy/domain/privacy_operation.dart';
import 'package:meu_gestor_financeiro/features/privacy/domain/privacy_operation_contract.dart';
import 'package:meu_gestor_financeiro/features/privacy/domain/privacy_operation_failure.dart';

enum PrivacyUiStatus {
  idle,
  prepared,
  processing,
  completed,
  recoverableFailure,
  sessionLost,
}

enum PrivacyReauthenticationMethod { password, google }

final class PrivacyUiState {
  const PrivacyUiState._({required this.status, this.type, this.message});
  const PrivacyUiState.idle() : this._(status: PrivacyUiStatus.idle);
  final PrivacyUiStatus status;
  final PrivacyOperationType? type;
  final String? message;
  bool get isBusy => status == PrivacyUiStatus.processing;
}

final Provider<PrivacyOperationRepository> privacyOperationRepositoryProvider =
    Provider<PrivacyOperationRepository>(
      (Ref ref) => FirebasePrivacyOperationRepository(
        functions: FirebaseFunctions.instanceFor(region: 'southamerica-east1'),
        auth: FirebaseAuth.instance,
      ),
    );

final Provider<PrivacyLocalCleanupCoordinator>
privacyLocalCleanupCoordinatorProvider =
    Provider<PrivacyLocalCleanupCoordinator>(
      (Ref ref) => const _UnavailablePrivacyLocalCleanupCoordinator(),
    );

final NotifierProvider<PrivacyOperationController, PrivacyUiState>
privacyOperationControllerProvider =
    NotifierProvider<PrivacyOperationController, PrivacyUiState>(
      PrivacyOperationController.new,
    );

abstract interface class PrivacyLocalCleanupCoordinator {
  Future<void> cleanAfterServerConfirmation(PrivacyOperationType type);
}

final class PrivacyOperationController extends Notifier<PrivacyUiState> {
  int _requestEpoch = 0;

  @override
  PrivacyUiState build() => const PrivacyUiState.idle();

  void prepare(PrivacyOperationType type) {
    if (!state.isBusy) {
      state = PrivacyUiState._(status: PrivacyUiStatus.prepared, type: type);
    }
  }

  Future<void> submit({
    required PrivacyOperationType type,
    required String phrase,
    required PrivacyReauthenticationMethod method,
    String password = '',
  }) async {
    if (state.isBusy || phrase != type.confirmationPhrase) {
      state = PrivacyUiState._(
        status: PrivacyUiStatus.recoverableFailure,
        type: type,
        message: 'Digite a frase de confirmação exatamente como apresentada.',
      );
      return;
    }
    final int epoch = ++_requestEpoch;
    state = PrivacyUiState._(status: PrivacyUiStatus.processing, type: type);
    try {
      final AuthRepository auth = ref.read(authRepositoryProvider);
      final AuthReauthenticationOutcome outcome =
          method == PrivacyReauthenticationMethod.password
          ? await auth.reauthenticateWithPassword(password)
          : await auth.reauthenticateWithGoogle();
      if (epoch != _requestEpoch) {
        return;
      }
      if (outcome == AuthReauthenticationOutcome.cancelled) {
        state = PrivacyUiState._(
          status: PrivacyUiStatus.recoverableFailure,
          type: type,
          message: 'A confirmação de identidade foi cancelada.',
        );
        return;
      }
      final AuthVerificationSnapshot token = await auth
          .forceRefreshIdentityToken();
      if (epoch != _requestEpoch) {
        return;
      }
      if (!token.isFullyVerified) {
        state = PrivacyUiState._(
          status: PrivacyUiStatus.sessionLost,
          type: type,
          message:
              'Sua sessão não está disponível. Entre novamente para continuar.',
        );
        return;
      }
      final PrivacyOperation operation = await ref
          .read(privacyOperationRepositoryProvider)
          .request(
            PrivacyOperationStartCommand(
              type: type,
              confirmationPhrase: phrase,
              idempotencyKey: PrivacyIdempotencyKey(
                'privacy-client-request-${DateTime.now().microsecondsSinceEpoch}',
              ),
            ),
          );
      if (epoch != _requestEpoch) {
        return;
      }
      await ref.read(privacyOperationRepositoryProvider).status(operation.id);
      if (epoch != _requestEpoch) {
        return;
      }
      state = PrivacyUiState._(
        status: PrivacyUiStatus.processing,
        type: type,
        message: 'Aguardando confirmação segura do servidor.',
      );
    } on AuthFailure catch (failure) {
      if (epoch == _requestEpoch) {
        state = PrivacyUiState._(
          status: PrivacyUiStatus.recoverableFailure,
          type: type,
          message: failure.safeMessage,
        );
      }
    } on PrivacyOperationFailure catch (failure) {
      if (epoch == _requestEpoch) {
        state = PrivacyUiState._(
          status: PrivacyUiStatus.recoverableFailure,
          type: type,
          message: failure.safeMessage,
        );
      }
    } on Object {
      if (epoch == _requestEpoch) {
        state = PrivacyUiState._(
          status: PrivacyUiStatus.recoverableFailure,
          type: type,
          message: 'Não foi possível confirmar esta operação agora.',
        );
      }
    }
  }
}

final class _UnavailablePrivacyLocalCleanupCoordinator
    implements PrivacyLocalCleanupCoordinator {
  const _UnavailablePrivacyLocalCleanupCoordinator();
  @override
  Future<void> cleanAfterServerConfirmation(PrivacyOperationType type) =>
      Future<void>.error(
        const PrivacyOperationFailure(PrivacyOperationFailureKind.unavailable),
      );
}
