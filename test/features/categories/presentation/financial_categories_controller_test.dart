import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/core/environment/app_environment.dart';
import 'package:meu_gestor_financeiro/features/authentication/data/auth_providers.dart';
import 'package:meu_gestor_financeiro/features/authentication/domain/auth_user.dart';
import 'package:meu_gestor_financeiro/features/categories/data/financial_category_providers.dart';
import 'package:meu_gestor_financeiro/features/categories/domain/financial_category.dart';
import 'package:meu_gestor_financeiro/features/categories/domain/financial_category_failure.dart';
import 'package:meu_gestor_financeiro/features/categories/presentation/controllers/financial_categories_controller.dart';
import 'package:meu_gestor_financeiro/features/categories/presentation/controllers/financial_category_action_controller.dart';
import 'package:meu_gestor_financeiro/features/profile/data/user_profile_providers.dart';
import 'package:meu_gestor_financeiro/features/profile/presentation/controllers/profile_gate_controller.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_financial_category_repository.dart';
import '../../../support/fake_user_profile_repository.dart';
import '../../../support/financial_category_fixtures.dart';
import '../../../support/profile_fixtures.dart';

void main() {
  test(
    'carrega apenas confirmação do servidor e separa ativas de arquivadas',
    () async {
      final _Context context = await _context(
        categories: <FinancialCategory>[
          createTestCategory(),
          createTestCategory(id: 'archived', isArchived: true),
        ],
      );
      addTearDown(context.dispose);
      final FinancialCategoriesState state = await context.container.read(
        financialCategoriesControllerProvider.future,
      );
      expect(state.activeCategories, hasLength(1));
      expect(state.archivedCategories, hasLength(1));
      expect(state.isServerConfirmed, isTrue);
    },
  );

  test('cache ou escrita pendente bloqueia a lista', () async {
    final _Context context = await _context(
      serverConfirmed: false,
      awaitList: false,
    );
    addTearDown(context.dispose);
    await Future<void>.delayed(Duration.zero);
    expect(
      context.container.read(financialCategoriesControllerProvider).error,
      isA<FinancialCategoryFailure>(),
    );
  });

  test('múltiplos toques criam uma categoria e retry reutiliza o ID', () async {
    final _Context context = await _context();
    addTearDown(context.dispose);
    final Completer<void> barrier = Completer<void>();
    context.categories.mutationBarrier = barrier;
    final FinancialCategoryActionController controller = context.container.read(
      financialCategoryActionControllerProvider.notifier,
    );
    const FinancialCategoryDraft draft = FinancialCategoryDraft(
      name: 'Salário',
      kind: FinancialCategoryKind.income,
      icon: FinancialCategoryIcon.salary,
      color: FinancialCategoryColor.green,
    );
    final Future<void> first = controller.create(draft);
    await Future<void>.delayed(Duration.zero);
    final Future<void> second = controller.create(draft);
    barrier.complete();
    await Future.wait(<Future<void>>[first, second]);
    expect(context.categories.createCalls, 1);
    expect(context.categories.generatedIdCalls, 1);

    context.categories.nextFailure = const FinancialCategoryFailure(
      kind: FinancialCategoryFailureKind.unavailable,
      safeMessage: 'Indisponível.',
    );
    await controller.create(draft);
    await controller.create(draft);
    expect(context.categories.generatedIdCalls, 2);
    expect(context.categories.categories, hasLength(2));
  });
}

final class _Context {
  const _Context({
    required this.container,
    required this.auth,
    required this.categories,
    required this.gate,
    required this.action,
    required this.list,
  });

  final ProviderContainer container;
  final FakeAuthRepository auth;
  final FakeFinancialCategoryRepository categories;
  final ProviderSubscription<AsyncValue<ProfileGateState>> gate;
  final ProviderSubscription<FinancialCategoryActionState> action;
  final ProviderSubscription<AsyncValue<FinancialCategoriesState>> list;

  void dispose() {
    action.close();
    list.close();
    gate.close();
    container.dispose();
    unawaited(auth.close());
  }
}

Future<_Context> _context({
  List<FinancialCategory>? categories,
  bool serverConfirmed = true,
  bool awaitList = true,
}) async {
  final FakeAuthRepository auth = FakeAuthRepository(
    initialUser: const AuthUser(
      id: 'owner',
      displayName: 'Pessoa Teste',
      emailVerified: true,
    ),
  );
  final FakeFinancialCategoryRepository repository =
      FakeFinancialCategoryRepository(initialCategories: categories);
  repository.serverConfirmed = serverConfirmed;
  final ProviderContainer container = ProviderContainer(
    overrides: [
      appEnvironmentProvider.overrideWithValue(AppEnvironment.development),
      authRepositoryProvider.overrideWithValue(auth),
      userProfileRepositoryProvider.overrideWithValue(
        FakeUserProfileRepository(
          initialProfile: createTestProfile(ownerId: 'owner'),
        ),
      ),
      financialCategoryRepositoryProvider.overrideWithValue(repository),
    ],
  );
  final Completer<void> ready = Completer<void>();
  final ProviderSubscription<AsyncValue<ProfileGateState>> gate = container
      .listen(profileGateControllerProvider, (
        _,
        AsyncValue<ProfileGateState> next,
      ) {
        if (next.value?.isTerminal == true && !ready.isCompleted) {
          ready.complete();
        }
      }, fireImmediately: true);
  await ready.future.timeout(const Duration(seconds: 2));
  final ProviderSubscription<FinancialCategoryActionState> action = container
      .listen(
        financialCategoryActionControllerProvider,
        (
          FinancialCategoryActionState? previous,
          FinancialCategoryActionState next,
        ) {},
      );
  final ProviderSubscription<AsyncValue<FinancialCategoriesState>> list =
      container.listen(
        financialCategoriesControllerProvider,
        (
          AsyncValue<FinancialCategoriesState>? previous,
          AsyncValue<FinancialCategoriesState> next,
        ) {},
      );
  if (awaitList) {
    await container.read(financialCategoriesControllerProvider.future);
  }
  return _Context(
    container: container,
    auth: auth,
    categories: repository,
    gate: gate,
    action: action,
    list: list,
  );
}
