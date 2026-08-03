import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/core/dates/sao_paulo_civil_date.dart';
import 'package:meu_gestor_financeiro/core/environment/app_environment.dart';
import 'package:meu_gestor_financeiro/features/accounts/data/financial_account_providers.dart';
import 'package:meu_gestor_financeiro/features/accounts/domain/financial_account.dart';
import 'package:meu_gestor_financeiro/features/accounts/presentation/controllers/financial_accounts_controller.dart';
import 'package:meu_gestor_financeiro/features/authentication/data/auth_providers.dart';
import 'package:meu_gestor_financeiro/features/authentication/domain/auth_user.dart';
import 'package:meu_gestor_financeiro/features/commitments/domain/financial_commitment.dart';
import 'package:meu_gestor_financeiro/features/commitments/domain/financial_commitment_failure.dart';
import 'package:meu_gestor_financeiro/features/commitments/presentation/controllers/financial_commitment_action_controller.dart';
import 'package:meu_gestor_financeiro/features/commitments/presentation/controllers/financial_commitments_controller.dart';
import 'package:meu_gestor_financeiro/features/commitments/presentation/providers/financial_commitment_providers.dart';
import 'package:meu_gestor_financeiro/features/profile/data/user_profile_providers.dart';
import 'package:meu_gestor_financeiro/features/profile/presentation/controllers/profile_gate_controller.dart';
import 'package:meu_gestor_financeiro/features/transactions/data/financial_transaction_providers.dart';
import 'package:meu_gestor_financeiro/features/transactions/presentation/controllers/financial_transactions_controller.dart';

import '../../../support/fake_auth_repository.dart';
import '../../../support/fake_financial_account_repository.dart';
import '../../../support/fake_financial_commitment_repository.dart';
import '../../../support/fake_financial_transaction_repository.dart';
import '../../../support/fake_user_profile_repository.dart';
import '../../../support/financial_account_fixtures.dart';
import '../../../support/financial_commitment_fixtures.dart';
import '../../../support/profile_fixtures.dart';

