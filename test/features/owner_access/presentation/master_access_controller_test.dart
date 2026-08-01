import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/core/environment/app_environment.dart';
import 'package:meu_gestor_financeiro/features/owner_access/data/firebase_master_access_repository.dart';
import 'package:meu_gestor_financeiro/features/owner_access/data/master_access_providers.dart';
import 'package:meu_gestor_financeiro/features/owner_access/domain/master_access_failure.dart';
import 'package:meu_gestor_financeiro/features/owner_access/domain/master_access_repository.dart';
import 'package:meu_gestor_financeiro/features/owner_access/presentation/controllers/master_access_controller.dart';
import 'package:meu_gestor_financeiro/features/owner_access/presentation/controllers/master_access_state.dart';

import '../../../support/fake_master_access_repository.dart';

final NotifierProvider<_SubjectController, String?> _subjectProvider =
    NotifierProvider<_SubjectController, String?>(_SubjectController.new);

final class _SubjectController extends Notifier<String?> {
  @override
  String? build() => 'test-user-a';

  void replace(String? value) => state = value;
}

void main() {
  test('11. caminho consulta somente system_admins/{uid}', () {
    expect(
      FirebaseMasterAccessRepository.documentPath('runtime-user'),
      'system_admins/runtime-user',
    );
  });

  test('12. repositório não oferece listagem de administradores', () {
    final MasterAccessRepository repository = FakeMasterAccessRepository();
    expect(repository.readOwnAccess, isA<Function>());
    expect(FirebaseMasterAccessRepository.collectionName, 'system_admins');
  });

  test('13. documento inexistente retorna regularUser', () {
    final result = FirebaseMasterAccessRepository.decodeReadSnapshot(
      exists: false,
      data: null,
      isFromCache: false,
      hasPendingWrites: false,
    );
    expect(result.decision, MasterAccessDecision.regularUser);
  });

  test('14. documento válido retorna activeOwner', () {
    final result = FakeMasterAccessRepository.activeOwnerResult();
    expect(result.decision, MasterAccessDecision.activeOwner);
    expect(result.access?.isActiveOwner, isTrue);
  });

  test('15. documento inativo retorna revoked', () {
    final result = FakeMasterAccessRepository.revokedResult();
    expect(result.decision, MasterAccessDecision.revoked);
    expect(result.access?.active, isFalse);
  });

  test('16. documento inválido não concede acesso', () async {
    final fake = FakeMasterAccessRepository()
      ..nextFailure = const MasterAccessFailure(
        kind: MasterAccessFailureKind.incompatible,
        safeMessage: 'Configuração incompatível.',
        code: 'invalid_document',
      );
    final _ControllerHarness harness = _controllerHarness(fake);
    addTearDown(harness.dispose);
    await harness.settle();
    expect(harness.state.status, MasterAccessStatus.invalidDocument);
    expect(harness.state.isActiveOwner, isFalse);
  });

  test('17. cache sem servidor não concede acesso', () async {
    final fake = FakeMasterAccessRepository(
      result: FakeMasterAccessRepository.activeOwnerResult(isFromServer: false),
    );
    final _ControllerHarness harness = _controllerHarness(fake);
    addTearDown(harness.dispose);
    await harness.settle();
    expect(harness.state.status, MasterAccessStatus.recoverableError);
    expect(harness.state.isActiveOwner, isFalse);
  });

  test('18. timeout não concede acesso', () async {
    final fake = FakeMasterAccessRepository()..barrier = Completer<void>();
    final _ControllerHarness harness = _controllerHarness(
      fake,
      timeout: Duration.zero,
    );
    addTearDown(harness.dispose);
    await harness.settle();
    expect(harness.state.status, MasterAccessStatus.recoverableError);
    expect(harness.state.failure?.kind, MasterAccessFailureKind.timeout);
  });

  test('19. permission-denied não concede acesso', () async {
    final fake = FakeMasterAccessRepository()
      ..nextFailure = const MasterAccessFailure(
        kind: MasterAccessFailureKind.permissionDenied,
        safeMessage: 'Acesso não confirmado.',
        code: 'permission-denied',
      );
    final _ControllerHarness harness = _controllerHarness(fake);
    addTearDown(harness.dispose);
    await harness.settle();
    expect(harness.state.status, MasterAccessStatus.recoverableError);
    expect(harness.state.isActiveOwner, isFalse);
  });

  test('20. unavailable permite retry', () async {
    final fake = FakeMasterAccessRepository()
      ..nextFailure = const MasterAccessFailure(
        kind: MasterAccessFailureKind.unavailable,
        safeMessage: 'Temporariamente indisponível.',
        code: 'unavailable',
      );
    final _ControllerHarness harness = _controllerHarness(fake);
    addTearDown(harness.dispose);
    await harness.settle();
    expect(harness.state.status, MasterAccessStatus.recoverableError);
    fake
      ..nextFailure = null
      ..result = FakeMasterAccessRepository.activeOwnerResult();
    await harness.controller.refresh();
    expect(harness.state.status, MasterAccessStatus.activeOwner);
  });

  test('21. logout invalida o estado', () async {
    final fake = FakeMasterAccessRepository(
      result: FakeMasterAccessRepository.activeOwnerResult(),
    );
    final _ControllerHarness harness = _controllerHarness(fake);
    addTearDown(harness.dispose);
    await harness.settle();
    expect(harness.state.isActiveOwner, isTrue);
    harness.subject.replace(null);
    await harness.settle();
    expect(harness.state.status, MasterAccessStatus.regularUser);
  });

  test('22. troca de usuário invalida e consulta o novo UID', () async {
    final fake = FakeMasterAccessRepository(
      result: FakeMasterAccessRepository.activeOwnerResult(),
    );
    final _ControllerHarness harness = _controllerHarness(fake);
    addTearDown(harness.dispose);
    await harness.settle();
    harness.subject.replace('test-user-b');
    await harness.settle();
    expect(
      fake.requestedUserIds,
      containsAllInOrder(<String>['test-user-a', 'test-user-b']),
    );
  });

  test('23. refresh revalida no servidor', () async {
    final fake = FakeMasterAccessRepository();
    final _ControllerHarness harness = _controllerHarness(fake);
    addTearDown(harness.dispose);
    await harness.settle();
    fake.result = FakeMasterAccessRepository.activeOwnerResult();
    await harness.controller.refresh();
    expect(fake.readCalls, 2);
    expect(fake.serverOnlyRequests, everyElement(isTrue));
    expect(harness.state.isActiveOwner, isTrue);
  });

  test('24. callbacks antigos são ignorados', () async {
    final _SequencedRepository repository = _SequencedRepository();
    final _ControllerHarness harness = _controllerHarness(repository);
    addTearDown(harness.dispose);
    await _flush();
    harness.subject.replace('test-user-b');
    await _flush();
    repository.second.complete(FakeMasterAccessRepository.regularUserResult());
    await _flush();
    repository.first.complete(FakeMasterAccessRepository.activeOwnerResult());
    await _flush();
    expect(harness.state.status, MasterAccessStatus.regularUser);
  });

  test('25. operações concorrentes são bloqueadas', () async {
    final Completer<void> barrier = Completer<void>();
    final fake = FakeMasterAccessRepository()..barrier = barrier;
    final _ControllerHarness harness = _controllerHarness(fake);
    addTearDown(harness.dispose);
    await _flush();
    unawaited(harness.controller.refresh());
    unawaited(harness.controller.refresh());
    await _flush();
    expect(fake.readCalls, 1);
    barrier.complete();
    await harness.settle();
  });
}

