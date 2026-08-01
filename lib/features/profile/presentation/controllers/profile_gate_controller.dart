import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_gestor_financeiro/features/authentication/data/auth_providers.dart';
import 'package:meu_gestor_financeiro/features/authentication/domain/auth_failure.dart';
import 'package:meu_gestor_financeiro/features/authentication/domain/auth_repository.dart';
import 'package:meu_gestor_financeiro/features/authentication/domain/auth_user.dart';
import 'package:meu_gestor_financeiro/features/profile/data/profile_diagnostics.dart';
import 'package:meu_gestor_financeiro/features/profile/data/user_profile_providers.dart';
import 'package:meu_gestor_financeiro/features/profile/domain/user_profile.dart';
import 'package:meu_gestor_financeiro/features/profile/domain/user_profile_failure.dart';
import 'package:meu_gestor_financeiro/features/profile/domain/user_profile_repository.dart';

enum ProfileGateProgressPhase {
  idle,
  refreshingUser,
  refreshingToken,
  loadingProfile,
}

sealed class ProfileGateState {
  const ProfileGateState();

  bool get isTerminal => this is! ProfileGateProgress;

  String get diagnosticName => switch (this) {
    ProfileGateProgress(:final phase) => phase.name,
    ProfileGateUnauthenticated() => 'unauthenticated',
    ProfileGateUnverifiedEmail() => 'unverifiedEmail',
    ProfileGateMissing() => 'profileMissing',
    ProfileGateValid() => 'profileReady',
    ProfileGateLegalUpdateRequired() => 'legalUpdateRequired',
    ProfileGateFailure() => 'recoverableError',
    ProfileGateIncompatible() => 'incompatibleProfile',
  };
}

final class ProfileGateProgress extends ProfileGateState {
  const ProfileGateProgress(this.phase);

  final ProfileGateProgressPhase phase;
}

final class ProfileGateUnauthenticated extends ProfileGateState {
  const ProfileGateUnauthenticated();
}

final class ProfileGateUnverifiedEmail extends ProfileGateState {
  const ProfileGateUnverifiedEmail();
}

final class ProfileGateMissing extends ProfileGateState {
  const ProfileGateMissing({required this.suggestedDisplayName});

  final String? suggestedDisplayName;
}

final class ProfileGateValid extends ProfileGateState {
  const ProfileGateValid(this.profile);

  final UserProfile profile;
}

final class ProfileGateLegalUpdateRequired extends ProfileGateState {
  const ProfileGateLegalUpdateRequired(this.profile);

  final UserProfile profile;
}

final class ProfileGateFailure extends ProfileGateState {
  const ProfileGateFailure(this.failure);

  final UserProfileFailure failure;
}

final class ProfileGateIncompatible extends ProfileGateState {
  const ProfileGateIncompatible(this.failure);

  final UserProfileFailure failure;
}

final class ProfileGateTimeoutPolicy {
  const ProfileGateTimeoutPolicy({
    required this.refreshUser,
    required this.refreshToken,
    required this.readProfile,
  });

  const ProfileGateTimeoutPolicy.standard()
    : refreshUser = const Duration(seconds: 12),
      refreshToken = const Duration(seconds: 12),
      readProfile = const Duration(seconds: 12);

  final Duration refreshUser;
  final Duration refreshToken;
  final Duration readProfile;
}

final Provider<ProfileGateTimeoutPolicy> profileGateTimeoutPolicyProvider =
    Provider<ProfileGateTimeoutPolicy>(
      (Ref ref) => const ProfileGateTimeoutPolicy.standard(),
    );

final AsyncNotifierProvider<ProfileGateController, ProfileGateState>
profileGateControllerProvider =
    AsyncNotifierProvider.autoDispose<ProfileGateController, ProfileGateState>(
      ProfileGateController.new,
    );

