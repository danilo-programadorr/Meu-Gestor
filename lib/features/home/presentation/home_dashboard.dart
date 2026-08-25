import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:meu_gestor_financeiro/app/theme/app_radius.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
import 'package:meu_gestor_financeiro/app/theme/app_theme_colors.dart';
import 'package:meu_gestor_financeiro/core/dates/sao_paulo_civil_date.dart';
import 'package:meu_gestor_financeiro/core/environment/app_environment.dart';
import 'package:meu_gestor_financeiro/core/money/money.dart';
import 'package:meu_gestor_financeiro/core/money/money_formatter.dart';
import 'package:meu_gestor_financeiro/features/accounts/domain/financial_account.dart';
import 'package:meu_gestor_financeiro/features/categories/domain/financial_category.dart';
import 'package:meu_gestor_financeiro/features/commitments/domain/financial_commitment.dart';
import 'package:meu_gestor_financeiro/features/commitments/presentation/controllers/financial_commitments_controller.dart';
import 'package:meu_gestor_financeiro/features/home/presentation/home_dashboard_analytics.dart';
import 'package:meu_gestor_financeiro/features/home/presentation/home_dashboard_filter.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_balance_calculator.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_transaction.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_transaction_date.dart';
import 'package:meu_gestor_financeiro/features/transactions/presentation/controllers/financial_transactions_controller.dart';

final class HomeDashboardCallbacks {
  const HomeDashboardCallbacks({
    required this.onToggleValues,
    this.onToggleTheme,
    required this.onProfile,
    this.onAppearance,
    required this.onAccounts,
    required this.onCategories,
    required this.onTransactions,
    required this.onNewIncome,
    required this.onNewExpense,
    required this.onNewPayable,
    required this.onNewReceivable,
    required this.onPayables,
    required this.onReceivables,
    required this.onInvestments,
    required this.onAssistant,
    required this.onTransaction,
    required this.onRetryWorkspace,
    required this.onRetryCommitments,
  });

  final VoidCallback onToggleValues;
  final VoidCallback? onToggleTheme;
  final VoidCallback onProfile;
  final VoidCallback? onAppearance;
  final VoidCallback onAccounts;
  final VoidCallback onCategories;
  final VoidCallback onTransactions;
  final VoidCallback onNewIncome;
  final VoidCallback onNewExpense;
  final VoidCallback onNewPayable;
  final VoidCallback onNewReceivable;
  final VoidCallback onPayables;
  final VoidCallback onReceivables;
  final VoidCallback onInvestments;
  final VoidCallback onAssistant;
  final ValueChanged<String> onTransaction;
  final VoidCallback onRetryWorkspace;
  final VoidCallback onRetryCommitments;
}

class HomeDashboardBody extends StatelessWidget {
  const HomeDashboardBody({
    required this.firstName,
    required this.environment,
    required this.valuesVisible,
    required this.workspace,
    required this.payables,
    required this.receivables,
    required this.today,
    required this.callbacks,
    required this.onRefresh,
    this.filter,
    this.onFilterChanged,
    super.key,
  });

  final String? firstName;
  final AppEnvironment environment;
  final bool valuesVisible;
  final AsyncValue<FinancialWorkspace> workspace;
  final AsyncValue<FinancialCommitmentsState<Payable>> payables;
  final AsyncValue<FinancialCommitmentsState<Receivable>> receivables;
  final SaoPauloCivilDate today;
  final HomeDashboardFilter? filter;
  final ValueChanged<HomeDashboardFilter>? onFilterChanged;
  final HomeDashboardCallbacks callbacks;
  final RefreshCallback onRefresh;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      final double horizontal = constraints.maxWidth <= 360
          ? AppSpacing.compactPageHorizontal
          : AppSpacing.pageHorizontal;
      final Widget content;
      if (workspace.hasError) {
        content = _WorkspaceError(
          firstName: firstName,
          environment: environment,
          valuesVisible: valuesVisible,
          callbacks: callbacks,
        );
      } else if (!workspace.hasValue) {
        content = _DashboardLoading(
          firstName: firstName,
          environment: environment,
          valuesVisible: valuesVisible,
          callbacks: callbacks,
        );
      } else {
        content = _DashboardContent(
          firstName: firstName,
          environment: environment,
          valuesVisible: valuesVisible,
          workspace: workspace.requireValue,
          payables: payables,
          receivables: receivables,
          today: today,
          filter: filter ?? HomeDashboardFilter.currentMonth(today),
          onFilterChanged: onFilterChanged,
          callbacks: callbacks,
        );
      }
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          key: const ValueKey<String>('home-dashboard-scroll'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            horizontal,
            AppSpacing.md,
            horizontal,
            AppSpacing.xxl,
          ),
          children: <Widget>[
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: content,
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.firstName,
    required this.environment,
    required this.valuesVisible,
    required this.workspace,
    required this.payables,
    required this.receivables,
    required this.today,
    required this.filter,
    required this.onFilterChanged,
    required this.callbacks,
  });

  final String? firstName;
  final AppEnvironment environment;
  final bool valuesVisible;
  final FinancialWorkspace workspace;
  final AsyncValue<FinancialCommitmentsState<Payable>> payables;
  final AsyncValue<FinancialCommitmentsState<Receivable>> receivables;
  final SaoPauloCivilDate today;
  final HomeDashboardFilter filter;
  final ValueChanged<HomeDashboardFilter>? onFilterChanged;
  final HomeDashboardCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    final HomeDashboardAnalytics analytics = HomeDashboardAnalytics.calculate(
      workspace: workspace,
      filter: filter,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _DashboardHeader(
          firstName: firstName,
          environment: environment,
          valuesVisible: valuesVisible,
          callbacks: callbacks,
        ),
        const SizedBox(height: AppSpacing.md),
        _DashboardFilters(
          workspace: workspace,
          filter: filter,
          today: today,
          valuesVisible: valuesVisible,
          onChanged: onFilterChanged,
        ),
        const SizedBox(height: AppSpacing.md),
        _BalanceHero(
          balance: analytics.balance,
          result: analytics.result,
          accountName: _selectedAccountName(workspace, filter.accountId),
          valuesVisible: valuesVisible,
          onAccounts: callbacks.onAccounts,
        ),
        const SizedBox(height: AppSpacing.md),
        _MonthlySummary(
          income: analytics.income,
          expense: analytics.expense,
          valuesVisible: valuesVisible,
          periodLabel: filter.periodLabel,
        ),
        const SizedBox(height: AppSpacing.md),
        _QuickActions(callbacks: callbacks),
        const SizedBox(height: AppSpacing.lg),
        _IncomeExpenseChart(
          incomeCents: analytics.income.cents,
          expenseCents: analytics.expense.cents,
          valuesVisible: valuesVisible,
          periodLabel: filter.periodLabel,
        ),
        const SizedBox(height: AppSpacing.lg),
        _ExpenseDistribution(
          expenses: analytics.categoryExpenses,
          total: analytics.expense,
          valuesVisible: valuesVisible,
        ),
        const SizedBox(height: AppSpacing.lg),
        _CommitmentsSection(
          payables: payables,
          receivables: receivables,
          today: today,
          valuesVisible: valuesVisible,
          callbacks: callbacks,
          filter: filter,
        ),
        const SizedBox(height: AppSpacing.lg),
        _RecentTransactions(
          workspace: workspace,
          transactions: analytics.transactions,
          valuesVisible: valuesVisible,
          callbacks: callbacks,
        ),
      ],
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.firstName,
    required this.environment,
    required this.valuesVisible,
    required this.callbacks,
  });

  final String? firstName;
  final AppEnvironment environment;
  final bool valuesVisible;
  final HomeDashboardCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    final String greeting = firstName == null ? 'Olá!' : 'Olá, $firstName!';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(greeting, style: Theme.of(context).textTheme.titleLarge),
              Text(
                'Meu Gestor Financeiro',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (environment == AppEnvironment.development) ...<Widget>[
                const SizedBox(height: AppSpacing.xxs),
                const _DevelopmentBadge(),
              ],
            ],
          ),
        ),
        _HeaderAction(
          tooltip: valuesVisible ? 'Ocultar valores' : 'Exibir valores',
          semanticLabel: valuesVisible
              ? 'Ocultar todos os valores financeiros'
              : 'Exibir todos os valores financeiros',
          icon: valuesVisible
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
          onPressed: callbacks.onToggleValues,
        ),
        if (callbacks.onToggleTheme
            case final VoidCallback toggleTheme) ...<Widget>[
          const SizedBox(width: AppSpacing.xs),
          _HeaderAction(
            tooltip: Theme.of(context).brightness == Brightness.dark
                ? 'Usar tema claro'
                : 'Usar tema escuro',
            semanticLabel: Theme.of(context).brightness == Brightness.dark
                ? 'Ativar tema claro'
                : 'Ativar tema escuro',
            icon: Theme.of(context).brightness == Brightness.dark
                ? Icons.light_mode_outlined
                : Icons.dark_mode_outlined,
            onPressed: toggleTheme,
          ),
        ],
        const SizedBox(width: AppSpacing.xs),
        _HeaderAction(
          key: const ValueKey<String>('dashboard-header-menu-button'),
          tooltip: 'Abrir menu',
          semanticLabel: 'Abrir menu de navegação',
          icon: Icons.menu_rounded,
          onPressed: () => _openDashboardMenu(context, callbacks),
        ),
      ],
    );
  }
}

