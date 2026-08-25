import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_gestor_financeiro/app/routing/app_routes.dart';
import 'package:meu_gestor_financeiro/app/theme/app_theme_preference.dart';
import 'package:meu_gestor_financeiro/core/dates/sao_paulo_civil_date.dart';
import 'package:meu_gestor_financeiro/core/environment/app_environment.dart';
import 'package:meu_gestor_financeiro/core/privacy/financial_privacy_controller.dart';
import 'package:meu_gestor_financeiro/features/accounts/presentation/controllers/financial_accounts_controller.dart';
import 'package:meu_gestor_financeiro/features/categories/presentation/controllers/financial_categories_controller.dart';
import 'package:meu_gestor_financeiro/features/commitments/domain/financial_commitment.dart';
import 'package:meu_gestor_financeiro/features/commitments/presentation/controllers/financial_commitments_controller.dart';
import 'package:meu_gestor_financeiro/features/home/presentation/home_dashboard.dart';
import 'package:meu_gestor_financeiro/features/home/presentation/home_dashboard_filter.dart';
import 'package:meu_gestor_financeiro/features/profile/presentation/controllers/profile_gate_controller.dart';
import 'package:meu_gestor_financeiro/features/transactions/data/financial_transaction_providers.dart';
import 'package:meu_gestor_financeiro/features/transactions/presentation/controllers/financial_transactions_controller.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  HomeDashboardFilter? _filter;

  @override
  Widget build(BuildContext context) {
    final AppEnvironment environment = ref.watch(appEnvironmentProvider);
    final bool valuesVisible = ref.watch(financialPrivacyControllerProvider);
    final AsyncValue<FinancialWorkspace> workspace = ref.watch(
      financialWorkspaceProvider,
    );
    final AsyncValue<FinancialCommitmentsState<Payable>> payables = ref.watch(
      payablesControllerProvider,
    );
    final AsyncValue<FinancialCommitmentsState<Receivable>> receivables = ref
        .watch(receivablesControllerProvider);
    final AsyncValue<ProfileGateState> profileGate = ref.watch(
      profileGateControllerProvider,
    );
    final SaoPauloCivilDate today = SaoPauloCivilDate.fromInstant(
      ref.watch(financialClockProvider)().toUtc(),
    );
    final HomeDashboardFilter filter = _filter ??=
        HomeDashboardFilter.currentMonth(today);

    return Scaffold(
      body: SafeArea(
        child: HomeDashboardBody(
          firstName: _firstName(profileGate),
          environment: environment,
          valuesVisible: valuesVisible,
          workspace: workspace,
          payables: payables,
          receivables: receivables,
          today: today,
          filter: filter,
          onFilterChanged: (HomeDashboardFilter value) {
            setState(() => _filter = value);
          },
          onRefresh: _refreshAll,
          callbacks: HomeDashboardCallbacks(
            onToggleValues: () {
              ref.read(financialPrivacyControllerProvider.notifier).toggle();
            },
            onToggleTheme: _toggleTheme,
            onProfile: () => _push(AppRoutes.profile),
            onAppearance: () => _push(AppRoutes.profile),
            onAccounts: () => _push(AppRoutes.accounts),
            onCategories: () => _push(AppRoutes.categories),
            onTransactions: () => _push(AppRoutes.transactions),
            onNewIncome: () => _push(AppRoutes.newIncome),
            onNewExpense: () => _push(AppRoutes.newExpense),
            onNewPayable: () => _push(AppRoutes.newPayable),
            onNewReceivable: () => _push(AppRoutes.newReceivable),
            onPayables: () => _push(AppRoutes.payables),
            onReceivables: () => _push(AppRoutes.receivables),
            onInvestments: () => _push(AppRoutes.investments),
            onAssistant: () => _push(AppRoutes.assistant),
            onTransaction: (String transactionId) =>
                _push(AppRoutes.transactionDetails(transactionId)),
            onRetryWorkspace: _refreshWorkspace,
            onRetryCommitments: _refreshCommitments,
          ),
        ),
      ),
    );
  }

  void _push(String location) {
    context.push(location);
  }

  Future<void> _toggleTheme() async {
    final Brightness brightness = Theme.of(context).brightness;
    try {
      await ref
          .read(appThemePreferenceControllerProvider.notifier)
          .toggleQuickly(brightness);
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível salvar a aparência. Tente novamente.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _refreshAll() => Future.wait<void>(<Future<void>>[
    _refreshWorkspace(),
    _refreshCommitments(),
  ]);

  Future<void> _refreshWorkspace() => Future.wait<void>(<Future<void>>[
    ref.read(financialAccountsControllerProvider.notifier).refresh(),
    ref.read(financialCategoriesControllerProvider.notifier).refresh(),
    ref.read(financialTransactionsControllerProvider.notifier).refresh(),
  ]);

  Future<void> _refreshCommitments() => Future.wait<void>(<Future<void>>[
    ref.read(payablesControllerProvider.notifier).refresh(),
    ref.read(receivablesControllerProvider.notifier).refresh(),
  ]);
}

String? _firstName(AsyncValue<ProfileGateState> profileGate) {
  final ProfileGateState? state = profileGate.value;
  if (state is! ProfileGateValid) {
    return null;
  }
  final String normalized = state.profile.displayName.trim();
  if (normalized.isEmpty) {
    return null;
  }
  return normalized.split(RegExp(r'\s+')).first;
}