void main() {
  final SaoPauloCivilDate today = SaoPauloCivilDate(
    year: 2026,
    month: 8,
    day: 15,
  );

  test('filtros distinguem pendente, atraso e estados finais', () {
    final FinancialCommitmentsState<Payable> state =
        FinancialCommitmentsState<Payable>(
          commitments: <Payable>[
            createTestPayable(
              id: 'overdue',
              dueDate: SaoPauloCivilDate(year: 2026, month: 8, day: 14),
            ),
            createTestPayable(
              id: 'pending',
              dueDate: SaoPauloCivilDate(year: 2026, month: 8, day: 15),
            ),
            createTestPayable(id: 'cancelled', status: PayableStatus.cancelled),
          ],
          isServerConfirmed: true,
        );
    expect(
      state
          .filtered(filter: FinancialCommitmentListFilter.overdue, today: today)
          .single
          .id,
      'overdue',
    );
    expect(
      state
          .filtered(filter: FinancialCommitmentListFilter.pending, today: today)
          .map((Payable item) => item.id),
      <String>['overdue', 'pending'],
    );
    expect(
      state
          .filtered(
            filter: FinancialCommitmentListFilter.cancelled,
            today: today,
          )
          .single
          .id,
      'cancelled',
    );
  });

  test('formulário aceita vencimento passado, presente e futuro', () {
    for (final SaoPauloCivilDate dueDate in <SaoPauloCivilDate>[
      SaoPauloCivilDate(year: 2026, month: 8, day: 14),
      SaoPauloCivilDate(year: 2026, month: 8, day: 15),
      SaoPauloCivilDate(year: 2027, month: 1, day: 1),
    ]) {
      expect(
        FinancialCommitmentDraft(
          description: 'Vencimento válido',
          categoryId: 'expense-category',
          amountCents: 100,
          dueDate: dueDate,
          notes: '',
        ).normalized().dueDate,
        dueDate,
      );
    }
  });

  test('lista recusa resultado não confirmado pelo servidor', () async {
    final _Context context = await _context(serverConfirmed: false);
    addTearDown(context.dispose);
    await Future<void>.delayed(Duration.zero);
    expect(
      context.container.read(payablesControllerProvider).error,
      isA<FinancialCommitmentFailure>(),
    );
  });

  test('múltiplos toques e retry incerto reutilizam o mesmo ID', () async {
    final _Context context = await _context();
    addTearDown(context.dispose);
    final FinancialCommitmentActionController controller = context.container
        .read(financialCommitmentActionControllerProvider.notifier);
    final Completer<void> barrier = Completer<void>();
    context.commitments.mutationBarrier = barrier;
    final FinancialCommitmentDraft draft = _draft();
    final Future<bool> first = controller.createPayable(draft);
    await Future<void>.delayed(Duration.zero);
    final Future<bool> second = controller.createPayable(draft);
    barrier.complete();
    expect(await first, isTrue);
    expect(await second, isFalse);
    expect(context.commitments.createCalls, 1);

    context.commitments.mutationBarrier = null;
    context.commitments.nextFailure = const FinancialCommitmentFailure(
      kind: FinancialCommitmentFailureKind.timeout,
      safeMessage: 'Tempo esgotado.',
      code: 'test_timeout',
    );
    expect(await controller.createPayable(draft), isFalse);
    expect(await controller.createPayable(draft), isTrue);
    expect(context.commitments.generatedPayableIds, 2);
  });

  test('liquidação cria um lançamento e atualiza saldo e resumo', () async {
    final _Context context = await _context(
      payables: <Payable>[createTestPayable()],
    );
    addTearDown(context.dispose);
    await context.startFinancialProviders();
    final bool success = await context.container
        .read(financialCommitmentActionControllerProvider.notifier)
        .settle(
          commitment: context.commitments.payables.single,
          accountId: 'account-1',
          movementDate: today,
        );
    expect(success, isTrue);
    expect(context.commitments.settleCalls, 1);
    expect(context.commitments.linkedTransactions, hasLength(1));
    expect(context.commitments.payables.single.isSettled, isTrue);
    expect(
      context.container
          .read(financialTransactionsControllerProvider)
          .requireValue
          .transactions,
      hasLength(1),
    );
    expect(
      context.container
          .read(financialSummaryProvider)
          .requireValue
          .totalCurrentBalance
          .cents,
      87500,
    );
  });

  test('cancelamento preserva registro e não cria lançamento', () async {
    final _Context context = await _context(
      receivables: <Receivable>[createTestReceivable()],
    );
    addTearDown(context.dispose);
    final bool success = await context.container
        .read(financialCommitmentActionControllerProvider.notifier)
        .cancelPending(context.commitments.receivables.single);
    expect(success, isTrue);
    expect(context.commitments.receivables, hasLength(1));
    expect(context.commitments.receivables.single.isCancelled, isTrue);
    expect(context.commitments.linkedTransactions, isEmpty);
  });

  test(
    'conectividade, timeout e conflito nunca produzem falso sucesso',
    () async {
      final _Context context = await _context(
        payables: <Payable>[createTestPayable()],
      );
      addTearDown(context.dispose);
      final FinancialCommitmentActionController controller = context.container
          .read(financialCommitmentActionControllerProvider.notifier);
      for (final FinancialCommitmentFailureKind kind
          in <FinancialCommitmentFailureKind>[
            FinancialCommitmentFailureKind.unavailable,
            FinancialCommitmentFailureKind.timeout,
            FinancialCommitmentFailureKind.conflict,
          ]) {
        context.commitments.nextFailure = FinancialCommitmentFailure(
          kind: kind,
          safeMessage: 'Falha controlada.',
          code: 'test_${kind.name}',
        );
        expect(
          await controller.cancelPending(context.commitments.payables.single),
          isFalse,
        );
        final FinancialCommitmentActionState state = context.container.read(
          financialCommitmentActionControllerProvider,
        );
        expect(state.status, FinancialCommitmentActionStatus.failure);
        expect(state.operationUncertain, isTrue);
        expect(state.message, contains('sem duplicar registros'));
        expect(context.commitments.payables.single.isPending, isTrue);
      }
    },
  );

  test('anulação invalida lançamento e recalcula o saldo', () async {
    final _Context context = await _context(
      receivables: <Receivable>[createTestReceivable()],
    );
    addTearDown(context.dispose);
    await context.startFinancialProviders();
    final FinancialCommitmentActionController controller = context.container
        .read(financialCommitmentActionControllerProvider.notifier);
    expect(
      await controller.settle(
        commitment: context.commitments.receivables.single,
        accountId: 'account-1',
        movementDate: today,
      ),
      isTrue,
    );
    final Receivable settled = context.commitments.receivables.single;
    expect(
      context.container
          .read(financialSummaryProvider)
          .requireValue
          .totalCurrentBalance
          .cents,
      125000,
    );
    expect(await controller.voidSettlement(settled), isTrue);
    expect(context.commitments.receivables.single.isVoided, isTrue);
    expect(context.commitments.linkedTransactions.single.isVoided, isTrue);
    expect(
      context.container
          .read(financialSummaryProvider)
          .requireValue
          .totalCurrentBalance
          .cents,
      100000,
    );
  });

  test('resposta tardia após dispose não publica sucesso', () async {
    final _Context context = await _context();
    final Completer<void> barrier = Completer<void>();
    context.commitments.mutationBarrier = barrier;
    final Future<bool> operation = context.container
        .read(financialCommitmentActionControllerProvider.notifier)
        .createReceivable(_draft());
    await Future<void>.delayed(Duration.zero);
    context.container.dispose();
    barrier.complete();
    expect(await operation, isFalse);
    await context.auth.close();
  });
}