final class ProfileGateController extends AsyncNotifier<ProfileGateState> {
  AuthRepository get _authRepository => ref.read(authRepositoryProvider);
  UserProfileRepository get _profileRepository =>
      ref.read(userProfileRepositoryProvider);
  ProfileDiagnostics get _diagnostics => ref.read(profileDiagnosticsProvider);
  ProfileGateTimeoutPolicy get _timeouts =>
      ref.read(profileGateTimeoutPolicyProvider);

  int _operationId = 0;
  bool _operationInProgress = false;
  String? _activeOwnerId;

  @override
  Future<ProfileGateState> build() async {
    ref.onDispose(() {
      _operationId += 1;
      _operationInProgress = false;
      _activeOwnerId = null;
    });
    ref.listen<AsyncValue<AuthUser?>>(authStateProvider, _onAuthStateChanged);

    final AuthUser? user = _authRepository.currentUser;
    if (user == null) {
      return const ProfileGateUnauthenticated();
    }
    if (!user.emailVerified) {
      return const ProfileGateUnverifiedEmail();
    }

    _activeOwnerId = user.id;
    final int operationId = ++_operationId;
    _operationInProgress = true;
    try {
      return await _loadFor(user, operationId);
    } finally {
      if (_isCurrent(operationId)) {
        _operationInProgress = false;
      }
    }
  }

  Future<void> retry() async {
    if (_operationInProgress) {
      return;
    }
    final AuthUser? user = _authRepository.currentUser;
    if (user == null) {
      _invalidateWith(const ProfileGateUnauthenticated());
      return;
    }
    if (!user.emailVerified) {
      _invalidateWith(const ProfileGateUnverifiedEmail());
      return;
    }
    await _restartFor(user);
  }

  void replaceProfile(UserProfile profile) {
    _operationId += 1;
    _operationInProgress = false;
    _activeOwnerId = profile.ownerId;
    state = AsyncData<ProfileGateState>(
      profile.hasCurrentLegalVersions
          ? ProfileGateValid(profile)
          : ProfileGateLegalUpdateRequired(profile),
    );
  }

  void _onAuthStateChanged(
    AsyncValue<AuthUser?>? previous,
    AsyncValue<AuthUser?> next,
  ) {
    if (next.hasError) {
      _invalidateWith(
        const ProfileGateFailure(
          UserProfileFailure(
            kind: UserProfileFailureKind.unauthenticated,
            safeMessage: 'Sua sessão não está disponível. Entre novamente.',
            code: 'PROFILE_SESSION_INVALID',
          ),
        ),
      );
      return;
    }
    if (next.isLoading) {
      return;
    }

    final AuthUser? user = next.value;
    if (user == null) {
      _invalidateWith(const ProfileGateUnauthenticated());
      return;
    }
    if (!user.emailVerified) {
      _activeOwnerId = user.id;
      _invalidateWith(const ProfileGateUnverifiedEmail());
      return;
    }
    if (_activeOwnerId == user.id) {
      return;
    }
    unawaited(_restartFor(user));
  }

  Future<void> _restartFor(AuthUser user) async {
    final int operationId = ++_operationId;
    _activeOwnerId = user.id;
    _operationInProgress = true;
    final ProfileGateState result = await _loadFor(user, operationId);
    if (_isCurrent(operationId)) {
      state = AsyncData<ProfileGateState>(result);
      _operationInProgress = false;
    }
  }