class _DevelopmentBadge extends StatelessWidget {
  const _DevelopmentBadge();

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Ambiente de desenvolvimento',
    child: Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.roundValue),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        'DEVELOPMENT',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.7,
        ),
      ),
    ),
  );
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.tooltip,
    required this.semanticLabel,
    required this.icon,
    required this.onPressed,
    super.key,
  });

  final String tooltip;
  final String semanticLabel;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: semanticLabel,
    child: Tooltip(
      message: tooltip,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: AppSpacing.minimumTapTarget,
            height: AppSpacing.minimumTapTarget,
            child: ExcludeSemantics(child: Icon(icon)),
          ),
        ),
      ),
    ),
  );
}

class _DashboardFilters extends StatelessWidget {
  const _DashboardFilters({
    required this.workspace,
    required this.filter,
    required this.today,
    required this.valuesVisible,
    required this.onChanged,
  });

  final FinancialWorkspace workspace;
  final HomeDashboardFilter filter;
  final SaoPauloCivilDate today;
  final bool valuesVisible;
  final ValueChanged<HomeDashboardFilter>? onChanged;

  @override
  Widget build(BuildContext context) {
    final String accountLabel =
        _selectedAccountName(workspace, filter.accountId) ?? 'Todas as contas';
    return Semantics(
      container: true,
      label: 'Filtros do dashboard',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _FilterButton(
              key: const ValueKey<String>('dashboard-account-filter'),
              icon: Icons.account_balance_wallet_outlined,
              label: accountLabel,
              semanticLabel: 'Filtrar por conta. Selecionado: $accountLabel',
              onPressed: onChanged == null
                  ? null
                  : () => _chooseAccount(context),
            ),
            const SizedBox(width: AppSpacing.xs),
            _FilterButton(
              key: const ValueKey<String>('dashboard-period-filter'),
              icon: Icons.calendar_month_outlined,
              label: filter.periodLabel,
              semanticLabel:
                  'Filtrar por período. Selecionado: ${filter.periodLabel}',
              onPressed: onChanged == null
                  ? null
                  : () => _choosePeriod(context),
            ),
            if (!filter.isDefaultFor(today)) ...<Widget>[
              const SizedBox(width: AppSpacing.xxs),
              Semantics(
                button: true,
                label: 'Limpar filtros do dashboard',
                child: TextButton(
                  key: const ValueKey<String>('dashboard-clear-filters'),
                  onPressed: onChanged == null
                      ? null
                      : () =>
                            onChanged!(HomeDashboardFilter.currentMonth(today)),
                  child: const Text('Limpar'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _chooseAccount(BuildContext context) async {
    final String? result = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.78,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageHorizontal,
                  AppSpacing.sm,
                  AppSpacing.pageHorizontal,
                  AppSpacing.md,
                ),
                child: Text(
                  'Conta do dashboard',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
              ),
              _FilterChoiceTile(
                label: 'Todas as contas',
                subtitle: valuesVisible
                    ? 'Saldo total ${MoneyFormatter.format(workspace.summary.totalCurrentBalance)}'
                    : 'Saldo total oculto',
                icon: Icons.all_inbox_outlined,
                selected: filter.accountId == null,
                onTap: () => Navigator.of(sheetContext).pop(''),
              ),
              for (final AccountCurrentBalance balance
                  in workspace.summary.accountBalances)
                if (!balance.account.isArchived)
                  _AccountFilterChoiceTile(
                    balance: balance,
                    valuesVisible: valuesVisible,
                    selected: filter.accountId == balance.account.id,
                    onTap: () =>
                        Navigator.of(sheetContext).pop(balance.account.id),
                  ),
            ],
          ),
        ),
      ),
    );
    if (!context.mounted || result == null) {
      return;
    }
    onChanged?.call(filter.withAccount(result.isEmpty ? null : result));
  }

  Future<void> _choosePeriod(BuildContext context) async {
    final Object? result = await showModalBottomSheet<Object>(
      context: context,
      builder: (BuildContext sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageHorizontal,
                AppSpacing.sm,
                AppSpacing.pageHorizontal,
                AppSpacing.md,
              ),
              child: Text(
                'Período do dashboard',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
            ),
            for (final DashboardPeriodPreset preset
                in DashboardPeriodPreset.values)
              _FilterChoiceTile(
                label: preset.label,
                subtitle: preset == DashboardPeriodPreset.custom
                    ? 'Escolha a data inicial e final'
                    : null,
                icon: preset == DashboardPeriodPreset.currentYear
                    ? Icons.date_range_outlined
                    : preset == DashboardPeriodPreset.custom
                    ? Icons.edit_calendar_outlined
                    : Icons.calendar_view_month_outlined,
                selected: filter.period == preset,
                onTap: () => Navigator.of(sheetContext).pop(preset),
              ),
            const Divider(),
            _FilterChoiceTile(
              label: 'Limpar filtros',
              subtitle: 'Voltar para todas as contas e este mês',
              icon: Icons.filter_alt_off_outlined,
              selected: false,
              onTap: () => Navigator.of(sheetContext).pop(_clearFiltersChoice),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted || result == null) {
      return;
    }
    if (result == _clearFiltersChoice) {
      onChanged?.call(HomeDashboardFilter.currentMonth(today));
      return;
    }
    final DashboardPeriodPreset preset = result as DashboardPeriodPreset;
    if (preset == DashboardPeriodPreset.monthAndYear) {
      final _MonthYearSelection? selection = await _chooseMonthAndYear(context);
      if (selection != null) {
        onChanged?.call(
          HomeDashboardFilter.monthAndYear(
            year: selection.year,
            month: selection.month,
            accountId: filter.accountId,
          ),
        );
      }
      return;
    }
    if (preset != DashboardPeriodPreset.custom) {
      onChanged?.call(filter.withPreset(preset, today));
      return;
    }
    final DateTimeRange? range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(today.year - 20),
      lastDate: DateTime(today.year + 5, 12, 31),
      initialDateRange: DateTimeRange(
        start: DateTime(
          filter.start.year,
          filter.start.month,
          filter.start.day,
        ),
        end: DateTime(filter.end.year, filter.end.month, filter.end.day),
      ),
      helpText: 'Período do dashboard',
      confirmText: 'Aplicar',
      cancelText: 'Cancelar',
      saveText: 'Aplicar',
    );
    if (range == null) {
      return;
    }
    onChanged?.call(
      HomeDashboardFilter.custom(
        start: SaoPauloCivilDate.fromCalendarDate(range.start),
        end: SaoPauloCivilDate.fromCalendarDate(range.end),
        accountId: filter.accountId,
      ),
    );
  }

