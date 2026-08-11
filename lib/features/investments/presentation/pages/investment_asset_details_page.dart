import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_gestor_financeiro/app/routing/app_routes.dart';
import 'package:meu_gestor_financeiro/app/routing/safe_back_navigation.dart';
import 'package:meu_gestor_financeiro/app/theme/app_radius.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
import 'package:meu_gestor_financeiro/app/theme/app_theme_colors.dart';
import 'package:meu_gestor_financeiro/core/privacy/financial_privacy_controller.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_operation.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_position.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/tracked_investment_asset.dart';
import 'package:meu_gestor_financeiro/features/investments/presentation/controllers/investment_action_controller.dart';
import 'package:meu_gestor_financeiro/features/investments/presentation/controllers/investments_controller.dart';
import 'package:meu_gestor_financeiro/features/investments/presentation/widgets/investment_view_support.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/presentation/controllers/investment_premium_access_controller.dart';

class InvestmentAssetDetailsPage extends ConsumerWidget {
  const InvestmentAssetDetailsPage({required this.assetId, super.key});

  final String assetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<InvestmentsState> workspace = ref.watch(
      investmentsControllerProvider,
    );
    final bool valuesVisible = ref.watch(financialPrivacyControllerProvider);
    final bool canMutate =
        ref
            .watch(investmentPremiumAccessControllerProvider)
            .value
            ?.canMutateManual ==
        true;
    return SafeBackScope(
      fallbackLocation: AppRoutes.investments,
      child: Scaffold(
        appBar: AppBar(
          leading: const SafeBackButton(
            fallbackLocation: AppRoutes.investments,
          ),
          title: const Text('Detalhes do ativo'),
          actions: <Widget>[
            InvestmentPrivacyButton(
              valuesVisible: valuesVisible,
              onPressed: () => ref
                  .read(financialPrivacyControllerProvider.notifier)
                  .toggle(),
            ),
          ],
        ),
        body: SafeArea(
          child: workspace.when(
            loading: () => const Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Carregando ativo',
              ),
            ),
            error: (Object error, StackTrace stackTrace) => _DetailsError(
              message: safeInvestmentErrorMessage(error),
              onRetry: () =>
                  ref.read(investmentsControllerProvider.notifier).refresh(),
            ),
            data: (InvestmentsState state) => _buildData(
              context,
              ref,
              state,
              valuesVisible: valuesVisible,
              canMutate: canMutate,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildData(
    BuildContext context,
    WidgetRef ref,
    InvestmentsState state, {
    required bool valuesVisible,
    required bool canMutate,
  }) {
    final TrackedInvestmentAsset? asset = state.assetById(assetId);
    if (asset == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Text(
            'Este ativo não está mais disponível.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final InvestmentPosition position = state
        .projectionForPortfolio(asset.portfolioId)
        .positions
        .firstWhere((InvestmentPosition value) => value.asset.id == assetId);
    final List<InvestmentOperation> operations =
        state.operationsForAsset(assetId).toList(growable: false)
          ..sort((InvestmentOperation a, InvestmentOperation b) {
            final int byDate = b.occurredAt.compareTo(a.occurredAt);
            return byDate != 0 ? byDate : b.createdAt.compareTo(a.createdAt);
          });
    final InvestmentActionState action = ref.watch(
      investmentActionControllerProvider,
    );
    return RefreshIndicator(
      onRefresh: () =>
          ref.read(investmentsControllerProvider.notifier).refresh(),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            constraints.maxWidth <= 360
                ? AppSpacing.compactPageHorizontal
                : AppSpacing.md,
            AppSpacing.md,
            constraints.maxWidth <= 360
                ? AppSpacing.compactPageHorizontal
                : AppSpacing.md,
            AppSpacing.xxl,
          ),
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: AppRadius.medium,
                  ),
                  child: Icon(
                    asset.type == TrackedInvestmentAssetType.stock
                        ? Icons.candlestick_chart_outlined
                        : Icons.apartment_rounded,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        asset.ticker,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text('${asset.name} · ${asset.type.label} · BRL'),
                    ],
                  ),
                ),
                Chip(
                  label: Text(
                    position.isClosed ? 'Posição zerada' : 'Posição ativa',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _PositionSummaryCard(
              position: position,
              valuesVisible: valuesVisible,
            ),
            const SizedBox(height: AppSpacing.sm),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Icon(Icons.info_outline_rounded),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Cotação automática ainda não disponível',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          const Text(
                            'Os indicadores usam somente compras e vendas informadas por você.',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (canMutate)
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  FilledButton.icon(
                    onPressed: action.isLoading
                        ? null
                        : () => context.push(
                            AppRoutes.newInvestmentOperation(
                              assetId,
                              InvestmentOperationKind.buy,
                            ),
                          ),
                    icon: const Icon(Icons.add_shopping_cart_outlined),
                    label: const Text('Registrar compra'),
                  ),
                  OutlinedButton.icon(
                    onPressed: action.isLoading || position.quantityScaled == 0
                        ? null
                        : () => context.push(
                            AppRoutes.newInvestmentOperation(
                              assetId,
                              InvestmentOperationKind.sell,
                            ),
                          ),
                    icon: const Icon(Icons.sell_outlined),
                    label: const Text('Registrar venda'),
                  ),
                ],
              ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Histórico de operações',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            if (operations.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Text(
                    'Nenhuma operação registrada. Comece pela operação mais antiga.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              for (final InvestmentOperation operation in operations)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _OperationCard(
                    operation: operation,
                    valuesVisible: valuesVisible,
                    canMutate: canMutate,
                    canVoid:
                        canMutate &&
                        !operation.isVoided &&
                        asset.lastOperationId == operation.id,
                    isLoading: action.isLoading,
                    onVoid: () => _confirmVoid(context, ref, operation),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmVoid(
    BuildContext context,
    WidgetRef ref,
    InvestmentOperation operation,
  ) async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: Text('Anular ${operation.kind.label.toLowerCase()}?'),
            content: const Text(
              'A operação continuará no histórico como anulada e deixará de compor a posição. Esta ação não pode ser desfeita.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Voltar'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Anular operação'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !context.mounted) {
      return;
    }
    final bool success = await ref
        .read(investmentActionControllerProvider.notifier)
        .voidOperation(operation);
    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Operação anulada. O histórico foi preservado.'),
        ),
      );
    }
  }
}

