import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/core/environment/app_environment.dart';
import 'package:meu_gestor_financeiro/features/authentication/data/auth_providers.dart';
import 'package:meu_gestor_financeiro/features/authentication/domain/auth_user.dart';
import 'package:meu_gestor_financeiro/features/investments/data/investment_providers.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_failure.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_income_event.dart';
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

  test(
    'cria, edita, recebe e anula provento com releitura do servidor',
    () async {
      final _Context context = await _context(withAsset: true);
      addTearDown(context.dispose);
      final InvestmentActionController controller = context.container.read(
        investmentActionControllerProvider.notifier,
      );
      expect(await controller.createIncomeEvent(_incomeDraft()), isTrue);
      InvestmentIncomeEvent event = context.container
          .read(investmentsControllerProvider)
          .requireValue
          .incomeEvents
          .single;
      expect(event.status, InvestmentIncomeStatus.expected);
      expect(
        await controller.updateExpectedIncomeEvent(
          event: event,
          draft: _incomeDraft(grossCents: 2000),
        ),
        isTrue,
      );
      event = context.container
          .read(investmentsControllerProvider)
          .requireValue
          .incomeEvents
          .single;
      expect(event.netAmountCents, 1850);
      expect(
        await controller.receiveIncomeEvent(
          event: event,
          receivedDate: DateTime.utc(2026, 8, 4, 3),
        ),
        isTrue,
      );
      event = context.container
          .read(investmentsControllerProvider)
          .requireValue
          .incomeEvents
          .single;
      expect(event.status, InvestmentIncomeStatus.received);
      expect(
        await controller.updateExpectedIncomeEvent(
          event: event,
          draft: _incomeDraft(grossCents: 3000),
        ),
        isFalse,
      );
      expect(await controller.voidIncomeEvent(event), isTrue);
      event = context.container
          .read(investmentsControllerProvider)
          .requireValue
          .incomeEvents
          .single;
      expect(event.status, InvestmentIncomeStatus.voided);
      expect(event.grossAmountCents, 2000);
    },
  );

  test('cancela previsão sem apagar histórico', () async {
    final _Context context = await _context(withAsset: true);
    addTearDown(context.dispose);
    final InvestmentActionController controller = context.container.read(
      investmentActionControllerProvider.notifier,
    );
    expect(await controller.createIncomeEvent(_incomeDraft()), isTrue);
    final InvestmentIncomeEvent event = context.container
        .read(investmentsControllerProvider)
        .requireValue
        .incomeEvents
        .single;
    expect(await controller.cancelIncomeEvent(event), isTrue);
    expect(
      context.repository.incomeEvents.single.status,
      InvestmentIncomeStatus.cancelled,
    );
    expect(context.repository.incomeEvents, hasLength(1));
  });

  test('retry de criação reutiliza ID sem duplicar provento', () async {
    final _Context context = await _context(withAsset: true);
    addTearDown(context.dispose);
    final InvestmentActionController controller = context.container.read(
      investmentActionControllerProvider.notifier,
    );
    context.repository.nextFailure = TimeoutException('teste');
    expect(await controller.createIncomeEvent(_incomeDraft()), isFalse);
    expect(await controller.createIncomeEvent(_incomeDraft()), isTrue);
    expect(context.repository.createIncomeIds, hasLength(2));
    expect(
      context.repository.createIncomeIds.first,
      context.repository.createIncomeIds.last,
    );
    expect(context.repository.incomeEvents, hasLength(1));
  });

  test('retry de confirmação reutiliza mutation ID', () async {
    final _Context context = await _context(withAsset: true);
    addTearDown(context.dispose);
    final InvestmentActionController controller = context.container.read(
      investmentActionControllerProvider.notifier,
    );
    expect(await controller.createIncomeEvent(_incomeDraft()), isTrue);
    final InvestmentIncomeEvent event = context.repository.incomeEvents.single;
    context.repository.nextFailure = TimeoutException('teste');
    expect(
      await controller.receiveIncomeEvent(
        event: event,
        receivedDate: DateTime.utc(2026, 8, 4, 3),
      ),
      isFalse,
    );
    expect(
      await controller.receiveIncomeEvent(
        event: event,
        receivedDate: DateTime.utc(2026, 8, 4, 3),
      ),
      isTrue,
    );
    expect(context.repository.incomeMutationIds, hasLength(2));
    expect(
      context.repository.incomeMutationIds.first,
      context.repository.incomeMutationIds.last,
    );
  });

  test('timeout após criar reconcilia sem duplicar o provento', () async {
    final _Context context = await _context(withAsset: true);
    addTearDown(context.dispose);
    final InvestmentActionController controller = context.container.read(
      investmentActionControllerProvider.notifier,
    );
    context.repository.nextIncomeFailureAfterWrite = TimeoutException('teste');
    expect(await controller.createIncomeEvent(_incomeDraft()), isFalse);
    expect(context.repository.incomeEvents, hasLength(1));
    expect(await controller.createIncomeEvent(_incomeDraft()), isTrue);
    expect(context.repository.incomeEvents, hasLength(1));
    expect(
      context.repository.createIncomeIds.first,
      context.repository.createIncomeIds.last,
    );
  });

  test('timeout após receber reconcilia a mesma transição', () async {
    final _Context context = await _context(withAsset: true);
    addTearDown(context.dispose);
    final InvestmentActionController controller = context.container.read(
      investmentActionControllerProvider.notifier,
    );
    expect(await controller.createIncomeEvent(_incomeDraft()), isTrue);
    final InvestmentIncomeEvent event = context.repository.incomeEvents.single;
    context.repository.nextIncomeFailureAfterWrite = TimeoutException('teste');
    expect(
      await controller.receiveIncomeEvent(
        event: event,
        receivedDate: DateTime.utc(2026, 8, 4, 3),
      ),
      isFalse,
    );
    expect(
      context.repository.incomeEvents.single.status,
      InvestmentIncomeStatus.received,
    );
    expect(
      await controller.receiveIncomeEvent(
        event: event,
        receivedDate: DateTime.utc(2026, 8, 4, 3),
      ),
      isTrue,
    );
    expect(
      context.repository.incomeMutationIds.first,
      context.repository.incomeMutationIds.last,
    );
  });

  test('bloqueia múltiplos toques em ação de provento', () async {
    final _Context context = await _context(withAsset: true);
    addTearDown(context.dispose);
    context.repository.incomeActionBarrier = Completer<void>();
    final InvestmentActionController controller = context.container.read(
      investmentActionControllerProvider.notifier,
    );
    final Future<bool> first = controller.createIncomeEvent(_incomeDraft());
    await Future<void>.delayed(Duration.zero);
    expect(await controller.createIncomeEvent(_incomeDraft()), isFalse);
    context.repository.incomeActionBarrier!.complete();
    expect(await first, isTrue);
    expect(context.repository.createIncomeIds, hasLength(1));
  });

  test('conflito de revisão impede segunda transição', () async {
    final _Context context = await _context(withAsset: true);
    addTearDown(context.dispose);
    final InvestmentActionController controller = context.container.read(
      investmentActionControllerProvider.notifier,
    );
    expect(await controller.createIncomeEvent(_incomeDraft()), isTrue);
    final InvestmentIncomeEvent stale = context.repository.incomeEvents.single;
    expect(await controller.cancelIncomeEvent(stale), isTrue);
    expect(await controller.cancelIncomeEvent(stale), isFalse);
  });

  test('descarta resposta tardia de provento após troca de sessão', () async {
    final _Context context = await _context(withAsset: true);
    addTearDown(context.dispose);
    context.repository.incomeActionBarrier = Completer<void>();
    final Future<bool> pending = context.container
        .read(investmentActionControllerProvider.notifier)
        .createIncomeEvent(_incomeDraft());
    await Future<void>.delayed(Duration.zero);
    context.auth.emit(null);
    await Future<void>.delayed(Duration.zero);
    context.repository.incomeActionBarrier!.complete();
    expect(await pending, isFalse);
  });

  test(
    'nega provento quando carteira está arquivada ou ativo é inválido',
    () async {
      final _Context context = await _context(withAsset: true);
      addTearDown(context.dispose);
      final InvestmentActionController controller = context.container.read(
        investmentActionControllerProvider.notifier,
      );
      final InvestmentPortfolio portfolio =
          context.repository.portfolios.single;
      expect(
        await controller.setPortfolioArchived(
          portfolio: portfolio,
          archived: true,
        ),
        isTrue,
      );
      expect(await controller.createIncomeEvent(_incomeDraft()), isFalse);
      expect(context.repository.incomeEvents, isEmpty);
    },
  );

  test(
    'entitlement encerrado não participa do fluxo gratuito de investimentos',
    () async {
      final _Context context = await _context();
      addTearDown(context.dispose);

      final bool success = await context.container
          .read(investmentActionControllerProvider.notifier)
          .createPortfolio(
            const InvestmentPortfolioDraft(name: 'Bloqueada', description: ''),
          );

      expect(success, isTrue);
      expect(context.repository.generatedIdCount, 1);
      expect(context.repository.createPortfolioCalls, 1);
    },
  );

  test('exclui somente carteira vazia e confirmada', () async {
    final _Context context = await _context();
    addTearDown(context.dispose);
    final InvestmentActionController controller = context.container.read(
      investmentActionControllerProvider.notifier,
    );
    expect(
      await controller.createPortfolio(
        const InvestmentPortfolioDraft(name: 'Temporária', description: ''),
      ),
      isTrue,
    );
    final InvestmentPortfolio portfolio = context.repository.portfolios.single;
    expect(await controller.deleteEmptyPortfolio(portfolio), isTrue);
    expect(context.repository.portfolios, isEmpty);
  });

  test('recusa exclusão de carteira com histórico', () async {
    final _Context context = await _context(withAsset: true);
    addTearDown(context.dispose);
    final InvestmentPortfolio portfolio = context.repository.portfolios.single;
    final bool success = await context.container
        .read(investmentActionControllerProvider.notifier)
        .deleteEmptyPortfolio(portfolio);
    expect(success, isFalse);
    expect(context.repository.portfolios, hasLength(1));
    expect(
      context.container.read(investmentActionControllerProvider).message,
      contains('possui histórico'),
    );
  });

  test('edita, arquiva, restaura e exclui ativo sem histórico', () async {
    final _Context context = await _context();
    addTearDown(context.dispose);
    final InvestmentActionController controller = context.container.read(
      investmentActionControllerProvider.notifier,
    );
    expect(
      await controller.createPortfolio(
        const InvestmentPortfolioDraft(name: 'Temporária', description: ''),
      ),
      isTrue,
    );
    final InvestmentPortfolio portfolio = context.repository.portfolios.single;
    expect(
      await controller.createAsset(
        TrackedInvestmentAssetDraft(
          portfolioId: portfolio.id,
          ticker: 'VALE3',
          name: 'Vale ON',
          type: TrackedInvestmentAssetType.stock,
        ),
      ),
      isTrue,
    );
    TrackedInvestmentAsset asset = context.repository.assets.single;
    expect(asset.hasHistory, isFalse);
    expect(
      await controller.updateAsset(
        asset: asset,
        update: const TrackedInvestmentAssetUpdate(
          name: 'Vale corrigida',
          type: TrackedInvestmentAssetType.fii,
        ),
      ),
      isTrue,
    );
    asset = context.repository.assets.single;
    expect(asset.name, 'Vale corrigida');
    expect(asset.type, TrackedInvestmentAssetType.fii);
    expect(
      await controller.setAssetArchived(asset: asset, archived: true),
      isTrue,
    );
    asset = context.repository.assets.single;
    expect(asset.isArchived, isTrue);
    expect(
      await controller.setAssetArchived(asset: asset, archived: false),
      isTrue,
    );
    asset = context.repository.assets.single;
    expect(await controller.deleteEmptyAsset(asset), isTrue);
    expect(context.repository.assets, isEmpty);
  });

  test(
    'ativo histórico permite correção de nome, mas não do tipo ou exclusão',
    () async {
      final _Context context = await _context(withAsset: true);
      addTearDown(context.dispose);
      final InvestmentActionController controller = context.container.read(
        investmentActionControllerProvider.notifier,
      );
      final TrackedInvestmentAsset asset = context.repository.assets.single;
      expect(
        await controller.updateAsset(
          asset: asset,
          update: TrackedInvestmentAssetUpdate(
            name: 'Nome corrigido',
            type: asset.type,
          ),
        ),
        isTrue,
      );
      final TrackedInvestmentAsset corrected = context.repository.assets.single;
      expect(corrected.name, 'Nome corrigido');
      expect(
        await controller.updateAsset(
          asset: corrected,
          update: const TrackedInvestmentAssetUpdate(
            name: 'Nome corrigido',
            type: TrackedInvestmentAssetType.fii,
          ),
        ),
        isFalse,
      );
      expect(await controller.deleteEmptyAsset(corrected), isFalse);
      expect(context.repository.assets, hasLength(1));
    },
  );
}

InvestmentIncomeDraft _incomeDraft({int grossCents = 1000}) =>
    InvestmentIncomeDraft(
      portfolioId: 'portfolio-1',
      assetId: 'portfolio-1__PETR4',
      type: InvestmentIncomeType.dividend,
      inputMode: InvestmentIncomeInputMode.total,
      exDate: null,
      expectedPaymentDate: DateTime.utc(2026, 9, 1, 3),
      eligibleQuantityScaled: null,
      unitAmountScaled: null,
      grossAmountCents: grossCents,
      withholdingTaxCents: 150,
      notes: '',
    );

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
