import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_gestor_financeiro/app/routing/app_routes.dart';
import 'package:meu_gestor_financeiro/app/routing/safe_back_navigation.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
import 'package:meu_gestor_financeiro/core/dates/sao_paulo_civil_date.dart';
import 'package:meu_gestor_financeiro/features/categories/domain/financial_category.dart';
import 'package:meu_gestor_financeiro/features/categories/presentation/controllers/financial_categories_controller.dart';
import 'package:meu_gestor_financeiro/features/commitments/domain/financial_commitment.dart';
import 'package:meu_gestor_financeiro/features/commitments/presentation/controllers/financial_commitments_controller.dart';
import 'package:meu_gestor_financeiro/features/commitments/presentation/widgets/commitment_view_support.dart';
import 'package:meu_gestor_financeiro/features/transactions/data/financial_transaction_providers.dart';

class CommitmentsPage extends ConsumerStatefulWidget {
  const CommitmentsPage({required this.kind, super.key});

  final FinancialCommitmentKind kind;

  @override
  ConsumerState<CommitmentsPage> createState() => _CommitmentsPageState();
}

class _CommitmentsPageState extends ConsumerState<CommitmentsPage> {
  FinancialCommitmentListFilter _filter = FinancialCommitmentListFilter.all;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<FinancialCategoriesState> categories = ref.watch(
      financialCategoriesControllerProvider,
    );
    final AsyncValue<FinancialCommitmentsState<FinancialCommitment>> values =
        widget.kind == FinancialCommitmentKind.payable
        ? ref.watch(payablesControllerProvider)
        : ref.watch(receivablesControllerProvider);
    return SafeBackScope(
      fallbackLocation: AppRoutes.home,
      child: Scaffold(
        appBar: AppBar(
          leading: const SafeBackButton(fallbackLocation: AppRoutes.home),
          title: Text(widget.kind.plural),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push(AppRoutes.newCommitment(widget.kind)),
          icon: const Icon(Icons.add_rounded),
          label: Text(
            widget.kind == FinancialCommitmentKind.payable
                ? 'Nova conta a pagar'
                : 'Nova conta a receber',
          ),
        ),
        body: SafeArea(
          child: _body(values: values, categories: categories),
        ),
      ),
    );
  }

  Widget _body({
    required AsyncValue<FinancialCommitmentsState<FinancialCommitment>> values,
    required AsyncValue<FinancialCategoriesState> categories,
  }) {
    if (values.isLoading || categories.isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          semanticsLabel: 'Carregando compromissos financeiros',
        ),
      );
    }
    if (values.hasError || categories.hasError) {
      return _CommitmentsError(
        message: safeFinancialCommitmentErrorMessage(
          values.error ?? categories.error!,
        ),
        onRetry: _refresh,
      );
    }
    final SaoPauloCivilDate today = SaoPauloCivilDate.fromInstant(
      ref.watch(financialClockProvider)().toUtc(),
    );
    final List<FinancialCommitment> filtered = values.requireValue.filtered(
      filter: _filter,
      today: today,
    );
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          104,
        ),
        children: <Widget>[
          DropdownButtonFormField<FinancialCommitmentListFilter>(
            initialValue: _filter,
            decoration: const InputDecoration(labelText: 'Filtrar por estado'),
            items: FinancialCommitmentListFilter.values
                .map(
                  (FinancialCommitmentListFilter value) => DropdownMenuItem(
                    value: value,
                    child: Text(
                      value == FinancialCommitmentListFilter.settled
                          ? widget.kind == FinancialCommitmentKind.payable
                                ? 'Pagos'
                                : 'Recebidos'
                          : value.label,
                    ),
                  ),
                )
                .toList(growable: false),
            onChanged: (FinancialCommitmentListFilter? value) {
              if (value != null) {
                setState(() => _filter = value);
              }
            },
          ),
          const SizedBox(height: AppSpacing.md),
          const Row(
            children: <Widget>[
              Icon(Icons.cloud_done_outlined, size: 18),
              SizedBox(width: AppSpacing.xs),
              Expanded(child: Text('Dados confirmados pelo servidor')),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (filtered.isEmpty)
            _EmptyCommitments(
              kind: widget.kind,
              hasAny: values.requireValue.commitments.isNotEmpty,
            )
          else
            for (final FinancialCommitment commitment in filtered) ...<Widget>[
              CommitmentCard(
                commitment: commitment,
                categoryName: _categoryName(
                  categories.requireValue.categories,
                  commitment.categoryId,
                ),
                today: today,
                onTap: () => context.push(
                  AppRoutes.commitmentDetails(widget.kind, commitment.id),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
        ],
      ),
    );
  }

  Future<void> _refresh() async {
    await Future.wait<void>(<Future<void>>[
      ref.read(financialCategoriesControllerProvider.notifier).refresh(),
      if (widget.kind == FinancialCommitmentKind.payable)
        ref.read(payablesControllerProvider.notifier).refresh()
      else
        ref.read(receivablesControllerProvider.notifier).refresh(),
    ]);
  }

  static String _categoryName(
    List<FinancialCategory> categories,
    String categoryId,
  ) {
    for (final FinancialCategory category in categories) {
      if (category.id == categoryId) {
        return category.name;
      }
    }
    return 'Categoria indisponível';
  }
}

class _EmptyCommitments extends StatelessWidget {
  const _EmptyCommitments({required this.kind, required this.hasAny});

  final FinancialCommitmentKind kind;
  final bool hasAny;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: <Widget>[
          Icon(kind.icon, size: 56, semanticLabel: 'Nenhum compromisso'),
          const SizedBox(height: AppSpacing.md),
          Text(
            hasAny
                ? 'Nenhum compromisso corresponde ao filtro.'
                : 'Você ainda não cadastrou ${kind.plural.toLowerCase()}.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Compromissos pendentes não alteram o saldo real.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class _CommitmentsError extends StatelessWidget {
  const _CommitmentsError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.cloud_off_outlined, size: 56),
          const SizedBox(height: AppSpacing.md),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Tentar novamente'),
          ),
        ],
      ),
    ),
  );
}