  Future<ProfileGateState> _loadFor(
    AuthUser initialUser,
    int operationId,
  ) async {
    try {
      _publishProgress(operationId, ProfileGateProgressPhase.refreshingUser);
      final AuthUser? refreshedUser = await _runStage<AuthUser?>(
        startStage: 'refresh-user-start',
        successStage: 'refresh-user-success',
        operationState: 'refreshingUser',
        timeout: _timeouts.refreshUser,
        operation: _authRepository.reloadCurrentUser,
      );
      if (!_isCurrent(operationId)) {
        return _currentState();
      }
      if (refreshedUser == null || refreshedUser.id != initialUser.id) {
        return const ProfileGateUnauthenticated();
      }
      if (!refreshedUser.emailVerified) {
        return const ProfileGateUnverifiedEmail();
      }

      _publishProgress(operationId, ProfileGateProgressPhase.refreshingToken);
      final AuthVerificationSnapshot verification =
          await _runStage<AuthVerificationSnapshot>(
            startStage: 'refresh-token-start',
            successStage: 'refresh-token-success',
            operationState: 'refreshingToken',
            timeout: _timeouts.refreshToken,
            operation: _authRepository.forceRefreshIdentityToken,
          );
      if (!_isCurrent(operationId)) {
        return _currentState();
      }
      if (verification.user == null ||
          verification.user?.id != initialUser.id) {
        return const ProfileGateUnauthenticated();
      }
      if (!verification.isFullyVerified) {
        return const ProfileGateUnverifiedEmail();
      }

      _publishProgress(operationId, ProfileGateProgressPhase.loadingProfile);
      final UserProfileReadResult result =
          await _runStage<UserProfileReadResult>(
            startStage: 'profile-read-start',
            successStage: null,
            errorStage: 'profile-read-error',
            operationState: 'loadingProfile',
            timeout: _timeouts.readProfile,
            operation: () => _profileRepository.readOwnProfile(
              ownerId: initialUser.id,
              serverOnly: true,
            ),
          );
      if (!_isCurrent(operationId)) {
        return _currentState();
      }
      if (!result.isFromServer || result.hasPendingWrites) {
        return const ProfileGateFailure(
          UserProfileFailure(
            kind: UserProfileFailureKind.failedPrecondition,
            safeMessage:
                'Não foi possível confirmar seu perfil com o servidor.',
            code: 'PROFILE_SERVER_CONFIRMATION_REQUIRED',
          ),
        );
      }

      final UserProfile? profile = result.profile;
      if (profile == null) {
        _diagnostics.recordGateEvent(
          stage: 'profile-not-found',
          duration: Duration.zero,
          finalState: 'profileMissing',
        );
        final String? suggestedName = verification.user?.displayName;
        return ProfileGateMissing(
          suggestedDisplayName: suggestedName == null || suggestedName.isEmpty
              ? null
              : suggestedName,
        );
      }

      final ProfileGateState finalState = profile.hasCurrentLegalVersions
          ? ProfileGateValid(profile)
          : ProfileGateLegalUpdateRequired(profile);
      _diagnostics.recordGateEvent(
        stage: 'profile-found',
        duration: Duration.zero,
        finalState: finalState.diagnosticName,
      );
      return finalState;
    } on _ProfileGateTimeout catch (error) {
      return ProfileGateFailure(
        UserProfileFailure(
          kind: UserProfileFailureKind.timeout,
          safeMessage: 'A verificação segura demorou demais. Tente novamente.',
          code: error.safeCode,
        ),
      );
    } on UserProfileFailure catch (failure) {
      final UserProfileFailure normalized = _normalizeProfileFailure(failure);
      if (_isIncompatible(normalized.kind)) {
        return ProfileGateIncompatible(normalized);
      }
      return ProfileGateFailure(normalized);
    } on AuthFailure catch (failure) {
      return ProfileGateFailure(
        UserProfileFailure(
          kind: failure.kind == AuthFailureKind.network
              ? UserProfileFailureKind.network
              : UserProfileFailureKind.unauthenticated,
          safeMessage: failure.safeMessage,
          code: failure.kind == AuthFailureKind.network
              ? 'PROFILE_AUTH_NETWORK'
              : 'PROFILE_SESSION_INVALID',
        ),
      );
    } on Object {
      return const ProfileGateFailure(
        UserProfileFailure(
          kind: UserProfileFailureKind.unknown,
          safeMessage:
              'Não foi possível verificar seu perfil. Tente novamente.',
          code: 'PROFILE_GATE_UNKNOWN',
        ),
      );
    }
  }

