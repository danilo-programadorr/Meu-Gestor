import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_gestor_financeiro/features/owner_access/data/master_access_diagnostics.dart';
import 'package:meu_gestor_financeiro/features/owner_access/data/master_access_providers.dart';
import 'package:meu_gestor_financeiro/features/owner_access/domain/master_access.dart';
import 'package:meu_gestor_financeiro/features/owner_access/domain/master_access_failure.dart';
import 'package:meu_gestor_financeiro/features/owner_access/domain/master_access_repository.dart';
import 'package:meu_gestor_financeiro/features/owner_access/presentation/controllers/master_access_state.dart';

final NotifierProvider<MasterAccessController, MasterAccessState>
masterAccessControllerProvider =
    NotifierProvider.autoDispose<MasterAccessController, MasterAccessState>(
      MasterAccessController.new,
    );

final Provider<Duration> masterAccessTimeoutProvider = Provider<Duration>(
  (Ref ref) => const Duration(seconds: 12),
);

final class MasterAccessController extends Notifier<MasterAccessState> {
  int _operationId = 0;
  bool _operationInProgress = false;
  bool _disposed = false;
  String? _activeUserId;

  MasterAccessRepository get _repository =>
      ref.read(masterAccessRepositoryProvider);
  MasterAccessDiagnostics get _diagnostics =>
      ref.read(masterAccessDiagnosticsProvider);

  @override
  MasterAccessState build() {
    ref.onDispose(() {
      _disposed = true;
      _operationId += 1;
      _operationInProgress = false;
      _activeUserId = null;
    });
    ref.listen<String?>(masterAccessSubjectProvider, (
      String? previous,
      String? next,
    ) {
      _handleSubject(next);
    });

    final String? userId = ref.read(masterAccessSubjectProvider);
    if (userId == null) {
      return MasterAccessState.regularUser();
    }
    _activeUserId = userId;
    Future<void>.microtask(() => _startValidation(userId));
    return MasterAccessState.idle();
  }

  Future<void> refresh() async {
    final String? userId = ref.read(masterAccessSubjectProvider);
    if (userId == null) {
      _clearAuthorization();
      return;
    }
    await _startValidation(userId);
  }

  void _handleSubject(String? userId) {
    if (userId == null) {
      _clearAuthorization();
      return;
    }
    if (userId == _activeUserId &&
        state.status != MasterAccessStatus.regularUser) {
      return;
    }
    _operationId += 1;
    _operationInProgress = false;
    _activeUserId = userId;
    unawaited(_startValidation(userId));
  }

  Future<void> _startValidation(String userId) async {
    if (_disposed || _operationInProgress) {
      return;
    }
    final int operationId = ++_operationId;
    _operationInProgress = true;
    _activeUserId = userId;
    state = MasterAccessState.loading();
    final Stopwatch stopwatch = Stopwatch()..start();
    try {
      final MasterAccessReadResult result = await _repository
          .readOwnAccess(userId: userId, serverOnly: true)
          .timeout(
            ref.read(masterAccessTimeoutProvider),
            onTimeout: () => throw const MasterAccessFailure(
              kind: MasterAccessFailureKind.timeout,
              safeMessage: 'A verificação administrativa demorou demais.',
              code: 'owner_access_timeout',
            ),
          );
      stopwatch.stop();
      if (!_isCurrent(operationId, userId)) {
        return;
      }
      final MasterAccessState nextState = _stateForResult(result);
      state = nextState;
      _diagnostics.record(
        operation: 'validate_owner_access',
        stage: 'server_confirmation',
        duration: stopwatch.elapsed,
        finalState: nextState.status.name,
      );
    } on MasterAccessFailure catch (failure) {
      stopwatch.stop();
      if (!_isCurrent(operationId, userId)) {
        return;
      }
      final MasterAccessState nextState = _stateForFailure(failure);
      state = nextState;
      _diagnostics.record(
        operation: 'validate_owner_access',
        stage: 'server_confirmation',
        duration: stopwatch.elapsed,
        finalState: nextState.status.name,
        error: failure,
        firestoreCode: failure.code,
      );
    } on Object catch (error) {
      stopwatch.stop();
      if (!_isCurrent(operationId, userId)) {
        return;
      }
      const MasterAccessFailure failure = MasterAccessFailure(
        kind: MasterAccessFailureKind.unknown,
        safeMessage: 'Não foi possível confirmar o acesso administrativo.',
        code: 'owner_access_unknown',
      );
      state = MasterAccessState.recoverableError(failure);
      _diagnostics.record(
        operation: 'validate_owner_access',
        stage: 'server_confirmation',
        duration: stopwatch.elapsed,
        finalState: MasterAccessStatus.recoverableError.name,
        error: error,
        firestoreCode: failure.code,
      );
    } finally {
      if (_isCurrent(operationId, userId)) {
        _operationInProgress = false;
      }
    }
  }

  MasterAccessState _stateForResult(MasterAccessReadResult result) {
    if (!result.isFromServer || result.hasPendingWrites) {
      return MasterAccessState.recoverableError(
        const MasterAccessFailure(
          kind: MasterAccessFailureKind.failedPrecondition,
          safeMessage:
              'Não foi possível confirmar o acesso administrativo com o servidor.',
          code: 'owner_access_server_confirmation_required',
        ),
      );
    }
    return switch (result.decision) {
      MasterAccessDecision.regularUser => MasterAccessState.regularUser(),
      MasterAccessDecision.revoked => MasterAccessState.revoked(),
      MasterAccessDecision.activeOwner => _activeOwnerState(result.access),
    };
  }

  MasterAccessState _activeOwnerState(MasterAccess? access) {
    if (access?.isActiveOwner == true) {
      return MasterAccessState.activeOwner();
    }
    return MasterAccessState.invalidDocument(
      const MasterAccessFailure(
        kind: MasterAccessFailureKind.incompatible,
        safeMessage:
            'A autorização administrativa possui uma configuração incompatível.',
        code: 'owner_access_not_active_owner',
      ),
    );
  }

  MasterAccessState _stateForFailure(MasterAccessFailure failure) {
    if (failure.kind == MasterAccessFailureKind.notFound) {
      return MasterAccessState.regularUser();
    }
    if (failure.kind == MasterAccessFailureKind.conversion ||
        failure.kind == MasterAccessFailureKind.incompatible ||
        failure.kind == MasterAccessFailureKind.dataLoss) {
      return MasterAccessState.invalidDocument(failure);
    }
    return MasterAccessState.recoverableError(failure);
  }

  void _clearAuthorization() {
    _operationId += 1;
    _operationInProgress = false;
    _activeUserId = null;
    state = MasterAccessState.regularUser();
  }

  bool _isCurrent(int operationId, String userId) =>
      !_disposed &&
      operationId == _operationId &&
      userId == _activeUserId &&
      ref.read(masterAccessSubjectProvider) == userId;
}
