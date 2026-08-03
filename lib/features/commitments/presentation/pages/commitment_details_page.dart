import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_gestor_financeiro/app/routing/app_routes.dart';
import 'package:meu_gestor_financeiro/app/routing/safe_back_navigation.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
import 'package:meu_gestor_financeiro/core/dates/sao_paulo_civil_date.dart';
import 'package:meu_gestor_financeiro/core/money/money_formatter.dart';
import 'package:meu_gestor_financeiro/features/accounts/domain/financial_account.dart';
import 'package:meu_gestor_financeiro/features/accounts/presentation/controllers/financial_accounts_controller.dart';
import 'package:meu_gestor_financeiro/features/categories/domain/financial_category.dart';
import 'package:meu_gestor_financeiro/features/categories/presentation/controllers/financial_categories_controller.dart';
import 'package:meu_gestor_financeiro/features/commitments/domain/financial_commitment.dart';
import 'package:meu_gestor_financeiro/features/commitments/presentation/controllers/financial_commitment_action_controller.dart';
import 'package:meu_gestor_financeiro/features/commitments/presentation/controllers/financial_commitments_controller.dart';
import 'package:meu_gestor_financeiro/features/commitments/presentation/widgets/commitment_view_support.dart';
import 'package:meu_gestor_financeiro/features/transactions/data/financial_transaction_providers.dart';

class CommitmentDetailsPage extends ConsumerWidget {
  const CommitmentDetailsPage({
    required this.kind,
    required this.commitmentId,
    super.key,
  });