FinancialCommitmentDraft _draft() => FinancialCommitmentDraft(
  description: 'Compromisso novo',
  categoryId: 'expense-category',
  amountCents: 1000,
  dueDate: SaoPauloCivilDate(year: 2026, month: 9, day: 1),
  notes: '',
);

final class _Context {
  const _Context({
    required this.container,
    required this.auth,
    required this.commitments,
    required this.subscriptions,
  });

  final ProviderContainer container;
  final FakeAuthRepository auth;
  final FakeFinancialCommitmentRepository commitments;
  final List<ProviderSubscription<dynamic>> subscriptions;

  Future<void> startFinancialProviders() async {
    await container.read(financialTransactionsControllerProvider.future);
    await container.read(financialAccountsControllerProvider.future);
  }

  void dispose() {
    for (final ProviderSubscription<dynamic> subscription in subscriptions) {
      subscription.close();
    }
    container.dispose();
    unawaited(auth.close());
  }
}

Future<_Context> _context({
  List<Payable>? payables,
  List<Receivable>? receivables,
  bool serverConfirmed = true,
}) async {
  final FakeAuthRepository auth = FakeAuthRepository(
    initialUser: const AuthUser(
      id: 'owner',
      displayName: 'Pessoa Teste',
      emailVerified: true,
    ),
  );
  final FakeFinancialCommitmentRepository commitments =
      FakeFinancialCommitmentRepository(
        initialPayables: payables,
        initialReceivables: receivables,
      );
  commitments.serverConfirmed = serverConfirmed;
  final ProviderContainer container = ProviderContainer(
    overrides: [
      appEnvironmentProvider.overrideWithValue(AppEnvironment.development),
      authRepositoryProvider.overrideWithValue(auth),
      userProfileRepositoryProvider.overrideWithValue(
        FakeUserProfileRepository(
          initialProfile: createTestProfile(ownerId: 'owner'),
        ),
      ),
      financialAccountRepositoryProvider.overrideWithValue(
        FakeFinancialAccountRepository(
          initialAccounts: <FinancialAccount>[createTestAccount()],
        ),
      ),
      financialTransactionRepositoryProvider.overrideWithValue(
        FakeFinancialTransactionRepository(),
      ),
      financialCommitmentRepositoryProvider.overrideWithValue(commitments),
      financialClockProvider.overrideWithValue(
        () => DateTime.utc(2026, 8, 15, 15),
      ),
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
  final List<ProviderSubscription<dynamic>> subscriptions =
      <ProviderSubscription<dynamic>>[
        gate,
        container.listen(
          financialCommitmentActionControllerProvider,
          (_, _) {},
        ),
        container.listen(payablesControllerProvider, (_, _) {}),
        container.listen(receivablesControllerProvider, (_, _) {}),
      ];
  return _Context(
    container: container,
    auth: auth,
    commitments: commitments,
    subscriptions: subscriptions,
  );
}
