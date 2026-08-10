import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/core/environment/app_environment.dart';
import 'package:meu_gestor_financeiro/features/authentication/data/auth_providers.dart';
import 'package:meu_gestor_financeiro/features/authentication/domain/auth_user.dart';
import 'package:meu_gestor_financeiro/features/investments/data/investment_providers.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_failure.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_operation.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_portfolio.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/tracked_investment_asset.dart';
import 'package:meu_gestor_financeiro/features/investments/presentation/controllers/investment_action_controller.dart';
import 'package:meu_gestor_financeiro/features/investments/presentation/controllers/investments_controller.dart';
import 'package:meu_gestor_financeiro/features/profile/data/user_profile_providers.dart';
import 'package:meu_gestor_financeiro/features/profile/presentation/controllers/profile_gate_controller.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_investment_repository.dart';
import '../../../support/fake_user_profile_repository.dart';
import '../../../support/profile_fixtures.dart';

void main() {
  test('carrega somente estado confirmado pelo servidor', () async {
    final _Context context = await _context();
    addTearDown(context.dispose);
    context.repository.serverConfirmed = false;
    await context.container
        .read(investmentsControllerProvider.notifier)
        .refresh();
    final AsyncValue<InvestmentsState> state = context.container.read(
      investmentsControllerProvider,
    );
    expect(state.hasError, isTrue);
    expect(state.error, isA<InvestmentFailure>());
  });

  test('cria carteira, relê servidor e publica sucesso', () async {
    final _Context context = await _context();
    addTearDown(context.dispose);
    final bool success = await context.container
        .read(investmentActionControllerProvider.notifier)
        .createPortfolio(
          const InvestmentPortfolioDraft(name: 'Longo prazo', description: ''),
        );
    expect(success, isTrue);
    expect(context.repository.createPortfolioCalls, 1);
    expect(context.repository.readCalls, 2);
    expect(
      context.container.read(investmentActionControllerProvider).status,
      InvestmentActionStatus.success,
    );
    expect(
      context.container
          .read(investmentsControllerProvider)
          .requireValue
          .portfolios
          .single
          .name,
      'Longo prazo',
    );
  });

  test(
    'bloqueia múltiplos toques enquanto a gravação está em andamento',
    () async {
      final _Context context = await _context();
      addTearDown(context.dispose);
      context.repository.createPortfolioBarrier = Completer<void>();
      final InvestmentActionController controller = context.container.read(
        investmentActionControllerProvider.notifier,
      );
      final Future<bool> first = controller.createPortfolio(
        const InvestmentPortfolioDraft(name: 'Longo prazo', description: ''),
      );
      await Future<void>.delayed(Duration.zero);
      final bool second = await controller.createPortfolio(
        const InvestmentPortfolioDraft(name: 'Outra', description: ''),
      );
      expect(second, isFalse);
      expect(context.repository.createPortfolioCalls, 1);
      context.repository.createPortfolioBarrier!.complete();
      expect(await first, isTrue);
    },
  );

  test(
    'edita, arquiva e restaura carteira com releitura do servidor',
    () async {
      final _Context context = await _context();
      addTearDown(context.dispose);
      final InvestmentActionController controller = context.container.read(
        investmentActionControllerProvider.notifier,
      );
      expect(
        await controller.createPortfolio(
          const InvestmentPortfolioDraft(name: 'Inicial', description: ''),
        ),
        isTrue,
      );
      InvestmentPortfolio portfolio = context.container
          .read(investmentsControllerProvider)
          .requireValue
          .portfolios
          .single;
      expect(
        await controller.updatePortfolio(
          portfolio: portfolio,
          draft: const InvestmentPortfolioDraft(
            name: 'Longo prazo',
            description: 'Corretora manual',
          ),
        ),
        isTrue,
      );
      portfolio = context.container
          .read(investmentsControllerProvider)
          .requireValue
          .portfolios
          .single;
      expect(
        await controller.setPortfolioArchived(
          portfolio: portfolio,
          archived: true,
        ),
        isTrue,
      );
      portfolio = context.container
          .read(investmentsControllerProvider)
          .requireValue
          .portfolios
          .single;
      expect(portfolio.isArchived, isTrue);
      expect(
        await controller.setPortfolioArchived(
          portfolio: portfolio,
          archived: false,
        ),
        isTrue,
      );
      expect(
        context.container
            .read(investmentsControllerProvider)
            .requireValue
            .portfolios
            .single
            .isArchived,
        isFalse,
      );
    },
  );

  test('registra e anula operação atualizando a projeção confirmada', () async {
    final _Context context = await _context(withAsset: true);
    addTearDown(context.dispose);
    final InvestmentActionController controller = context.container.read(
      investmentActionControllerProvider.notifier,
    );
    expect(
      await controller.createOperation(
        InvestmentOperationDraft(
          portfolioId: 'portfolio-1',
          assetId: 'portfolio-1__PETR4',
          kind: InvestmentOperationKind.buy,
          occurredAt: DateTime.utc(2026, 8, 3, 3),
          quantityScaled: 100000000,
          unitPriceScaled: 32000000,
          feesCents: 25,
          notes: '',
        ),
      ),
      isTrue,
    );
    InvestmentsState workspace = context.container
        .read(investmentsControllerProvider)
        .requireValue;
    expect(workspace.assets.single.currentQuantityScaled, 100000000);
    expect(await controller.voidOperation(workspace.operations.single), isTrue);
    workspace = context.container
        .read(investmentsControllerProvider)
        .requireValue;
    expect(workspace.assets.single.currentQuantityScaled, 0);
    expect(workspace.operations.single.isVoided, isTrue);
  });

  test('retry após timeout reutiliza o mesmo ID da tentativa', () async {
    final _Context context = await _context();
    addTearDown(context.dispose);
    final InvestmentActionController controller = context.container.read(
      investmentActionControllerProvider.notifier,
    );
    context.repository.nextFailure = TimeoutException('teste');
    expect(
      await controller.createPortfolio(
        const InvestmentPortfolioDraft(name: 'Longo prazo', description: ''),
      ),
      isFalse,
    );
    expect(
      context.container
          .read(investmentActionControllerProvider)
          .operationUncertain,
      isTrue,
    );
    expect(
      await controller.createPortfolio(
        const InvestmentPortfolioDraft(name: 'Longo prazo', description: ''),
      ),
      isTrue,
    );
    expect(context.repository.createPortfolioIds, hasLength(2));
    expect(
      context.repository.createPortfolioIds.first,
      context.repository.createPortfolioIds.last,
    );
  });

  test('retry de operação reutiliza o ID e não duplica o registro', () async {
    final _Context context = await _context(withAsset: true);
    addTearDown(context.dispose);
    final InvestmentActionController controller = context.container.read(
      investmentActionControllerProvider.notifier,
    );
    final InvestmentOperationDraft draft = InvestmentOperationDraft(
      portfolioId: 'portfolio-1',
      assetId: 'portfolio-1__PETR4',
      kind: InvestmentOperationKind.buy,
      occurredAt: DateTime.utc(2026, 8, 3, 3),
      quantityScaled: 100000000,
      unitPriceScaled: 32000000,
      feesCents: 0,
      notes: '',
    );
    context.repository.nextFailure = TimeoutException('teste');
    expect(await controller.createOperation(draft), isFalse);
    expect(await controller.createOperation(draft), isTrue);
    expect(context.repository.createOperationIds, hasLength(2));
    expect(
      context.repository.createOperationIds.first,
      context.repository.createOperationIds.last,
    );
    expect(context.repository.operations, hasLength(1));
  });

  test(
    'retry de anulação reutiliza mutation ID e preserva o histórico',
    () async {
      final _Context context = await _context(withAsset: true);
      addTearDown(context.dispose);
      final InvestmentActionController controller = context.container.read(
        investmentActionControllerProvider.notifier,
      );
      expect(
        await controller.createOperation(
          InvestmentOperationDraft(
            portfolioId: 'portfolio-1',
            assetId: 'portfolio-1__PETR4',
            kind: InvestmentOperationKind.buy,
            occurredAt: DateTime.utc(2026, 8, 3, 3),
            quantityScaled: 100000000,
            unitPriceScaled: 32000000,
            feesCents: 0,
            notes: '',
          ),
        ),
        isTrue,
      );
      final InvestmentOperation operation = context.container
          .read(investmentsControllerProvider)
          .requireValue
          .operations
          .single;
      context.repository.nextFailure = TimeoutException('teste');
      expect(await controller.voidOperation(operation), isFalse);
      expect(await controller.voidOperation(operation), isTrue);
      expect(context.repository.voidMutationIds, hasLength(2));
      expect(
        context.repository.voidMutationIds.first,
        context.repository.voidMutationIds.last,
      );
      expect(context.repository.operations.single.isVoided, isTrue);
    },
  );

  test('ignora resposta tardia depois da troca de sessão', () async {
    final _Context context = await _context();
    addTearDown(context.dispose);
    context.repository.createPortfolioBarrier = Completer<void>();
    final Future<bool> pending = context.container
        .read(investmentActionControllerProvider.notifier)
        .createPortfolio(
          const InvestmentPortfolioDraft(name: 'Longo prazo', description: ''),
        );
    await Future<void>.delayed(Duration.zero);
    context.auth.emit(null);
    await Future<void>.delayed(Duration.zero);
    context.repository.createPortfolioBarrier!.complete();
    expect(await pending, isFalse);
  });

  test(
    'não anuncia sucesso quando a confirmação por releitura falha',
    () async {
      final _Context context = await _context();
      addTearDown(context.dispose);
      context.repository.nextReadFailure = const InvestmentFailure(
        kind: InvestmentFailureKind.unavailable,
        safeMessage: 'Servidor indisponível.',
        code: 'test_unavailable',
      );
      final bool success = await context.container
          .read(investmentActionControllerProvider.notifier)
          .createPortfolio(
            const InvestmentPortfolioDraft(
              name: 'Longo prazo',
              description: '',
            ),
          );
      expect(success, isFalse);
      expect(
        context.container.read(investmentActionControllerProvider).status,
        InvestmentActionStatus.failure,
      );
    },
  );
}

