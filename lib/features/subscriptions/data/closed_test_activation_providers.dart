import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/data/firebase_closed_test_activation_repository.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/closed_test_activation_repository.dart';

final Provider<ClosedTestActivationRepository>
closedTestActivationRepositoryProvider =
    Provider<ClosedTestActivationRepository>(
      (Ref ref) => FirebaseClosedTestActivationRepository(
        functions: FirebaseFunctions.instanceFor(region: 'southamerica-east1'),
      ),
    );

final Provider<ClosedTestActivationCoordinator>
closedTestActivationCoordinatorProvider =
    Provider<ClosedTestActivationCoordinator>(
      (Ref ref) => ClosedTestActivationCoordinator(
        repository: ref.watch(closedTestActivationRepositoryProvider),
      ),
    );

/// Mantém no máximo uma chamada por UID durante a vida do processo. Falhas
/// também são memorizadas para impedir loops automáticos e múltiplos toques.
final class ClosedTestActivationCoordinator {
  ClosedTestActivationCoordinator({
    required ClosedTestActivationRepository repository,
  }) : _repository = repository;

  final ClosedTestActivationRepository _repository;
  final Map<String, Future<void>> _attempts = <String, Future<void>>{};

  Future<void> activateOnce({required String ownerId}) {
    if (ownerId.isEmpty || ownerId.contains('/')) {
      return Future<void>.error(
        const ClosedTestActivationFailure(
          kind: ClosedTestActivationFailureKind.notAuthorized,
          safeMessage: 'O acesso ao teste fechado não está disponível.',
          code: 'closed_test_invalid_local_owner',
        ),
      );
    }
    return _attempts.putIfAbsent(
      ownerId,
      () => Future<void>.sync(_repository.activateCurrentUser),
    );
  }
}