  Future<_MonthYearSelection?> _chooseMonthAndYear(BuildContext context) async {
    int selectedYear = filter.start.year;
    int selectedMonth = filter.start.month;
    return showDialog<_MonthYearSelection>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) => AlertDialog(
          title: const Text('Escolher mês e ano'),
          content: Row(
            children: <Widget>[
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: selectedMonth,
                  decoration: const InputDecoration(labelText: 'Mês'),
                  items: <DropdownMenuItem<int>>[
                    for (int month = 1; month <= 12; month += 1)
                      DropdownMenuItem<int>(
                        value: month,
                        child: Text(_monthLabel(month)),
                      ),
                  ],
                  onChanged: (int? value) {
                    if (value != null) {
                      setState(() => selectedMonth = value);
                    }
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: selectedYear,
                  decoration: const InputDecoration(labelText: 'Ano'),
                  items: <DropdownMenuItem<int>>[
                    for (
                      int year = today.year - 20;
                      year <= today.year + 5;
                      year += 1
                    )
                      DropdownMenuItem<int>(value: year, child: Text('$year')),
                  ],
                  onChanged: (int? value) {
                    if (value != null) {
                      setState(() => selectedYear = value);
                    }
                  },
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(
                _MonthYearSelection(year: selectedYear, month: selectedMonth),
              ),
              child: const Text('Aplicar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.icon,
    required this.label,
    required this.semanticLabel,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String label;
  final String semanticLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onPressed != null,
    label: semanticLabel,
    child: ActionChip(
      avatar: Icon(icon, size: 18),
      label: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 156),
        child: Text(label, overflow: TextOverflow.ellipsis),
      ),
      onPressed: onPressed,
    ),
  );
}

class _FilterChoiceTile extends StatelessWidget {
  const _FilterChoiceTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    minTileHeight: 56,
    leading: Icon(icon),
    title: Text(label),
    subtitle: subtitle == null ? null : Text(subtitle!),
    trailing: selected ? const Icon(Icons.check_circle_rounded) : null,
    selected: selected,
    onTap: onTap,
  );
}

class _AccountFilterChoiceTile extends StatelessWidget {
  const _AccountFilterChoiceTile({
    required this.balance,
    required this.valuesVisible,
    required this.selected,
    required this.onTap,
  });

  final AccountCurrentBalance balance;
  final bool valuesVisible;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppThemeColors themeColors = AppThemeColors.of(context);
    final bool negative = balance.currentBalance.cents < 0;
    final Color stateColor = negative
        ? themeColors.expense
        : themeColors.success;
    return Semantics(
      selected: selected,
      button: true,
      label:
          '${balance.account.name}, ${balance.account.type.label}, '
          '${negative ? 'saldo negativo' : 'saldo positivo ou zero'}, '
          '${valuesVisible ? MoneyFormatter.format(balance.currentBalance) : 'valor oculto'}',
      child: ListTile(
        minTileHeight: 64,
        leading: CircleAvatar(
          backgroundColor: Theme.of(
            context,
          ).colorScheme.primary.withValues(alpha: 0.12),
          foregroundColor: Theme.of(context).colorScheme.primary,
          child: Text(_accountMonogram(balance.account.name)),
        ),
        title: Text(balance.account.name),
        subtitle: Text(
          '${balance.account.type.label} • ${negative ? 'Negativo' : 'Positivo ou zero'}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (valuesVisible)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 104),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    MoneyFormatter.format(balance.currentBalance),
                    style: Theme.of(
                      context,
                    ).textTheme.labelLarge?.copyWith(color: stateColor),
                  ),
                ),
              )
            else
              const Text('••••••'),
            const SizedBox(width: AppSpacing.xs),
            Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: selected ? Theme.of(context).colorScheme.primary : null,
            ),
          ],
        ),
        selected: selected,
        shape: RoundedRectangleBorder(
          side: BorderSide(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}

class _BalanceHero extends StatelessWidget {
  const _BalanceHero({
    required this.balance,
    required this.result,
    required this.accountName,
    required this.valuesVisible,
    required this.onAccounts,
  });

  final Money balance;
  final Money result;
  final String? accountName;
  final bool valuesVisible;
  final VoidCallback onAccounts;

  @override
  Widget build(BuildContext context) {
    final AppThemeColors themeColors = AppThemeColors.of(context);
    final ColorScheme colors = Theme.of(context).colorScheme;
    final _ResultPresentation resultPresentation = _resultPresentation(
      context,
      result,
    );
    final String balanceLabel = accountName == null
        ? 'Saldo total atual'
        : 'Saldo atual de $accountName';
    final bool enlarged = MediaQuery.textScalerOf(context).scale(16) > 22;
    final Widget balanceTitle = Row(
      children: <Widget>[
        Icon(
          Icons.account_balance_wallet_outlined,
          color: colors.primary,
          semanticLabel: 'Saldo total',
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            balanceLabel,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
        ),
      ],
    );
    final Widget accountsButton = TextButton.icon(
      onPressed: onAccounts,
      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
      label: const Text('Ver contas'),
    );
    return Semantics(
      container: true,
      label: valuesVisible
          ? '$balanceLabel ${MoneyFormatter.format(balance)}. '
                'Resultado do período ${MoneyFormatter.format(result)}, '
                '${resultPresentation.label.toLowerCase()}.'
          : 'Saldo atual e resultado do período ocultos.',
      child: Container(
        key: const ValueKey<String>('home-balance-card'),
        constraints: const BoxConstraints(minHeight: 176),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              themeColors.balanceGradientStart,
              themeColors.balanceGradientEnd,
            ],
          ),
          borderRadius: AppRadius.hero,
          border: Border.all(color: colors.outlineVariant),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: themeColors.shadow,
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (enlarged) ...<Widget>[
              balanceTitle,
              Align(alignment: Alignment.centerRight, child: accountsButton),
            ] else
              Row(
                children: <Widget>[
                  Expanded(child: balanceTitle),
                  accountsButton,
                ],
              ),
            const SizedBox(height: AppSpacing.xs),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: _MoneyValue(
                money: balance,
                visible: valuesVisible,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: colors.onSurface,
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Divider(color: colors.outlineVariant),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: <Widget>[
                Icon(
                  resultPresentation.icon,
                  color: resultPresentation.color,
                  semanticLabel: resultPresentation.label,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Resultado do período',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: colors.onSurfaceVariant),
                      ),
                      Text(
                        resultPresentation.label,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: resultPresentation.color,
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: _MoneyValue(
                      money: result,
                      visible: valuesVisible,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: colors.onSurface,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthlySummary extends StatelessWidget {
  const _MonthlySummary({
    required this.income,
    required this.expense,
    required this.valuesVisible,
    required this.periodLabel,
  });

  final Money income;
  final Money expense;
  final bool valuesVisible;
  final String periodLabel;

  @override
  Widget build(BuildContext context) {
    final AppThemeColors themeColors = AppThemeColors.of(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool stacked =
            constraints.maxWidth < 300 ||
            MediaQuery.textScalerOf(context).scale(16) > 23;
        final double width = stacked
            ? constraints.maxWidth
            : (constraints.maxWidth - AppSpacing.sm) / 2;
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            _MonthlyMetric(
              width: width,
              label: 'Receitas',
              icon: Icons.south_west_rounded,
              color: themeColors.success,
              money: income,
              visible: valuesVisible,
              supportingText: periodLabel,
            ),
            _MonthlyMetric(
              width: width,
              label: 'Despesas',
              icon: Icons.north_east_rounded,
              color: themeColors.expense,
              money: expense,
              visible: valuesVisible,
              supportingText: periodLabel,
            ),
          ],
        );
      },
    );
  }
}

class _MonthlyMetric extends StatelessWidget {
  const _MonthlyMetric({
    required this.width,
    required this.label,
    required this.icon,
    required this.color,
    required this.money,
    required this.visible,
    this.supportingText,
  });

  final double width;
  final String label;
  final IconData icon;
  final Color color;
  final Money money;
  final bool visible;
  final String? supportingText;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Semantics(
      container: true,
      label:
          '$label no período $supportingText: '
          '${visible ? MoneyFormatter.format(money) : 'valor oculto'}',
      child: Container(
        key: ValueKey<String>('dashboard-${label.toLowerCase()}-indicator'),
        constraints: const BoxConstraints(minHeight: 104),
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          borderRadius: AppRadius.medium,
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon, color: color, semanticLabel: label),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: _MoneyValue(
                money: money,
                visible: visible,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (supportingText != null)
              Text(
                supportingText!,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: color),
              ),
          ],
        ),
      ),
    ),
  );
}