  Future<T> _runStage<T>({
    required String startStage,
    required String? successStage,
    String? errorStage,
    required String operationState,
    required Duration timeout,
    required Future<T> Function() operation,
  }) async {
    final Stopwatch stopwatch = Stopwatch()..start();
    _diagnostics.recordGateEvent(
      stage: startStage,
      duration: Duration.zero,
      finalState: operationState,
    );
    try {
      final T result = await operation().timeout(
        timeout,
        onTimeout: () => throw _ProfileGateTimeout(startStage),
      );
      stopwatch.stop();
      if (successStage != null) {
        _diagnostics.recordGateEvent(
          stage: successStage,
          duration: stopwatch.elapsed,
          finalState: operationState,
        );
      }
      return result;
    } on _ProfileGateTimeout catch (error) {
      stopwatch.stop();
      if (errorStage != null) {
        _diagnostics.recordGateEvent(
          stage: errorStage,
          duration: stopwatch.elapsed,
          finalState: 'recoverableError',
          error: error,
          errorCode: error.safeCode,
        );
      }
      _diagnostics.recordGateEvent(
        stage: 'gate-timeout',
        duration: stopwatch.elapsed,
        finalState: 'recoverableError',
        error: error,
        errorCode: error.safeCode,
      );
      rethrow;
    } on Object catch (error) {
      stopwatch.stop();
      if (errorStage != null) {
        _diagnostics.recordGateEvent(
          stage: errorStage,
          duration: stopwatch.elapsed,
          finalState: 'recoverableError',
          error: error,
          errorCode: _safeErrorCode(error),
        );
      }
      rethrow;
    }
  }

  void _publishProgress(int operationId, ProfileGateProgressPhase phase) {
    if (_isCurrent(operationId)) {
      state = AsyncData<ProfileGateState>(ProfileGateProgress(phase));
    }
  }

  void _invalidateWith(ProfileGateState value) {
    _operationId += 1;
    _operationInProgress = false;
    if (value is ProfileGateUnauthenticated) {
      _activeOwnerId = null;
    }
    state = AsyncData<ProfileGateState>(value);
  }

  bool _isCurrent(int operationId) => operationId == _operationId;

  ProfileGateState _currentState() =>
      state.value ?? const ProfileGateUnauthenticated();

  static bool _isIncompatible(UserProfileFailureKind kind) =>
      kind == UserProfileFailureKind.conversion ||
      kind == UserProfileFailureKind.incompatible ||
      kind == UserProfileFailureKind.dataLoss;

  static UserProfileFailure _normalizeProfileFailure(
    UserProfileFailure failure,
  ) {
    final String code = switch (failure.kind) {
      UserProfileFailureKind.permissionDenied => 'PROFILE_PERMISSION_DENIED',
      UserProfileFailureKind.unavailable => 'PROFILE_UNAVAILABLE',
      UserProfileFailureKind.timeout => 'PROFILE_GATE_TIMEOUT',
      UserProfileFailureKind.conversion ||
      UserProfileFailureKind.incompatible ||
      UserProfileFailureKind.dataLoss => 'PROFILE_DATA_INVALID',
      _ => failure.code ?? 'PROFILE_GATE_ERROR',
    };
    return UserProfileFailure(
      kind: failure.kind,
      safeMessage: failure.safeMessage,
      code: code,
    );
  }

  static String _safeErrorCode(Object error) => switch (error) {
    UserProfileFailure(:final code, :final kind) => code ?? kind.name,
    AuthFailure(:final kind) => kind.name,
    _ => 'PROFILE_GATE_ERROR',
  };
}

final class _ProfileGateTimeout implements Exception {
  const _ProfileGateTimeout(this.stage);

  final String stage;

  String get safeCode => 'PROFILE_GATE_TIMEOUT';

  @override
  String toString() => 'ProfileGateTimeout($stage)';
}