final class _ControllerHarness {
  _ControllerHarness(this.container, this.subscription);

  final ProviderContainer container;
  final ProviderSubscription<MasterAccessState> subscription;

  MasterAccessController get controller =>
      container.read(masterAccessControllerProvider.notifier);
  MasterAccessState get state => container.read(masterAccessControllerProvider);
  _SubjectController get subject => container.read(_subjectProvider.notifier);

  Future<void> settle() async {
    await _flush();
    await _flush();
  }

  void dispose() {
    subscription.close();
    container.dispose();
  }
}

_ControllerHarness _controllerHarness(
  MasterAccessRepository repository, {
  Duration timeout = const Duration(seconds: 12),
}) {
  final ProviderContainer container = ProviderContainer(
    overrides: [
      appEnvironmentProvider.overrideWithValue(AppEnvironment.development),
      masterAccessRepositoryProvider.overrideWithValue(repository),
      masterAccessSubjectProvider.overrideWith(
        (Ref ref) => ref.watch(_subjectProvider),
      ),
      masterAccessTimeoutProvider.overrideWithValue(timeout),
    ],
  );
  final ProviderSubscription<MasterAccessState> subscription = container
      .listen<MasterAccessState>(
        masterAccessControllerProvider,
        (MasterAccessState? previous, MasterAccessState next) {},
        fireImmediately: true,
      );
  return _ControllerHarness(container, subscription);
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

final class _SequencedRepository implements MasterAccessRepository {
  final Completer<MasterAccessReadResult> first =
      Completer<MasterAccessReadResult>();
  final Completer<MasterAccessReadResult> second =
      Completer<MasterAccessReadResult>();
  int calls = 0;

  @override
  Future<MasterAccessReadResult> readOwnAccess({
    required String userId,
    required bool serverOnly,
  }) {
    calls += 1;
    return calls == 1 ? first.future : second.future;
  }
}