class _IncomeExpenseChart extends StatelessWidget {
  const _IncomeExpenseChart({
    required this.incomeCents,
    required this.expenseCents,
    required this.valuesVisible,
    required this.periodLabel,
  });

  final int incomeCents;
  final int expenseCents;
  final bool valuesVisible;
  final String periodLabel;

  @override
  Widget build(BuildContext context) {
    final AppThemeColors themeColors = AppThemeColors.of(context);
    final int maximum = incomeCents >= expenseCents
        ? incomeCents
        : expenseCents;
    final double incomeScale = maximum == 0 ? 0 : incomeCents / maximum;
    final double expenseScale = maximum == 0 ? 0 : expenseCents / maximum;
    final Money income = Money.fromCents(incomeCents);
    final Money expense = Money.fromCents(expenseCents);
    final Money result = Money.fromCents(incomeCents - expenseCents);
    final _ResultPresentation resultPresentation = _resultPresentation(
      context,
      result,
    );
    final String semantic = valuesVisible
        ? 'Gráfico de colunas agrupadas do período $periodLabel: '
              'receitas ${MoneyFormatter.format(income)}; '
              'despesas ${MoneyFormatter.format(expense)}. '
              'As duas colunas usam a mesma escala e linha de base.'
        : 'Comparação de receitas e despesas com valores ocultos.';
    final String resultSemantic = valuesVisible
        ? 'Resultado ${MoneyFormatter.format(result)}, '
              '${resultPresentation.label.toLowerCase()}.'
        : 'Resultado com valor oculto.';
    return Semantics(
      label: '$semantic $resultSemantic',
      image: true,
      child: ExcludeSemantics(
        child: _DashboardCard(
          key: const ValueKey<String>('dashboard-income-expense-chart'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Receitas x despesas',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(periodLabel, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _ColumnLegend(
                      label: 'Receitas',
                      money: income,
                      color: themeColors.success,
                      valuesVisible: valuesVisible,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _ColumnLegend(
                      label: 'Despesas',
                      money: expense,
                      color: themeColors.expense,
                      valuesVisible: valuesVisible,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final bool enlarged =
                      MediaQuery.textScalerOf(context).scale(16) > 22;
                  return SizedBox(
                    key: const ValueKey<String>(
                      'dashboard-grouped-column-chart',
                    ),
                    height: enlarged ? 180 : 148,
                    width: constraints.maxWidth,
                    child: CustomPaint(
                      painter: _GroupedColumnsPainter(
                        incomeFraction: incomeScale,
                        expenseFraction: expenseScale,
                        incomeColor: themeColors.success,
                        expenseColor: themeColors.expense,
                        baselineColor: themeColors.chartTrack,
                        brightness: Theme.of(context).brightness,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: <Widget>[
                  Icon(
                    resultPresentation.icon,
                    size: 18,
                    color: resultPresentation.color,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'Resultado ${resultPresentation.label.toLowerCase()}',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: resultPresentation.color,
                      ),
                    ),
                  ),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: _MoneyValue(
                        money: result,
                        visible: valuesVisible,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColumnLegend extends StatelessWidget {
  const _ColumnLegend({
    required this.label,
    required this.money,
    required this.color,
    required this.valuesVisible,
  });

  final String label;
  final Money money;
  final Color color;
  final bool valuesVisible;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Row(
        children: <Widget>[
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.xxs),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: _MoneyValue(
          money: money,
          visible: valuesVisible,
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ),
    ],
  );
}

class _GroupedColumnsPainter extends CustomPainter {
  const _GroupedColumnsPainter({
    required this.incomeFraction,
    required this.expenseFraction,
    required this.incomeColor,
    required this.expenseColor,
    required this.baselineColor,
    required this.brightness,
  });

  final double incomeFraction;
  final double expenseFraction;
  final Color incomeColor;
  final Color expenseColor;
  final Color baselineColor;
  final Brightness brightness;

  @override
  void paint(Canvas canvas, Size size) {
    final double baseline = size.height - 4;
    canvas.drawLine(
      Offset(10, baseline),
      Offset(size.width - 10, baseline),
      Paint()
        ..color = baselineColor
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    final double barWidth = (size.width * 0.18).clamp(34, 58);
    final double availableHeight = size.height - 18;
    _paintColumn(
      canvas: canvas,
      centerX: size.width * 0.32,
      baseline: baseline,
      width: barWidth,
      height: availableHeight * incomeFraction.clamp(0, 1),
      color: incomeColor,
    );
    _paintColumn(
      canvas: canvas,
      centerX: size.width * 0.68,
      baseline: baseline,
      width: barWidth,
      height: availableHeight * expenseFraction.clamp(0, 1),
      color: expenseColor,
    );
  }

  void _paintColumn({
    required Canvas canvas,
    required double centerX,
    required double baseline,
    required double width,
    required double height,
    required Color color,
  }) {
    if (height <= 0) {
      return;
    }
    final double depth = (width * 0.13).clamp(4, 7);
    final double left = centerX - (width / 2);
    final double right = centerX + (width / 2) - depth;
    final double top = baseline - height;
    final Rect front = Rect.fromLTRB(left, top, right, baseline);
    final RRect roundedFront = RRect.fromRectAndRadius(
      front,
      const Radius.circular(4),
    );
    canvas.drawShadow(
      Path()..addRRect(roundedFront),
      Colors.black.withValues(
        alpha: brightness == Brightness.dark ? 0.42 : 0.22,
      ),
      5,
      false,
    );
    canvas.drawRRect(
      roundedFront,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color.lerp(color, Colors.white, 0.20)!,
            color,
            Color.lerp(color, Colors.black, 0.12)!,
          ],
        ).createShader(front),
    );

    final Path side = Path()
      ..moveTo(right, top + 3)
      ..lineTo(right + depth, top)
      ..lineTo(right + depth, baseline - 3)
      ..lineTo(right, baseline)
      ..close();
    canvas.drawPath(
      side,
      Paint()..color = Color.lerp(color, Colors.black, 0.24)!,
    );

    final Path cap = Path()
      ..moveTo(left + 4, top)
      ..lineTo(right, top)
      ..lineTo(right + depth, top - 3)
      ..lineTo(left + 4 + depth, top - 3)
      ..close();
    canvas.drawPath(
      cap,
      Paint()..color = Color.lerp(color, Colors.white, 0.30)!,
    );
  }

  @override
  bool shouldRepaint(covariant _GroupedColumnsPainter oldDelegate) =>
      incomeFraction != oldDelegate.incomeFraction ||
      expenseFraction != oldDelegate.expenseFraction ||
      incomeColor != oldDelegate.incomeColor ||
      expenseColor != oldDelegate.expenseColor ||
      baselineColor != oldDelegate.baselineColor ||
      brightness != oldDelegate.brightness;
}

class _ExpenseDistribution extends StatelessWidget {
  const _ExpenseDistribution({
    required this.expenses,
    required this.total,
    required this.valuesVisible,
  });

  final List<DashboardCategoryExpense> expenses;
  final Money total;
  final bool valuesVisible;

  @override
  Widget build(BuildContext context) {
    final List<DashboardCategoryExpense> leading = _groupCategoryExpenses(
      expenses,
    );
    final List<Color> palette = _expensePalette(context, leading.length);
    final String semantics = expenses.isEmpty
        ? 'Sem despesas no período selecionado.'
        : valuesVisible
        ? 'Distribuição de despesas: ${leading.map((DashboardCategoryExpense item) => '${item.label}, ${_formatPercentage(item.fraction)}, ${MoneyFormatter.format(item.amount)}').join('; ')}.'
        : 'Distribuição de despesas com valores e percentuais ocultos.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _SectionTitle(
          title: 'Despesas por categoria',
          subtitle: 'Onde o valor do período ficou concentrado.',
        ),
        const SizedBox(height: AppSpacing.md),
        _DashboardCard(
          child: expenses.isEmpty
              ? const _ChartEmptyState(
                  icon: Icons.donut_large_outlined,
                  title: 'Sem despesas neste período',
                  message:
                      'Quando houver despesas confirmadas, a distribuição aparecerá aqui.',
                )
              : Semantics(
                  image: true,
                  label: semantics,
                  child: ExcludeSemantics(
                    child: LayoutBuilder(
                      builder:
                          (BuildContext context, BoxConstraints constraints) {
                            final bool compact = constraints.maxWidth < 430;
                            final Widget chart = SizedBox.square(
                              dimension: compact ? 140 : 152,
                              child: CustomPaint(
                                key: const ValueKey<String>(
                                  'dashboard-expense-donut',
                                ),
                                painter: _ExpenseDonutPainter(
                                  items: leading,
                                  colors: palette,
                                  trackColor: AppThemeColors.of(
                                    context,
                                  ).chartTrack,
                                ),
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(30),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: <Widget>[
                                          Text(
                                            'Total',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.labelMedium,
                                          ),
                                          const SizedBox(
                                            height: AppSpacing.xxs,
                                          ),
                                          _MoneyValue(
                                            money: total,
                                            visible: valuesVisible,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleMedium,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                            final Widget legend = Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                for (
                                  int index = 0;
                                  index < leading.length;
                                  index += 1
                                )
                                  _CategoryExpenseRow(
                                    item: leading[index],
                                    color: palette[index],
                                    valuesVisible: valuesVisible,
                                  ),
                              ],
                            );
                            if (compact) {
                              return Column(
                                children: <Widget>[
                                  chart,
                                  const SizedBox(height: AppSpacing.md),
                                  legend,
                                ],
                              );
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: <Widget>[
                                chart,
                                const SizedBox(width: AppSpacing.lg),
                                Expanded(child: legend),
                              ],
                            );
                          },
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _ExpenseDonutPainter extends CustomPainter {
  const _ExpenseDonutPainter({
    required this.items,
    required this.colors,
    required this.trackColor,
  });

  final List<DashboardCategoryExpense> items;
  final List<Color> colors;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = (size.shortestSide - 20) / 2;
    final Rect rect = Rect.fromCircle(center: center, radius: radius);
    const double gap = 0.035;
    const double start = -1.5707963267948966;
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.butt;
    canvas.drawCircle(center, radius, paint..color = trackColor);
    double cursor = start;
    for (int index = 0; index < items.length; index += 1) {
      final DashboardCategoryExpense item = items[index];
      final double sweep = (item.fraction * 6.283185307179586) - gap;
      if (sweep <= 0) {
        continue;
      }
      canvas.drawArc(rect, cursor, sweep, false, paint..color = colors[index]);
      cursor += sweep + gap;
    }
  }

  @override
  bool shouldRepaint(_ExpenseDonutPainter oldDelegate) =>
      oldDelegate.items != items ||
      oldDelegate.colors != colors ||
      oldDelegate.trackColor != trackColor;
}

class _CategoryExpenseRow extends StatelessWidget {
  const _CategoryExpenseRow({
    required this.item,
    required this.color,
    required this.valuesVisible,
  });

  final DashboardCategoryExpense item;
  final Color color;
  final bool valuesVisible;

  @override
  Widget build(BuildContext context) {
    final bool enlarged = MediaQuery.textScalerOf(context).scale(16) > 22;
    final Widget label = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Icon(Icons.circle, size: 10, color: color),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(item.label, maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
    final Widget values = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          valuesVisible ? _formatPercentage(item.fraction) : '••',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: _MoneyValue(
              money: item.amount,
              visible: valuesVisible,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: enlarged
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                label,
                const SizedBox(height: AppSpacing.xs),
                Align(alignment: Alignment.centerRight, child: values),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(child: label),
                const SizedBox(width: AppSpacing.xs),
                Flexible(child: values),
              ],
            ),
    );
  }
}

class _ChartEmptyState extends StatelessWidget {
  const _ChartEmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
    child: Column(
      children: <Widget>[
        Icon(icon, size: 40, semanticLabel: title),
        const SizedBox(height: AppSpacing.sm),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(message, textAlign: TextAlign.center),
      ],
    ),
  );
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.callbacks});

  final HomeDashboardCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    final AppThemeColors themeColors = AppThemeColors.of(context);
    final bool enlarged = MediaQuery.textScalerOf(context).scale(16) > 22;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('Ações rápidas', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          key: const ValueKey<String>('dashboard-quick-actions'),
          height: enlarged ? 126 : 86,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: <Widget>[
              _QuickAction(
                icon: Icons.add_rounded,
                title: 'Nova receita',
                subtitle: 'Entrada realizada',
                color: themeColors.success,
                onTap: callbacks.onNewIncome,
              ),
              const SizedBox(width: AppSpacing.xs),
              _QuickAction(
                icon: Icons.remove_rounded,
                title: 'Nova despesa',
                subtitle: 'Saída realizada',
                color: themeColors.expense,
                onTap: callbacks.onNewExpense,
              ),
              const SizedBox(width: AppSpacing.xs),
              _QuickAction(
                icon: Icons.outbox_outlined,
                title: 'Conta a pagar',
                subtitle: 'Criar pendência',
                color: themeColors.warning,
                onTap: callbacks.onNewPayable,
              ),
              const SizedBox(width: AppSpacing.xs),
              _QuickAction(
                icon: Icons.move_to_inbox_outlined,
                title: 'Conta a receber',
                subtitle: 'Criar pendência',
                color: themeColors.info,
                onTap: callbacks.onNewReceivable,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 144,
    child: Semantics(
      button: true,
      label: '$title. $subtitle.',
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.medium,
          side: BorderSide(color: color.withValues(alpha: 0.30)),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.medium,
          child: Container(
            constraints: const BoxConstraints(minHeight: 80),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.13),
                    borderRadius: AppRadius.medium,
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _CommitmentsSection extends StatelessWidget {
  const _CommitmentsSection({
    required this.payables,
    required this.receivables,
    required this.today,
    required this.valuesVisible,
    required this.callbacks,
    required this.filter,
  });

  final AsyncValue<FinancialCommitmentsState<Payable>> payables;
  final AsyncValue<FinancialCommitmentsState<Receivable>> receivables;
  final SaoPauloCivilDate today;
  final bool valuesVisible;
  final HomeDashboardCallbacks callbacks;
  final HomeDashboardFilter filter;

  @override
  Widget build(BuildContext context) {
    final Widget body;
    if (payables.hasError || receivables.hasError) {
      body = _SectionError(
        message: 'Não foi possível carregar seus compromissos.',
        onRetry: callbacks.onRetryCommitments,
      );
    } else if (!payables.hasValue || !receivables.hasValue) {
      body = const _CommitmentsLoading();
    } else {
      final List<Payable> pendingPayables = payables.requireValue.commitments
          .where(
            (Payable item) => item.isPending && filter.includes(item.dueDate),
          )
          .toList(growable: false);
      final List<Receivable> pendingReceivables = receivables
          .requireValue
          .commitments
          .where(
            (Receivable item) =>
                item.isPending && filter.includes(item.dueDate),
          )
          .toList(growable: false);
      body = _CommitmentsData(
        payables: pendingPayables,
        receivables: pendingReceivables,
        today: today,
        valuesVisible: valuesVisible,
        callbacks: callbacks,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SectionTitle(
          title: 'Compromissos pendentes',
          subtitle: 'Pendências não alteram seu saldo até a confirmação.',
          actionLabel: 'Ver todos',
          onAction: callbacks.onPayables,
        ),
        const SizedBox(height: AppSpacing.md),
        body,
      ],
    );
  }
}

class _CommitmentsData extends StatelessWidget {
  const _CommitmentsData({
    required this.payables,
    required this.receivables,
    required this.today,
    required this.valuesVisible,
    required this.callbacks,
  });

  final List<Payable> payables;
  final List<Receivable> receivables;
  final SaoPauloCivilDate today;
  final bool valuesVisible;
  final HomeDashboardCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    final AppThemeColors themeColors = AppThemeColors.of(context);
    final int overdueCount = <FinancialCommitment>[
      ...payables,
      ...receivables,
    ].where((FinancialCommitment item) => item.isOverdue(today)).length;
    final List<FinancialCommitment> upcoming =
        <FinancialCommitment>[
            ...payables,
            ...receivables,
          ].where((FinancialCommitment item) => !item.isOverdue(today)).toList()
          ..sort((FinancialCommitment a, FinancialCommitment b) {
            final int date = a.dueDate.compareTo(b.dueDate);
            return date != 0
                ? date
                : a.description.toLowerCase().compareTo(
                    b.description.toLowerCase(),
                  );
          });
    if (payables.isEmpty && receivables.isEmpty) {
      return _DashboardCard(
        child: Column(
          children: <Widget>[
            Icon(
              Icons.event_available_outlined,
              size: 44,
              color: Theme.of(context).colorScheme.primary,
              semanticLabel: 'Nenhum compromisso pendente',
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Tudo organizado por aqui',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Quando você cadastrar uma conta futura, o próximo vencimento aparecerá aqui.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                OutlinedButton(
                  onPressed: callbacks.onNewPayable,
                  child: const Text('Criar conta a pagar'),
                ),
                OutlinedButton(
                  onPressed: callbacks.onNewReceivable,
                  child: const Text('Criar conta a receber'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                TextButton(
                  onPressed: callbacks.onPayables,
                  child: const Text('Contas a pagar'),
                ),
                TextButton(
                  onPressed: callbacks.onReceivables,
                  child: const Text('Contas a receber'),
                ),
              ],
            ),
          ],
        ),
      );
    }
    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _CommitmentMetric(
            label: 'A pagar',
            value: _sumCommitments(payables),
            visible: valuesVisible,
            color: themeColors.warning,
            icon: Icons.outbox_outlined,
            onTap: callbacks.onPayables,
          ),
          const SizedBox(height: AppSpacing.xs),
          _CommitmentMetric(
            label: 'A receber',
            value: _sumCommitments(receivables),
            visible: valuesVisible,
            color: themeColors.info,
            icon: Icons.move_to_inbox_outlined,
            onTap: callbacks.onReceivables,
          ),
          const SizedBox(height: AppSpacing.xs),
          _CountMetric(
            label: 'Em atraso',
            count: overdueCount,
            color: overdueCount == 0
                ? themeColors.success
                : themeColors.expense,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Próximos vencimentos',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          if (upcoming.isEmpty)
            Text(
              'Nenhum vencimento futuro pendente.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ...upcoming
              .take(3)
              .map(
                (FinancialCommitment commitment) => _UpcomingCommitmentTile(
                  commitment: commitment,
                  today: today,
                  visible: valuesVisible,
                ),
              ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              TextButton.icon(
                onPressed: callbacks.onPayables,
                icon: const Icon(Icons.outbox_outlined),
                label: const Text('Contas a pagar'),
              ),
              TextButton.icon(
                onPressed: callbacks.onReceivables,
                icon: const Icon(Icons.move_to_inbox_outlined),
                label: const Text('Contas a receber'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CommitmentMetric extends StatelessWidget {
  const _CommitmentMetric({
    required this.label,
    required this.value,
    required this.visible,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final Money value;
  final bool visible;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: color.withValues(alpha: 0.08),
    borderRadius: AppRadius.medium,
    child: InkWell(
      onTap: onTap,
      borderRadius: AppRadius.medium,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          borderRadius: AppRadius.medium,
          border: Border.all(color: color.withValues(alpha: 0.24)),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, color: color, semanticLabel: label),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.labelLarge),
            ),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: _MoneyValue(
                  money: value,
                  visible: visible,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CountMetric extends StatelessWidget {
  const _CountMetric({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 56),
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm,
      vertical: AppSpacing.xs,
    ),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: AppRadius.medium,
      border: Border.all(color: color.withValues(alpha: 0.24)),
    ),
    child: Row(
      children: <Widget>[
        Icon(
          count == 0 ? Icons.check_circle_outline : Icons.warning_amber_rounded,
          color: color,
          semanticLabel: count == 0 ? 'Sem atrasos' : 'Há atrasos',
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.labelLarge),
        ),
        Flexible(
          child: Text(
            '$count ${count == 1 ? 'compromisso' : 'compromissos'}',
            textAlign: TextAlign.end,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: color),
          ),
        ),
      ],
    ),
  );
}

class _UpcomingCommitmentTile extends StatelessWidget {
  const _UpcomingCommitmentTile({
    required this.commitment,
    required this.today,
    required this.visible,
  });

  final FinancialCommitment commitment;
  final SaoPauloCivilDate today;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final AppThemeColors themeColors = AppThemeColors.of(context);
    final bool payable = commitment.kind == FinancialCommitmentKind.payable;
    final bool overdue = commitment.isOverdue(today);
    final Color color = overdue
        ? themeColors.expense
        : payable
        ? themeColors.warning
        : themeColors.info;
    final String kindLabel = payable ? 'A pagar' : 'A receber';
    final String date = _formatCivilDate(commitment.dueDate);
    return Semantics(
      label:
          '${commitment.description}, $kindLabel, vencimento $date, '
          '${overdue ? 'atrasado' : 'pendente'}',
      child: Container(
        margin: const EdgeInsets.only(top: AppSpacing.xs),
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: AppRadius.medium,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              overdue ? Icons.schedule_rounded : Icons.event_outlined,
              color: color,
              semanticLabel: overdue ? 'Atrasado' : 'Pendente',
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    commitment.description,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '$kindLabel • $date${overdue ? ' • Atrasado' : ''}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: overdue ? color : null,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  _MoneyValue(
                    money: commitment.amount,
                    visible: visible,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentTransactions extends StatelessWidget {
  const _RecentTransactions({
    required this.workspace,
    required this.transactions,
    required this.valuesVisible,
    required this.callbacks,
  });

  final FinancialWorkspace workspace;
  final List<FinancialTransaction> transactions;
  final bool valuesVisible;
  final HomeDashboardCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    final List<FinancialTransaction> recent = transactions
        .take(4)
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SectionTitle(
          title: 'Lançamentos recentes',
          subtitle: 'As últimas movimentações do filtro aplicado.',
          actionLabel: 'Ver todos',
          onAction: callbacks.onTransactions,
        ),
        const SizedBox(height: AppSpacing.md),
        _DashboardCard(
          child: recent.isEmpty
              ? Column(
                  children: <Widget>[
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 42,
                      color: Theme.of(context).colorScheme.primary,
                      semanticLabel: 'Nenhum lançamento registrado',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Seu histórico começa aqui',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Registre uma receita ou despesa já realizada.',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                )
              : Column(
                  children: recent
                      .map(
                        (FinancialTransaction transaction) =>
                            _RecentTransactionTile(
                              transaction: transaction,
                              account: workspace.accounts.findById(
                                transaction.accountId,
                              ),
                              category: workspace.categories.findById(
                                transaction.categoryId,
                              ),
                              visible: valuesVisible,
                              onTap: () =>
                                  callbacks.onTransaction(transaction.id),
                            ),
                      )
                      .toList(growable: false),
                ),
        ),
      ],
    );
  }
}

class _RecentTransactionTile extends StatelessWidget {
  const _RecentTransactionTile({
    required this.transaction,
    required this.account,
    required this.category,
    required this.visible,
    required this.onTap,
  });

  final FinancialTransaction transaction;
  final FinancialAccount? account;
  final FinancialCategory? category;
  final bool visible;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool income = transaction.kind == FinancialTransactionKind.income;
    final AppThemeColors themeColors = AppThemeColors.of(context);
    final Color color = transaction.isVoided
        ? Theme.of(context).colorScheme.outline
        : income
        ? themeColors.success
        : themeColors.expense;
    final DateTime civil = FinancialTransactionDate.saoPauloCalendarDate(
      transaction.occurredAt,
    );
    final String date = DateFormat('dd/MM/yyyy', 'pt_BR').format(civil);
    final String kind = transaction.isVoided
        ? 'Anulado'
        : income
        ? 'Receita'
        : 'Despesa';
    return Semantics(
      button: true,
      label:
          '${transaction.description}, $kind, ${category?.name ?? 'categoria indisponível'}, '
          '${account?.name ?? 'conta indisponível'}, $date',
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.medium,
        child: Container(
          constraints: const BoxConstraints(minHeight: 84),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.22),
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: AppRadius.medium,
                ),
                child: Icon(
                  transaction.isVoided
                      ? Icons.block_outlined
                      : income
                      ? Icons.south_west_rounded
                      : Icons.north_east_rounded,
                  color: color,
                  semanticLabel: kind,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      transaction.description,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '${category?.name ?? 'Categoria indisponível'} • '
                      '${account?.name ?? 'Conta indisponível'}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Text(date, style: Theme.of(context).textTheme.labelMedium),
                    const SizedBox(height: AppSpacing.xxs),
                    _MoneyValue(
                      money: Money.fromCents(
                        income
                            ? transaction.amountCents
                            : -transaction.amountCents,
                      ),
                      visible: visible,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: color,
                        decoration: transaction.isVoided
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _openDashboardMenu(
  BuildContext context,
  HomeDashboardCallbacks callbacks,
) async {
  final _DashboardMenuDestination? destination =
      await showModalBottomSheet<_DashboardMenuDestination>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (BuildContext sheetContext) => const _DashboardMenuSheet(),
      );
  if (!context.mounted || destination == null) {
    return;
  }
  switch (destination) {
    case _DashboardMenuDestination.accounts:
      callbacks.onAccounts();
    case _DashboardMenuDestination.categories:
      callbacks.onCategories();
    case _DashboardMenuDestination.transactions:
      callbacks.onTransactions();
    case _DashboardMenuDestination.payables:
      callbacks.onPayables();
    case _DashboardMenuDestination.receivables:
      callbacks.onReceivables();
    case _DashboardMenuDestination.investments:
      callbacks.onInvestments();
    case _DashboardMenuDestination.assistant:
      callbacks.onAssistant();
    case _DashboardMenuDestination.profile:
      callbacks.onProfile();
    case _DashboardMenuDestination.appearance:
      (callbacks.onAppearance ?? callbacks.onProfile)();
  }
}

enum _DashboardMenuDestination {
  accounts,
  categories,
  transactions,
  payables,
  receivables,
  investments,
  assistant,
  profile,
  appearance,
}

class _DashboardMenuSheet extends StatelessWidget {
  const _DashboardMenuSheet();

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.md + MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Menu',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fechar menu',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const _DashboardMenuGroup(
                title: 'Organização',
                items: <_DashboardMenuItemData>[
                  _DashboardMenuItemData(
                    destination: _DashboardMenuDestination.accounts,
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Contas e carteiras',
                  ),
                  _DashboardMenuItemData(
                    destination: _DashboardMenuDestination.categories,
                    icon: Icons.category_outlined,
                    label: 'Categorias',
                  ),
                  _DashboardMenuItemData(
                    destination: _DashboardMenuDestination.transactions,
                    icon: Icons.receipt_long_outlined,
                    label: 'Lançamentos',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              const _DashboardMenuGroup(
                title: 'Planejamento',
                items: <_DashboardMenuItemData>[
                  _DashboardMenuItemData(
                    destination: _DashboardMenuDestination.payables,
                    icon: Icons.event_busy_outlined,
                    label: 'Contas a pagar',
                  ),
                  _DashboardMenuItemData(
                    destination: _DashboardMenuDestination.receivables,
                    icon: Icons.event_available_outlined,
                    label: 'Contas a receber',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              const _DashboardMenuGroup(
                title: 'Assistência',
                items: <_DashboardMenuItemData>[
                  _DashboardMenuItemData(
                    destination: _DashboardMenuDestination.assistant,
                    icon: Icons.auto_awesome_outlined,
                    label: 'Assistente financeiro',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              const _DashboardMenuGroup(
                title: 'Patrimônio',
                items: <_DashboardMenuItemData>[
                  _DashboardMenuItemData(
                    destination: _DashboardMenuDestination.investments,
                    icon: Icons.show_chart_rounded,
                    label: 'Investimentos',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              const _DashboardMenuGroup(
                title: 'Conta e aplicativo',
                items: <_DashboardMenuItemData>[
                  _DashboardMenuItemData(
                    destination: _DashboardMenuDestination.profile,
                    icon: Icons.person_outline_rounded,
                    label: 'Perfil',
                  ),
                  _DashboardMenuItemData(
                    destination: _DashboardMenuDestination.appearance,
                    icon: Icons.palette_outlined,
                    label: 'Aparência',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _DashboardMenuGroup extends StatelessWidget {
  const _DashboardMenuGroup({required this.title, required this.items});

  final String title;
  final List<_DashboardMenuItemData> items;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm,
          AppSpacing.xs,
          AppSpacing.sm,
          AppSpacing.xxs,
        ),
        child: Text(title, style: Theme.of(context).textTheme.labelLarge),
      ),
      for (final _DashboardMenuItemData item in items)
        ListTile(
          minTileHeight: 48,
          leading: Icon(item.icon),
          title: Text(item.label),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => Navigator.of(context).pop(item.destination),
        ),
    ],
  );
}

class _DashboardMenuItemData {
  const _DashboardMenuItemData({
    required this.destination,
    required this.icon,
    required this.label,
  });

  final _DashboardMenuDestination destination;
  final IconData icon;
  final String label;
}

class _WorkspaceError extends StatelessWidget {
  const _WorkspaceError({
    required this.firstName,
    required this.environment,
    required this.valuesVisible,
    required this.callbacks,
  });

  final String? firstName;
  final AppEnvironment environment;
  final bool valuesVisible;
  final HomeDashboardCallbacks callbacks;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      _DashboardHeader(
        firstName: firstName,
        environment: environment,
        valuesVisible: valuesVisible,
        callbacks: callbacks,
      ),
      const SizedBox(height: AppSpacing.lg),
      _SectionError(
        message: 'Não foi possível confirmar seu dashboard financeiro.',
        onRetry: callbacks.onRetryWorkspace,
      ),
      const SizedBox(height: AppSpacing.lg),
      const _SectionTitle(
        title: 'Ações rápidas',
        subtitle: 'Você ainda pode acessar os fluxos financeiros.',
      ),
      const SizedBox(height: AppSpacing.md),
      _QuickActions(callbacks: callbacks),
    ],
  );
}

class _DashboardLoading extends StatelessWidget {
  const _DashboardLoading({
    required this.firstName,
    required this.environment,
    required this.valuesVisible,
    required this.callbacks,
  });

  final String? firstName;
  final AppEnvironment environment;
  final bool valuesVisible;
  final HomeDashboardCallbacks callbacks;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      _DashboardHeader(
        firstName: firstName,
        environment: environment,
        valuesVisible: valuesVisible,
        callbacks: callbacks,
      ),
      const SizedBox(height: AppSpacing.lg),
      Semantics(
        liveRegion: true,
        label: 'Carregando dashboard financeiro',
        child: const Column(
          children: <Widget>[
            _SkeletonBlock(height: 214),
            SizedBox(height: AppSpacing.lg),
            _SkeletonBlock(height: 250),
            SizedBox(height: AppSpacing.lg),
            _SkeletonBlock(height: 220),
          ],
        ),
      ),
    ],
  );
}

class _CommitmentsLoading extends StatelessWidget {
  const _CommitmentsLoading();

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: 'Carregando compromissos',
    child: const _SkeletonBlock(height: 250),
  );
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: AppRadius.large,
      border: Border.all(
        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.22),
      ),
    ),
    alignment: Alignment.center,
    child: const SizedBox.square(
      dimension: 28,
      child: CircularProgressIndicator(strokeWidth: 2.5),
    ),
  );
}

class _SectionError extends StatelessWidget {
  const _SectionError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => _DashboardCard(
    child: Column(
      children: <Widget>[
        Icon(
          Icons.cloud_off_outlined,
          size: 40,
          color: Theme.of(context).colorScheme.error,
          semanticLabel: 'Falha ao carregar',
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Tentar novamente'),
        ),
      ],
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xxs),
            Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
      if (actionLabel != null && onAction != null) ...<Widget>[
        const SizedBox(width: AppSpacing.xs),
        TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    ],
  );
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final AppThemeColors themeColors = AppThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: themeColors.elevatedSurface,
        borderRadius: AppRadius.large,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: Theme.of(context).brightness == Brightness.dark
            ? const <BoxShadow>[]
            : <BoxShadow>[
                BoxShadow(
                  color: themeColors.shadow,
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: child,
    );
  }
}

class _MoneyValue extends StatelessWidget {
  const _MoneyValue({required this.money, required this.visible, this.style});

  final Money money;
  final bool visible;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    if (!visible) {
      return Semantics(
        label: 'Valor oculto',
        child: ExcludeSemantics(child: Text('••••••', style: style)),
      );
    }
    return Text(MoneyFormatter.format(money), style: style, softWrap: true);
  }
}

final class _ResultPresentation {
  const _ResultPresentation({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;
}

_ResultPresentation _resultPresentation(BuildContext context, Money result) {
  final AppThemeColors colors = AppThemeColors.of(context);
  if (result.cents > 0) {
    return _ResultPresentation(
      label: 'Positivo',
      icon: Icons.trending_up_rounded,
      color: colors.success,
    );
  }
  if (result.cents < 0) {
    return _ResultPresentation(
      label: 'Negativo',
      icon: Icons.trending_down_rounded,
      color: colors.expense,
    );
  }
  return _ResultPresentation(
    label: 'Neutro',
    icon: Icons.trending_flat_rounded,
    color: colors.info,
  );
}

List<DashboardCategoryExpense> _groupCategoryExpenses(
  List<DashboardCategoryExpense> expenses,
) {
  if (expenses.length <= 4) {
    return expenses;
  }
  final List<DashboardCategoryExpense> result = expenses
      .take(4)
      .toList(growable: true);
  final Iterable<DashboardCategoryExpense> remaining = expenses.skip(4);
  final int remainingCents = remaining.fold<int>(
    0,
    (int total, DashboardCategoryExpense item) => total + item.amount.cents,
  );
  final double remainingFraction = remaining.fold<double>(
    0,
    (double total, DashboardCategoryExpense item) => total + item.fraction,
  );
  result.add(
    DashboardCategoryExpense(
      category: null,
      amount: Money.fromCents(remainingCents),
      fraction: remainingFraction,
      labelOverride: 'Outras',
    ),
  );
  return List<DashboardCategoryExpense>.unmodifiable(result);
}

List<Color> _expensePalette(BuildContext context, int length) {
  final AppThemeColors themeColors = AppThemeColors.of(context);
  final ColorScheme colors = Theme.of(context).colorScheme;
  final List<Color> palette = <Color>[
    themeColors.expense,
    themeColors.warning,
    themeColors.info,
    colors.primary,
    Color.lerp(themeColors.expense, colors.tertiary, 0.62)!,
  ];
  return palette.take(length).toList(growable: false);
}

String _formatPercentage(double fraction) =>
    NumberFormat.percentPattern('pt_BR').format(fraction);

String? _selectedAccountName(FinancialWorkspace workspace, String? accountId) =>
    accountId == null ? null : workspace.accounts.findById(accountId)?.name;

String _accountMonogram(String name) {
  final String normalized = name.trim();
  return normalized.isEmpty ? 'C' : normalized.characters.first.toUpperCase();
}

const String _clearFiltersChoice = 'clear-filters';

final class _MonthYearSelection {
  const _MonthYearSelection({required this.year, required this.month});

  final int year;
  final int month;
}

String _monthLabel(int month) {
  final String value = DateFormat(
    'MMMM',
    'pt_BR',
  ).format(DateTime.utc(2026, month));
  return '${value[0].toUpperCase()}${value.substring(1)}';
}

Money _sumCommitments(Iterable<FinancialCommitment> commitments) =>
    Money.fromCents(
      commitments.fold<int>(
        0,
        (int total, FinancialCommitment item) => total + item.amountCents,
      ),
    );

String _formatCivilDate(SaoPauloCivilDate date) => DateFormat(
  'dd/MM/yyyy',
  'pt_BR',
).format(DateTime(date.year, date.month, date.day));