class _PositionSummaryCard extends StatelessWidget {
  const _PositionSummaryCard({
    required this.position,
    required this.valuesVisible,
  });

  final InvestmentPosition position;
  final bool valuesVisible;

  @override
  Widget build(BuildContext context) {
    final AppThemeColors themeColors = AppThemeColors.of(context);
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label: valuesVisible
          ? 'Resumo da posição. Quantidade ${InvestmentViewSupport.quantity(position.quantityScaled, visible: true)}. Custo total ${InvestmentViewSupport.money(position.totalCostCents, visible: true)}. Preço médio ${InvestmentViewSupport.unitPrice(position.averageUnitPriceScaled, visible: true)}. Resultado realizado ${InvestmentViewSupport.money(position.realizedResultCents, visible: true)}.'
          : 'Resumo da posição com valores e quantidades ocultos.',
      child: ExcludeSemantics(
        child: Container(
          key: const ValueKey<String>('investment-position-summary'),
          padding: const EdgeInsets.all(AppSpacing.lg),
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
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Resumo da posição',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.xl,
                runSpacing: AppSpacing.md,
                children: <Widget>[
                  _Metric(
                    label: 'Quantidade',
                    value: InvestmentViewSupport.quantity(
                      position.quantityScaled,
                      visible: valuesVisible,
                    ),
                  ),
                  _Metric(
                    label: 'Custo total',
                    value: InvestmentViewSupport.money(
                      position.totalCostCents,
                      visible: valuesVisible,
                    ),
                  ),
                  _Metric(
                    label: 'Preço médio',
                    value: InvestmentViewSupport.unitPrice(
                      position.averageUnitPriceScaled,
                      visible: valuesVisible,
                    ),
                  ),
                  _Metric(
                    label: 'Resultado realizado',
                    value: InvestmentViewSupport.money(
                      position.realizedResultCents,
                      visible: valuesVisible,
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

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minWidth: 120),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: AppSpacing.xxs),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    ),
  );
}

class _OperationCard extends StatelessWidget {
  const _OperationCard({
    required this.operation,
    required this.valuesVisible,
    required this.canMutate,
    required this.canVoid,
    required this.isLoading,
    required this.onVoid,
  });

  final InvestmentOperation operation;
  final bool valuesVisible;
  final bool canMutate;
  final bool canVoid;
  final bool isLoading;
  final VoidCallback onVoid;

  @override
  Widget build(BuildContext context) {
    final int totalCents = operation.kind == InvestmentOperationKind.buy
        ? operation.grossAmountCents + operation.feesCents
        : operation.grossAmountCents - operation.feesCents;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  operation.kind == InvestmentOperationKind.buy
                      ? Icons.add_circle_outline_rounded
                      : Icons.remove_circle_outline_rounded,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    operation.kind.label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      decoration: operation.isVoided
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                ),
                if (operation.isVoided) const Chip(label: Text('Anulada')),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('Data: ${InvestmentViewSupport.date(operation.occurredAt)}'),
            Text(
              'Quantidade: ${InvestmentViewSupport.quantity(operation.quantityScaled, visible: valuesVisible)}',
            ),
            Text(
              'Preço unitário: ${InvestmentViewSupport.unitPrice(operation.unitPriceScaled, visible: valuesVisible)}',
            ),
            Text(
              'Valor bruto: ${InvestmentViewSupport.money(operation.grossAmountCents, visible: valuesVisible)}',
            ),
            Text(
              'Taxas: ${InvestmentViewSupport.money(operation.feesCents, visible: valuesVisible)}',
            ),
            Text(
              '${operation.kind == InvestmentOperationKind.buy ? 'Total pago' : 'Total recebido'}: ${InvestmentViewSupport.money(totalCents, visible: valuesVisible)}',
            ),
            if (operation.notes.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              Text(operation.notes),
            ],
            if (canVoid) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: isLoading ? null : onVoid,
                  icon: const Icon(Icons.undo_rounded),
                  label: const Text('Anular'),
                ),
              ),
            ] else if (canMutate && !operation.isVoided) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Para corrigir esta operação, anule primeiro as operações posteriores.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailsError extends StatelessWidget {
  const _DetailsError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.md),
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