final class _Context {
  const _Context({
    required this.container,
    required this.auth,
    required this.repository,
    required this.gate,
    required this.investments,
    required this.action,
  });

  final ProviderContainer container;
  final FakeAuthRepository auth;
  final FakeInvestmentRepository repository;
  final ProviderSubscription<AsyncValue<ProfileGateState>> gate;
  final ProviderSubscription<AsyncValue<InvestmentsState>> investments;
  final ProviderSubscription<InvestmentActionState> action;

  void dispose() {
    action.close();
    investments.close();
    gate.close();
    container.dispose();
    unawaited(auth.close());
  }
}

Future<_Context> _context({bool withAsset = false}) async {
  final FakeAuthRepository auth = FakeAuthRepository(
    initialUser: const AuthUser(
      id: 'owner',
      displayName: 'Pessoa Teste',
      emailVerified: true,
    ),
  );
  final FakeInvestmentRepository repository = FakeInvestmentRepository();
  if (withAsset) {
    final DateTime now = DateTime.utc(2026, 8, 4, 12);
    repository.portfolios.add(
      InvestmentPortfolio(
        id: 'portfolio-1',
        ownerId: 'owner',
        name: 'Longo prazo',
        description: '',
        isArchived: false,
        archivedAt: null,
        createdAt: now,
        updatedAt: now,
        schemaVersion: 1,
        revision: 1,
      ),
    );
    repository.assets.add(
      TrackedInvestmentAsset(
        id: 'portfolio-1__PETR4',
        ownerId: 'owner',
        portfolioId: 'portfolio-1',
        ticker: 'PETR4',
        name: 'Petrobras PN',
        type: TrackedInvestmentAssetType.stock,
        currencyCode: 'BRL',
        currentQuantityScaled: 0,
        lastOperationId: null,
        lastOperationAt: null,
        createdAt: now,
        updatedAt: now,
        schemaVersion: 1,
        revision: 1,
      ),
    );
  }
  final ProviderContainer container = ProviderContainer(
    overrides: [
      appEnvironmentProvider.overrideWithValue(AppEnvironment.development),
      authRepositoryProvider.overrideWithValue(auth),
      userProfileRepositoryProvider.overrideWithValue(
        FakeUserProfileRepository(
          initialProfile: createTestProfile(ownerId: 'owner'),
        ),
      ),
      investmentRepositoryProvider.overrideWithValue(repository),
    ],
  );
  final Completer<void> gateReady = Completer<void>();
  final ProviderSubscription<AsyncValue<ProfileGateState>> gate = container
      .listen(profileGateControllerProvider, (
        AsyncValue<ProfileGateState>? previous,
        AsyncValue<ProfileGateState> next,
      ) {
        if (next.value?.isTerminal == true && !gateReady.isCompleted) {
          gateReady.complete();
        }
      }, fireImmediately: true);
  await gateReady.future.timeout(const Duration(seconds: 2));
  final Completer<void> investmentsReady = Completer<void>();
  final ProviderSubscription<AsyncValue<InvestmentsState>> investments =
      container.listen(investmentsControllerProvider, (_, next) {
        if (!next.isLoading && !investmentsReady.isCompleted) {
          investmentsReady.complete();
        }
      }, fireImmediately: true);
  await investmentsReady.future.timeout(const Duration(seconds: 2));
  final ProviderSubscription<InvestmentActionState> action = container.listen(
    investmentActionControllerProvider,
    (_, _) {},
  );
  return _Context(
    container: container,
    auth: auth,
    repository: repository,
    gate: gate,
    investments: investments,
    action: action,
  );
}
