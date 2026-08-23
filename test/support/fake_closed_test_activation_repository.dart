import 'dart:async';

import 'package:meu_gestor_financeiro/features/subscriptions/domain/closed_test_activation_repository.dart';

final class FakeClosedTestActivationRepository
    implements ClosedTestActivationRepository {
  int calls = 0;
  Object? failure;
  Completer<void>? barrier;
  void Function()? onActivate;

  @override
  Future<void> activateCurrentUser() async {
    calls += 1;
    await barrier?.future;
    final Object? currentFailure = failure;
    if (currentFailure != null) throw currentFailure;
    onActivate?.call();
  }
}