  final FinancialCommitmentKind kind;
  final String commitmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<FinancialCommitment> commitment =
        kind == FinancialCommitmentKind.payable
        ? ref.watch(payableDetailsProvider(commitmentId))
        : ref.watch(receivableDetailsProvider(commitmentId));
    final AsyncValue<FinancialAccountsState> accounts = ref.watch(
      financialAccountsControllerProvider,
    );
    final AsyncValue<FinancialCategoriesState> categories = ref.watch(
      financialCategoriesControllerProvider,
    );
    final FinancialCommitmentActionState action = ref.watch(
      financialCommitmentActionControllerProvider,
    );
    final FinancialCommitment? confirmed = action.commitment;
    final FinancialCommitment? current =
        confirmed?.id == commitmentId && confirmed?.kind == kind
        ? confirmed
        : commitment.value;
    if (current == null &&
        (commitment.isLoading || accounts.isLoading || categories.isLoading)) {
      return _loading();
    }
    if (commitment.hasError || accounts.hasError || categories.hasError) {
      return _error(
        safeFinancialCommitmentErrorMessage(
          commitment.error ?? accounts.error ?? categories.error!,
        ),
        () => _refresh(ref),
      );
    }
    if (current == null || !accounts.hasValue || !categories.hasValue) {
      return _loading();
    }
    return _DetailsContent(
      commitment: current,
      accounts: accounts.requireValue.accounts,
      categories: categories.requireValue.categories,
    );
  }

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(
      kind == FinancialCommitmentKind.payable
          ? payableDetailsProvider(commitmentId)
          : receivableDetailsProvider(commitmentId),
    );
    await Future.wait<void>(<Future<void>>[
      ref.read(financialAccountsControllerProvider.notifier).refresh(),
      ref.read(financialCategoriesControllerProvider.notifier).refresh(),
    ]);
  }

  Widget _loading() => SafeBackScope(
    fallbackLocation: AppRoutes.commitments(kind),
    child: Scaffold(
      appBar: AppBar(
        leading: SafeBackButton(fallbackLocation: AppRoutes.commitments(kind)),
        title: const Text('Detalhes do compromisso'),
      ),
      body: const Center(
        child: CircularProgressIndicator(
          semanticsLabel: 'Carregando detalhes do compromisso',
        ),
      ),
    ),
  );

  Widget _error(String message, VoidCallback onRetry) => SafeBackScope(
    fallbackLocation: AppRoutes.commitments(kind),
    child: Scaffold(
      appBar: AppBar(
        leading: SafeBackButton(fallbackLocation: AppRoutes.commitments(kind)),
        title: const Text('Detalhes do compromisso'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: onRetry,
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _DetailsContent extends ConsumerWidget {
  const _DetailsContent({
    required this.commitment,
    required this.accounts,
    required this.categories,
  });

  final FinancialCommitment commitment;
  final List<FinancialAccount> accounts;
  final List<FinancialCategory> categories;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final FinancialCommitmentActionState action = ref.watch(
      financialCommitmentActionControllerProvider,
    );
    final SaoPauloCivilDate today = SaoPauloCivilDate.fromInstant(
      ref.watch(financialClockProvider)().toUtc(),
    );
    return SafeBackScope(
      fallbackLocation: AppRoutes.commitments(commitment.kind),
      child: Scaffold(
        appBar: AppBar(
          leading: SafeBackButton(
            fallbackLocation: AppRoutes.commitments(commitment.kind),
          ),
          title: const Text('Detalhes do compromisso'),
          actions: <Widget>[
            if (commitment.isPending)
              IconButton(
                tooltip: 'Editar compromisso',
                onPressed: action.isLoading
                    ? null
                    : () => context.push(
                        AppRoutes.editCommitment(
                          commitment.kind,
                          commitment.id,
                        ),
                      ),
                icon: const Icon(Icons.edit_outlined),
              ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: <Widget>[
              Center(
                child: CircleAvatar(
                  radius: 34,
                  child: Icon(
                    commitment.kind.icon,
                    size: 34,
                    semanticLabel: commitment.kind.singular,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                commitment.description,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.lg),
              _DetailRow(label: 'Tipo', value: commitment.kind.singular),
              _DetailRow(
                label: 'Valor',
                value: MoneyFormatter.format(commitment.amount),
              ),
              _DetailRow(
                label: 'Categoria',
                value: _categoryName(commitment.categoryId),
              ),
              _DetailRow(
                label: 'Data de vencimento',
                value: formatCivilDate(commitment.dueDate),
              ),
              if (commitment.movementDate != null)
                _DetailRow(
                  label: 'Data da movimentação real',
                  value: formatCivilDate(commitment.movementDate!),
                ),
              if (commitment.settlementAccountId != null)
                _DetailRow(
                  label: 'Conta da movimentação',
                  value: _accountName(commitment.settlementAccountId!),
                ),
              _DetailRow(
                label: 'Estado',
                value: commitmentStatusLabel(commitment, today),
              ),
              _DetailRow(
                label: 'Observações',
                value: commitment.notes.isEmpty
                    ? 'Não informadas'
                    : commitment.notes,
              ),
              const SizedBox(height: AppSpacing.sm),
              _BalanceNotice(commitment: commitment),
              if (commitment.linkedTransactionId != null) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: () => context.push(
                    AppRoutes.transactionDetails(
                      commitment.linkedTransactionId!,
                    ),
                  ),
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('Ver lançamento vinculado'),
                ),
              ],
              if (action.message case final String message) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color:
                          action.status ==
                              FinancialCommitmentActionStatus.failure
                          ? Theme.of(context).colorScheme.error
                          : null,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        bottomNavigationBar: _actions(context, ref, action),
      ),
    );
  }

  Widget? _actions(
    BuildContext context,
    WidgetRef ref,
    FinancialCommitmentActionState action,
  ) {
    if (!commitment.isPending && !commitment.isSettled) {
      return null;
    }
    if (action.isLoading) {
      return const SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (commitment.isPending) ...<Widget>[
              FilledButton.icon(
                onPressed: () => _openSettlement(context),
                icon: const Icon(Icons.check_circle_outline),
                label: Text(
                  commitment.kind == FinancialCommitmentKind.payable
                      ? 'Confirmar pagamento'
                      : 'Confirmar recebimento',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: () => _confirmCancel(context, ref),
                icon: const Icon(Icons.block_outlined),
                label: const Text('Cancelar pendência'),
              ),
            ] else
              OutlinedButton.icon(
                onPressed: () => _confirmVoid(context, ref),
                icon: const Icon(Icons.undo_outlined),
                label: const Text('Anular liquidação'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSettlement(BuildContext context) async {
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => CommitmentSettlementDialog(
        commitment: commitment,
        activeAccounts: accounts
            .where((FinancialAccount account) => !account.isArchived)
            .toList(growable: false),
      ),
    );
  }

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('Cancelar esta pendência?'),
            content: const Text(
              'O compromisso continuará no histórico como cancelado. Nenhum lançamento será criado e o saldo real não mudará.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Voltar'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Cancelar pendência'),
              ),
            ],
          ),
        ) ??
        false;
    if (confirmed) {
      await ref
          .read(financialCommitmentActionControllerProvider.notifier)
          .cancelPending(commitment);
    }
  }

  Future<void> _confirmVoid(BuildContext context, WidgetRef ref) async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('Anular esta liquidação?'),
            content: const Text(
              'O compromisso permanecerá no histórico como anulado. O lançamento vinculado será invalidado na mesma operação e deixará de participar do saldo. Esta ação não restaura a pendência.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Voltar'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Anular liquidação'),
              ),
            ],
          ),
        ) ??
        false;
    if (confirmed) {
      await ref
          .read(financialCommitmentActionControllerProvider.notifier)
          .voidSettlement(commitment);
    }
  }

  String _accountName(String id) {
    for (final FinancialAccount account in accounts) {
      if (account.id == id) {
        return account.isArchived
            ? '${account.name} (arquivada)'
            : account.name;
      }
    }
    return 'Conta indisponível';
  }

  String _categoryName(String id) {
    for (final FinancialCategory category in categories) {
      if (category.id == id) {
        return category.isArchived
            ? '${category.name} (arquivada)'
            : category.name;
      }
    }
    return 'Categoria indisponível';
  }
}

class CommitmentSettlementDialog extends ConsumerStatefulWidget {
  const CommitmentSettlementDialog({
    required this.commitment,
    required this.activeAccounts,
    super.key,
  });

  final FinancialCommitment commitment;
  final List<FinancialAccount> activeAccounts;

  @override
  ConsumerState<CommitmentSettlementDialog> createState() =>
      _CommitmentSettlementDialogState();
}

class _CommitmentSettlementDialogState
    extends ConsumerState<CommitmentSettlementDialog> {
  String? _accountId;
  SaoPauloCivilDate? _movementDate;

  @override
  void initState() {
    super.initState();
    _accountId = widget.activeAccounts.length == 1
        ? widget.activeAccounts.single.id
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final FinancialCommitmentActionState action = ref.watch(
      financialCommitmentActionControllerProvider,
    );
    _movementDate ??= SaoPauloCivilDate.fromInstant(
      ref.read(financialClockProvider)().toUtc(),
    );
    return PopScope(
      canPop: !action.isLoading,
      child: AlertDialog(
        title: Text(
          widget.commitment.kind == FinancialCommitmentKind.payable
              ? 'Confirmar pagamento'
              : 'Confirmar recebimento',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(widget.commitment.description),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Valor fixo: ${MoneyFormatter.format(widget.commitment.amount)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Vencimento previsto: ${formatCivilDate(widget.commitment.dueDate)}',
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'A data da movimentação indica quando o dinheiro realmente saiu ou entrou. Ela é separada do vencimento.',
              ),
              const SizedBox(height: AppSpacing.md),
              if (widget.activeAccounts.isEmpty)
                const Text(
                  'Não há conta ativa disponível. Cadastre ou restaure uma conta antes de liquidar.',
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: _accountId,
                  decoration: const InputDecoration(
                    labelText: 'Conta da movimentação',
                  ),
                  items: widget.activeAccounts
                      .map(
                        (FinancialAccount account) => DropdownMenuItem<String>(
                          value: account.id,
                          child: Text(account.name),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: action.isLoading
                      ? null
                      : (String? value) => setState(() => _accountId = value),
                ),
              const SizedBox(height: AppSpacing.md),
              CivilDateField(
                label: 'Data da movimentação',
                selectedDate: _movementDate,
                enabled: !action.isLoading,
                helperText:
                    'Pode ser hoje ou uma data passada. Datas futuras são bloqueadas.',
                onPressed: _chooseMovementDate,
              ),
              if (action.message case final String message) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    message,
                    style: TextStyle(
                      color:
                          action.status ==
                              FinancialCommitmentActionStatus.failure
                          ? Theme.of(context).colorScheme.error
                          : null,
                    ),
                  ),
                ),
              ],
              if (action.isLoading) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                const Center(
                  child: CircularProgressIndicator(
                    semanticsLabel: 'Confirmando liquidação com o servidor',
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: action.isLoading
                ? null
                : () => Navigator.of(context).pop(false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed:
                action.isLoading ||
                    _accountId == null ||
                    widget.activeAccounts.isEmpty
                ? null
                : _confirm,
            child: Text(widget.commitment.kind.settlementVerb),
          ),
        ],
      ),
    );
  }

  Future<void> _chooseMovementDate() async {
    final SaoPauloCivilDate today = SaoPauloCivilDate.fromInstant(
      ref.read(financialClockProvider)().toUtc(),
    );
    final SaoPauloCivilDate? selected = await showCivilDatePicker(
      context: context,
      selectedDate: _movementDate ?? today,
      lastDate: today.toUtcCalendarDate(),
      helpText: 'Data da movimentação',
    );
    if (selected != null && mounted) {
      setState(() => _movementDate = selected);
    }
  }

  Future<void> _confirm() async {
    final bool success = await ref
        .read(financialCommitmentActionControllerProvider.notifier)
        .settle(
          commitment: widget.commitment,
          accountId: _accountId!,
          movementDate: _movementDate!,
        );
    if (success && mounted) {
      Navigator.of(context).pop(true);
    }
  }
}

class _BalanceNotice extends StatelessWidget {
  const _BalanceNotice({required this.commitment});

  final FinancialCommitment commitment;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.info_outline),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              commitment.isSettled
                  ? 'Somente o lançamento vinculado ativo participa do saldo real.'
                  : commitment.isVoided
                  ? 'A liquidação e o lançamento foram anulados; este registro não participa do saldo.'
                  : 'Este compromisso não participa do saldo real.',
            ),
          ),
        ],
      ),
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(child: Text(label)),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
      ],
    ),
  );
}
