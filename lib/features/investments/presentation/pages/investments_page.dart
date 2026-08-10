import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_gestor_financeiro/app/routing/app_routes.dart';
import 'package:meu_gestor_financeiro/app/routing/safe_back_navigation.dart';
import 'package:meu_gestor_financeiro/app/theme/app_radius.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
import 'package:meu_gestor_financeiro/app/theme/app_theme_colors.dart';
import 'package:meu_gestor_financeiro/core/privacy/financial_privacy_controller.dart';
import 'package:meu_gestor_financeiro/features/investments/data/investment_providers.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_operation.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_portfolio.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_position.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/tracked_investment_asset.dart';
import 'package:meu_gestor_financeiro/features/investments/presentation/controllers/investment_action_controller.dart';
import 'package:meu_gestor_financeiro/features/investments/presentation/controllers/investments_controller.dart';
import 'package:meu_gestor_financeiro/features/investments/presentation/widgets/investment_analytics.dart';
import 'package:meu_gestor_financeiro/features/investments/presentation/widgets/investment_view_support.dart';

class InvestmentsPage extends ConsumerStatefulWidget {
  const InvestmentsPage({super.key});

  @override
  ConsumerState<InvestmentsPage> createState() => _InvestmentsPageState();
}

class _InvestmentsPageState extends ConsumerState<InvestmentsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _assetSearchController = TextEditingController();
  String? _selectedPortfolioId;
  String _assetQuery = '';
  InvestmentAssetFilter _assetFilter = InvestmentAssetFilter.all;
  InvestmentPositionSort _assetSort = InvestmentPositionSort.ticker;
  InvestmentPeriodFilter _summaryPeriod = InvestmentPeriodFilter.last12Months;
  InvestmentAllocationMode _allocationMode = InvestmentAllocationMode.classes;
  InvestmentOperationKind? _operationKind;
  String? _operationAssetId;
  InvestmentPeriodFilter _operationPeriod = InvestmentPeriodFilter.all;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _assetSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<InvestmentsState> workspace = ref.watch(
      investmentsControllerProvider,
    );
    final bool valuesVisible = ref.watch(financialPrivacyControllerProvider);
    final InvestmentActionState action = ref.watch(
      investmentActionControllerProvider,
    );
    return SafeBackScope(
      fallbackLocation: AppRoutes.home,
      child: Scaffold(
        appBar: AppBar(
          leading: const SafeBackButton(fallbackLocation: AppRoutes.home),
          title: const Text('Investimentos'),
          actions: <Widget>[
            InvestmentPrivacyButton(
              valuesVisible: valuesVisible,
              onPressed: () => ref
                  .read(financialPrivacyControllerProvider.notifier)
                  .toggle(),
            ),
            IconButton(
              tooltip: 'Criar carteira',
              onPressed: action.isLoading
                  ? null
                  : () => context.push(AppRoutes.newInvestmentPortfolio),
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        body: SafeArea(
          child: workspace.when(
            loading: () => const Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Carregando investimentos',
              ),
            ),
            error: (Object error, StackTrace stackTrace) => _InvestmentsError(
              message: safeInvestmentErrorMessage(error),
              onRetry: () =>
                  ref.read(investmentsControllerProvider.notifier).refresh(),
            ),
            data: (InvestmentsState data) => _buildContent(
              data,
              valuesVisible: valuesVisible,
              action: action,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    InvestmentsState data, {
    required bool valuesVisible,
    required InvestmentActionState action,
  }) {
    if (data.activePortfolios.isEmpty) {
      return RefreshIndicator(
        onRefresh: () =>
            ref.read(investmentsControllerProvider.notifier).refresh(),
        child: ListView(
          key: const ValueKey<String>('investments-empty-scroll'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.md),
          children: <Widget>[
            const _TrackingNotice(),
            const SizedBox(height: AppSpacing.lg),
            _EmptyInvestments(
              hasArchived: data.archivedPortfolios.isNotEmpty,
              onCreate: () => context.push(AppRoutes.newInvestmentPortfolio),
              onArchived: () => _showPortfolioManager(data),
            ),
          ],
        ),
      );
    }
    final InvestmentPortfolio selected =
        data.activePortfolios.where((InvestmentPortfolio portfolio) {
          return portfolio.id == _selectedPortfolioId;
        }).firstOrNull ??
        data.activePortfolios.first;
    _selectedPortfolioId = selected.id;
    final InvestmentProjection projection = data.projectionForPortfolio(
      selected.id,
    );
    final DateTime now = ref.watch(investmentClockProvider)();
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.compactPageHorizontal,
            AppSpacing.xs,
            AppSpacing.compactPageHorizontal,
            AppSpacing.sm,
          ),
          child: _PortfolioSelector(
            portfolios: data.activePortfolios,
            selected: selected,
            onChanged: (InvestmentPortfolio value) => setState(() {
              _selectedPortfolioId = value.id;
              _operationAssetId = null;
              _assetQuery = '';
              _assetSearchController.clear();
              _assetFilter = InvestmentAssetFilter.all;
            }),
            onManage: () => _showPortfolioManager(data),
          ),
        ),
        TabBar(
          controller: _tabController,
          tabs: const <Widget>[
            Tab(text: 'Resumo', icon: Icon(Icons.space_dashboard_outlined)),
            Tab(text: 'Ativos', icon: Icon(Icons.candlestick_chart_outlined)),
            Tab(text: 'Lançamentos', icon: Icon(Icons.receipt_long_outlined)),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: <Widget>[
              _SummaryTab(
                portfolio: selected,
                projection: projection,
                operations: data.operations,
                valuesVisible: valuesVisible,
                isServerConfirmed: data.isServerConfirmed,
                period: _summaryPeriod,
                allocationMode: _allocationMode,
                now: now,
                onPeriodChanged: (InvestmentPeriodFilter value) =>
                    setState(() => _summaryPeriod = value),
                onAllocationModeChanged: (InvestmentAllocationMode value) =>
                    setState(() => _allocationMode = value),
                onClassSelected: _openAssetClass,
                onAssetSelected: (String assetId) =>
                    context.push(AppRoutes.investmentAssetDetails(assetId)),
                onRefresh: () =>
                    ref.read(investmentsControllerProvider.notifier).refresh(),
              ),
              _AssetsTab(
                portfolio: selected,
                projection: projection,
                valuesVisible: valuesVisible,
                query: _assetQuery,
                searchController: _assetSearchController,
                filter: _assetFilter,
                sort: _assetSort,
                actionLoading: action.isLoading,
                onQueryChanged: (String value) =>
                    setState(() => _assetQuery = value),
                onFilterChanged: (InvestmentAssetFilter value) =>
                    setState(() => _assetFilter = value),
                onSortChanged: (InvestmentPositionSort value) =>
                    setState(() => _assetSort = value),
                onAdd: () =>
                    context.push(AppRoutes.newInvestmentAsset(selected.id)),
                onOpen: (String assetId) =>
                    context.push(AppRoutes.investmentAssetDetails(assetId)),
                onRefresh: () =>
                    ref.read(investmentsControllerProvider.notifier).refresh(),
              ),
              _OperationsTab(
                portfolio: selected,
                assets: data.assetsForPortfolio(selected.id),
                operations: data.operations
                    .where(
                      (InvestmentOperation operation) =>
                          operation.portfolioId == selected.id,
                    )
                    .toList(growable: false),
                valuesVisible: valuesVisible,
                now: now,
                kind: _operationKind,
                assetId: _operationAssetId,
                period: _operationPeriod,
                actionLoading: action.isLoading,
                onKindChanged: (InvestmentOperationKind? value) =>
                    setState(() => _operationKind = value),
                onAssetChanged: (String? value) =>
                    setState(() => _operationAssetId = value),
                onPeriodChanged: (InvestmentPeriodFilter value) =>
                    setState(() => _operationPeriod = value),
                onOpenAsset: (String assetId) =>
                    context.push(AppRoutes.investmentAssetDetails(assetId)),
                onVoid: (InvestmentOperation operation) =>
                    _confirmVoid(operation),
                onRefresh: () =>
                    ref.read(investmentsControllerProvider.notifier).refresh(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _openAssetClass(TrackedInvestmentAssetType type) {
    setState(() {
      _assetFilter = type == TrackedInvestmentAssetType.stock
          ? InvestmentAssetFilter.stocks
          : InvestmentAssetFilter.realEstateFunds;
    });
    _tabController.animateTo(1);
  }

  Future<void> _confirmArchive(InvestmentPortfolio portfolio) async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('Arquivar esta carteira?'),
            content: const Text(
              'Ela e seus ativos deixarão a área principal. Operações e posições serão preservadas e a carteira poderá ser restaurada.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Arquivar'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) {
      return;
    }
    final bool success = await ref
        .read(investmentActionControllerProvider.notifier)
        .setPortfolioArchived(portfolio: portfolio, archived: true);
    if (success && mounted) {
      setState(() => _selectedPortfolioId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Carteira arquivada. Nenhum histórico foi apagado.'),
        ),
      );
    }
  }

  Future<void> _showPortfolioManager(InvestmentsState data) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.82,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Gerenciar carteiras',
                        style: Theme.of(sheetContext).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Fechar',
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    context.push(AppRoutes.newInvestmentPortfolio);
                  },
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Criar carteira'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.xs,
                    AppSpacing.md,
                    AppSpacing.lg,
                  ),
                  children: <Widget>[
                    if (data.portfolios.isEmpty)
                      const _InlineEmpty(
                        message: 'Nenhuma carteira cadastrada.',
                      )
                    else
                      for (final InvestmentPortfolio portfolio
                          in data.portfolios)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Card(
                            child: ListTile(
                              minTileHeight: 64,
                              leading: Icon(
                                portfolio.isArchived
                                    ? Icons.inventory_2_outlined
                                    : Icons.account_balance_wallet_outlined,
                              ),
                              title: Text(portfolio.name),
                              subtitle: Text(
                                portfolio.isArchived ? 'Arquivada' : 'Ativa',
                              ),
                              trailing: PopupMenuButton<String>(
                                tooltip: 'Ações de ${portfolio.name}',
                                onSelected: (String action) async {
                                  if (action == 'edit') {
                                    Navigator.of(sheetContext).pop();
                                    await context.push(
                                      AppRoutes.editInvestmentPortfolio(
                                        portfolio.id,
                                      ),
                                    );
                                    return;
                                  }
                                  if (portfolio.isArchived) {
                                    final bool success = await ref
                                        .read(
                                          investmentActionControllerProvider
                                              .notifier,
                                        )
                                        .setPortfolioArchived(
                                          portfolio: portfolio,
                                          archived: false,
                                        );
                                    if (success && sheetContext.mounted) {
                                      Navigator.of(sheetContext).pop();
                                    }
                                    return;
                                  }
                                  Navigator.of(sheetContext).pop();
                                  await _confirmArchive(portfolio);
                                },
                                itemBuilder: (BuildContext context) =>
                                    <PopupMenuEntry<String>>[
                                      const PopupMenuItem<String>(
                                        value: 'edit',
                                        child: Text('Editar'),
                                      ),
                                      PopupMenuItem<String>(
                                        value: 'archive',
                                        child: Text(
                                          portfolio.isArchived
                                              ? 'Restaurar'
                                              : 'Arquivar',
                                        ),
                                      ),
                                    ],
                              ),
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmVoid(InvestmentOperation operation) async {
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
    if (!confirmed) {
      return;
    }
    final bool success = await ref
        .read(investmentActionControllerProvider.notifier)
        .voidOperation(operation);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Operação anulada. O histórico foi preservado.'),
        ),
      );
    }
  }
}

class _PortfolioSelector extends StatelessWidget {
  const _PortfolioSelector({
    required this.portfolios,
    required this.selected,
    required this.onChanged,
    required this.onManage,
  });

  final List<InvestmentPortfolio> portfolios;
  final InvestmentPortfolio selected;
  final ValueChanged<InvestmentPortfolio> onChanged;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      Expanded(
        child: DropdownButtonFormField<String>(
          key: const ValueKey<String>('investment-portfolio-selector'),
          initialValue: selected.id,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Carteira selecionada',
            prefixIcon: Icon(Icons.account_balance_wallet_outlined),
          ),
          items: portfolios
              .map(
                (InvestmentPortfolio portfolio) => DropdownMenuItem<String>(
                  value: portfolio.id,
                  child: Text(portfolio.name, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(growable: false),
          onChanged: (String? id) {
            if (id == null) {
              return;
            }
            onChanged(
              portfolios.firstWhere(
                (InvestmentPortfolio portfolio) => portfolio.id == id,
              ),
            );
          },
        ),
      ),
      const SizedBox(width: AppSpacing.xs),
      IconButton.filledTonal(
        tooltip: 'Gerenciar carteiras',
        onPressed: onManage,
        icon: const Icon(Icons.tune_rounded),
      ),
    ],
  );
}

class _SummaryTab extends StatelessWidget {
  const _SummaryTab({
    required this.portfolio,
    required this.projection,
    required this.operations,
    required this.valuesVisible,
    required this.isServerConfirmed,
    required this.period,
    required this.allocationMode,
    required this.now,
    required this.onPeriodChanged,
    required this.onAllocationModeChanged,
    required this.onClassSelected,
    required this.onAssetSelected,
    required this.onRefresh,
  });

  final InvestmentPortfolio portfolio;
  final InvestmentProjection projection;
  final List<InvestmentOperation> operations;
  final bool valuesVisible;
  final bool isServerConfirmed;
  final InvestmentPeriodFilter period;
  final InvestmentAllocationMode allocationMode;
  final DateTime now;
  final ValueChanged<InvestmentPeriodFilter> onPeriodChanged;
  final ValueChanged<InvestmentAllocationMode> onAllocationModeChanged;
  final ValueChanged<TrackedInvestmentAssetType> onClassSelected;
  final ValueChanged<String> onAssetSelected;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final List<InvestmentEvolutionBucket> evolution =
        InvestmentAnalytics.evolution(
          operations: operations,
          portfolioId: portfolio.id,
          period: period,
          now: now,
        );
    final List<InvestmentAllocationSlice> allocation =
        allocationMode == InvestmentAllocationMode.classes
        ? InvestmentAnalytics.allocationByClass(projection)
        : InvestmentAnalytics.allocationByAsset(projection);
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) => ListView(
          key: const ValueKey<String>('investment-summary-scroll'),
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
            _InvestmentHeroCard(
              portfolio: portfolio,
              projection: projection,
              valuesVisible: valuesVisible,
            ),
            const SizedBox(height: AppSpacing.md),
            const _TrackingNotice(),
            const SizedBox(height: AppSpacing.lg),
            _SectionCard(
              title: 'Evolução dos aportes e vendas',
              subtitle: 'Compras e vendas registradas, sem cotação de mercado.',
              trailing: DropdownButton<InvestmentPeriodFilter>(
                value: period,
                underline: const SizedBox.shrink(),
                borderRadius: AppRadius.medium,
                items: InvestmentPeriodFilter.values
                    .map(
                      (InvestmentPeriodFilter value) =>
                          DropdownMenuItem<InvestmentPeriodFilter>(
                            value: value,
                            child: Text(value.label),
                          ),
                    )
                    .toList(growable: false),
                onChanged: (InvestmentPeriodFilter? value) {
                  if (value != null) {
                    onPeriodChanged(value);
                  }
                },
              ),
              child: InvestmentEvolutionChart(
                buckets: evolution,
                valuesVisible: valuesVisible,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _SectionCard(
              title: 'Alocação pelo custo acompanhado',
              subtitle: 'Participação real das posições abertas.',
              trailing: SegmentedButton<InvestmentAllocationMode>(
                showSelectedIcon: false,
                segments: InvestmentAllocationMode.values
                    .map(
                      (InvestmentAllocationMode value) =>
                          ButtonSegment<InvestmentAllocationMode>(
                            value: value,
                            label: Text(value.label),
                          ),
                    )
                    .toList(growable: false),
                selected: <InvestmentAllocationMode>{allocationMode},
                onSelectionChanged: (Set<InvestmentAllocationMode> values) =>
                    onAllocationModeChanged(values.single),
              ),
              child: InvestmentAllocationChart(
                slices: allocation,
                valuesVisible: valuesVisible,
                onSelected: (InvestmentAllocationSlice slice) {
                  if (slice.assetId != null) {
                    onAssetSelected(slice.assetId!);
                  } else if (slice.type != null) {
                    onClassSelected(slice.type!);
                  }
                },
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Classes de ativos',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final InvestmentClassSummary summary
                in InvestmentAnalytics.classes(projection))
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _AssetClassCard(
                  summary: summary,
                  valuesVisible: valuesVisible,
                  onTap: () => onClassSelected(summary.type),
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: <Widget>[
                Icon(
                  isServerConfirmed
                      ? Icons.cloud_done_outlined
                      : Icons.cloud_sync_outlined,
                  size: 18,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    isServerConfirmed
                        ? 'Histórico confirmado pelo servidor'
                        : 'Confirmação pendente',
                    style: Theme.of(context).textTheme.bodySmall,
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

class _InvestmentHeroCard extends StatelessWidget {
  const _InvestmentHeroCard({
    required this.portfolio,
    required this.projection,
    required this.valuesVisible,
  });

  final InvestmentPortfolio portfolio;
  final InvestmentProjection projection;
  final bool valuesVisible;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final AppThemeColors themeColors = AppThemeColors.of(context);
    final int openPositions = projection.positions
        .where((InvestmentPosition position) => !position.isClosed)
        .length;
    final String semantic = valuesVisible
        ? 'Carteira ${portfolio.name}. Custo acompanhado ${InvestmentViewSupport.money(projection.totalCostCents, visible: true)}. ${projection.positions.length} ativos cadastrados. $openPositions posições abertas. Resultado realizado ${InvestmentViewSupport.money(projection.totalRealizedResultCents, visible: true)}.'
        : 'Resumo da carteira ${portfolio.name} com valores e quantidades ocultos.';
    return Semantics(
      container: true,
      label: semantic,
      child: ExcludeSemantics(
        child: Container(
          key: const ValueKey<String>('investment-main-summary-card'),
          constraints: const BoxConstraints(minHeight: 196),
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
              Row(
                children: <Widget>[
                  Icon(Icons.auto_graph_rounded, color: colors.primary),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      portfolio.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const Chip(label: Text('Manual')),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Custo atual acompanhado',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  InvestmentViewSupport.money(
                    projection.totalCostCents,
                    visible: valuesVisible,
                  ),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.lg,
                runSpacing: AppSpacing.md,
                children: <Widget>[
                  _HeroMetric(
                    label: 'Ativos cadastrados',
                    value: valuesVisible
                        ? '${projection.positions.length}'
                        : InvestmentViewSupport.hiddenValue,
                  ),
                  _HeroMetric(
                    label: 'Posições abertas',
                    value: valuesVisible
                        ? '$openPositions'
                        : InvestmentViewSupport.hiddenValue,
                  ),
                  _HeroMetric(
                    label: 'Resultado realizado',
                    value: InvestmentViewSupport.money(
                      projection.totalRealizedResultCents,
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

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minWidth: 116),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: AppSpacing.xxs),
        Text(value, style: Theme.of(context).textTheme.titleSmall),
      ],
    ),
  );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xxs),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          if (trailing != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Align(alignment: Alignment.centerLeft, child: trailing),
          ],
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    ),
  );
}

class _AssetClassCard extends StatelessWidget {
  const _AssetClassCard({
    required this.summary,
    required this.valuesVisible,
    required this.onTap,
  });

  final InvestmentClassSummary summary;
  final bool valuesVisible;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: onTap,
      borderRadius: AppRadius.large,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 92),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: AppRadius.medium,
                ),
                child: Icon(
                  summary.type == TrackedInvestmentAssetType.stock
                      ? Icons.candlestick_chart_outlined
                      : Icons.apartment_rounded,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      summary.type.label,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      !valuesVisible
                          ? 'Dados da classe ocultos'
                          : summary.assetCount == 0
                          ? 'Nenhum ativo cadastrado nesta classe'
                          : '${summary.assetCount} ${summary.assetCount == 1 ? 'ativo' : 'ativos'} · ${summary.positionCount} ${summary.positionCount == 1 ? 'posição aberta' : 'posições abertas'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (valuesVisible && summary.assetCount > 0) ...<Widget>[
                      const SizedBox(height: AppSpacing.xs),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xxs,
                        children: <Widget>[
                          Text(
                            InvestmentViewSupport.money(
                              summary.costCents,
                              visible: valuesVisible,
                            ),
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          Text(
                            InvestmentViewSupport.percentage(
                              summary.fraction,
                              visible: valuesVisible,
                            ),
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    ),
  );
}

class _AssetsTab extends StatelessWidget {
  const _AssetsTab({
    required this.portfolio,
    required this.projection,
    required this.valuesVisible,
    required this.query,
    required this.searchController,
    required this.filter,
    required this.sort,
    required this.actionLoading,
    required this.onQueryChanged,
    required this.onFilterChanged,
    required this.onSortChanged,
    required this.onAdd,
    required this.onOpen,
    required this.onRefresh,
  });

  final InvestmentPortfolio portfolio;
  final InvestmentProjection projection;
  final bool valuesVisible;
  final String query;
  final TextEditingController searchController;
  final InvestmentAssetFilter filter;
  final InvestmentPositionSort sort;
  final bool actionLoading;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<InvestmentAssetFilter> onFilterChanged;
  final ValueChanged<InvestmentPositionSort> onSortChanged;
  final VoidCallback onAdd;
  final ValueChanged<String> onOpen;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final List<InvestmentPosition> positions =
        InvestmentAnalytics.filterPositions(
          positions: projection.positions,
          query: query,
          filter: filter,
          sort: sort,
        );
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) => ListView(
          key: const ValueKey<String>('investments-scroll'),
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
            Text('Ativos', style: Theme.of(context).textTheme.titleLarge),
            Text(portfolio.name, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: actionLoading ? null : onAdd,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Adicionar ativo'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const ValueKey<String>('investment-asset-search'),
              controller: searchController,
              onChanged: onQueryChanged,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                labelText: 'Buscar por ticker ou nome',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: InvestmentAssetFilter.values
                  .map(
                    (InvestmentAssetFilter value) => FilterChip(
                      label: Text(value.label),
                      selected: filter == value,
                      onSelected: (_) => onFilterChanged(value),
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<InvestmentPositionSort>(
              initialValue: sort,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Ordenar ativos por',
                prefixIcon: Icon(Icons.sort_rounded),
              ),
              items: InvestmentPositionSort.values
                  .map(
                    (InvestmentPositionSort value) =>
                        DropdownMenuItem<InvestmentPositionSort>(
                          value: value,
                          child: Text(value.label),
                        ),
                  )
                  .toList(growable: false),
              onChanged: (InvestmentPositionSort? value) {
                if (value != null) {
                  onSortChanged(value);
                }
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            if (positions.isEmpty)
              _InlineEmpty(
                message: projection.positions.isEmpty
                    ? 'Nenhum ativo cadastrado nesta carteira.'
                    : 'Nenhum ativo corresponde à busca e aos filtros.',
              )
            else
              for (final InvestmentPosition position in positions)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _PositionCard(
                    position: position,
                    valuesVisible: valuesVisible,
                    onTap: () => onOpen(position.asset.id),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _PositionCard extends StatelessWidget {
  const _PositionCard({
    required this.position,
    required this.valuesVisible,
    required this.onTap,
  });

  final InvestmentPosition position;
  final bool valuesVisible;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: AppRadius.large,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _AssetTypeIcon(type: position.asset.type),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        position.asset.ticker,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        position.asset.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                Chip(label: Text(position.asset.type.label)),
                Chip(
                  avatar: Icon(
                    position.isClosed
                        ? Icons.pause_circle_outline_rounded
                        : Icons.check_circle_outline_rounded,
                    size: 18,
                  ),
                  label: Text(
                    position.isClosed ? 'Posição zerada' : 'Posição ativa',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                _CompactMetric(
                  label: 'Quantidade',
                  value: InvestmentViewSupport.quantity(
                    position.quantityScaled,
                    visible: valuesVisible,
                  ),
                ),
                _CompactMetric(
                  label: 'Preço médio',
                  value: InvestmentViewSupport.unitPrice(
                    position.averageUnitPriceScaled,
                    visible: valuesVisible,
                  ),
                ),
                _CompactMetric(
                  label: 'Custo atual',
                  value: InvestmentViewSupport.money(
                    position.totalCostCents,
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

class _OperationsTab extends StatelessWidget {
  const _OperationsTab({
    required this.portfolio,
    required this.assets,
    required this.operations,
    required this.valuesVisible,
    required this.now,
    required this.kind,
    required this.assetId,
    required this.period,
    required this.actionLoading,
    required this.onKindChanged,
    required this.onAssetChanged,
    required this.onPeriodChanged,
    required this.onOpenAsset,
    required this.onVoid,
    required this.onRefresh,
  });

  final InvestmentPortfolio portfolio;
  final List<TrackedInvestmentAsset> assets;
  final List<InvestmentOperation> operations;
  final bool valuesVisible;
  final DateTime now;
  final InvestmentOperationKind? kind;
  final String? assetId;
  final InvestmentPeriodFilter period;
  final bool actionLoading;
  final ValueChanged<InvestmentOperationKind?> onKindChanged;
  final ValueChanged<String?> onAssetChanged;
  final ValueChanged<InvestmentPeriodFilter> onPeriodChanged;
  final ValueChanged<String> onOpenAsset;
  final ValueChanged<InvestmentOperation> onVoid;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final Map<String, TrackedInvestmentAsset> byId =
        <String, TrackedInvestmentAsset>{
          for (final TrackedInvestmentAsset asset in assets) asset.id: asset,
        };
    final List<InvestmentOperation> filtered =
        operations
            .where((operation) {
              return (kind == null || operation.kind == kind) &&
                  (assetId == null || operation.assetId == assetId) &&
                  InvestmentAnalytics.operationMatchesPeriod(
                    operation: operation,
                    period: period,
                    now: now,
                  );
            })
            .toList(growable: false)
          ..sort((InvestmentOperation first, InvestmentOperation second) {
            final int byDate = second.occurredAt.compareTo(first.occurredAt);
            return byDate != 0
                ? byDate
                : second.createdAt.compareTo(first.createdAt);
          });
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) => ListView(
          key: const ValueKey<String>('investment-operations-scroll'),
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
            Text('Lançamentos', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Histórico manual de ${portfolio.name}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            _OperationFilters(
              assets: assets,
              kind: kind,
              assetId: assetId,
              period: period,
              onKindChanged: onKindChanged,
              onAssetChanged: onAssetChanged,
              onPeriodChanged: onPeriodChanged,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (filtered.isEmpty)
              _InlineEmpty(
                message: operations.isEmpty
                    ? 'Nenhuma operação registrada nesta carteira.'
                    : 'Nenhum lançamento corresponde aos filtros.',
              )
            else
              for (final InvestmentOperation operation in filtered)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _PortfolioOperationCard(
                    operation: operation,
                    asset: byId[operation.assetId],
                    valuesVisible: valuesVisible,
                    canVoid:
                        !operation.isVoided &&
                        byId[operation.assetId]?.lastOperationId ==
                            operation.id,
                    actionLoading: actionLoading,
                    onOpen: () => onOpenAsset(operation.assetId),
                    onVoid: () => onVoid(operation),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _OperationFilters extends StatelessWidget {
  const _OperationFilters({
    required this.assets,
    required this.kind,
    required this.assetId,
    required this.period,
    required this.onKindChanged,
    required this.onAssetChanged,
    required this.onPeriodChanged,
  });

  final List<TrackedInvestmentAsset> assets;
  final InvestmentOperationKind? kind;
  final String? assetId;
  final InvestmentPeriodFilter period;
  final ValueChanged<InvestmentOperationKind?> onKindChanged;
  final ValueChanged<String?> onAssetChanged;
  final ValueChanged<InvestmentPeriodFilter> onPeriodChanged;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('Filtros', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<InvestmentOperationKind?>(
            initialValue: kind,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Operação'),
            items: <DropdownMenuItem<InvestmentOperationKind?>>[
              const DropdownMenuItem<InvestmentOperationKind?>(
                child: Text('Compras e vendas'),
              ),
              ...InvestmentOperationKind.values.map(
                (InvestmentOperationKind value) =>
                    DropdownMenuItem<InvestmentOperationKind?>(
                      value: value,
                      child: Text(value.label),
                    ),
              ),
            ],
            onChanged: onKindChanged,
          ),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String?>(
            initialValue: assetId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Ativo'),
            items: <DropdownMenuItem<String?>>[
              const DropdownMenuItem<String?>(child: Text('Todos os ativos')),
              ...assets.map(
                (TrackedInvestmentAsset asset) => DropdownMenuItem<String?>(
                  value: asset.id,
                  child: Text(
                    '${asset.ticker} · ${asset.name}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            onChanged: onAssetChanged,
          ),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<InvestmentPeriodFilter>(
            initialValue: period,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Período'),
            items: InvestmentPeriodFilter.values
                .map(
                  (InvestmentPeriodFilter value) =>
                      DropdownMenuItem<InvestmentPeriodFilter>(
                        value: value,
                        child: Text(value.label),
                      ),
                )
                .toList(growable: false),
            onChanged: (InvestmentPeriodFilter? value) {
              if (value != null) {
                onPeriodChanged(value);
              }
            },
          ),
        ],
      ),
    ),
  );
}

class _PortfolioOperationCard extends StatelessWidget {
  const _PortfolioOperationCard({
    required this.operation,
    required this.asset,
    required this.valuesVisible,
    required this.canVoid,
    required this.actionLoading,
    required this.onOpen,
    required this.onVoid,
  });

  final InvestmentOperation operation;
  final TrackedInvestmentAsset? asset;
  final bool valuesVisible;
  final bool canVoid;
  final bool actionLoading;
  final VoidCallback onOpen;
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
            InkWell(
              onTap: onOpen,
              borderRadius: AppRadius.medium,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AppSpacing.minimumTapTarget,
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      operation.kind == InvestmentOperationKind.buy
                          ? Icons.south_east_rounded
                          : Icons.north_east_rounded,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '${operation.kind.label} · ${asset?.ticker ?? 'Ativo'}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            InvestmentViewSupport.date(operation.occurredAt),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Chip(label: Text(operation.isVoided ? 'Anulada' : 'Ativa')),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
            ),
            const Divider(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                _CompactMetric(
                  label: 'Quantidade',
                  value: InvestmentViewSupport.quantity(
                    operation.quantityScaled,
                    visible: valuesVisible,
                  ),
                ),
                _CompactMetric(
                  label: 'Preço',
                  value: InvestmentViewSupport.unitPrice(
                    operation.unitPriceScaled,
                    visible: valuesVisible,
                  ),
                ),
                _CompactMetric(
                  label: 'Taxas',
                  value: InvestmentViewSupport.money(
                    operation.feesCents,
                    visible: valuesVisible,
                  ),
                ),
                _CompactMetric(
                  label: operation.kind == InvestmentOperationKind.buy
                      ? 'Total pago'
                      : 'Total recebido',
                  value: InvestmentViewSupport.money(
                    totalCents,
                    visible: valuesVisible,
                  ),
                ),
              ],
            ),
            if (canVoid) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: actionLoading ? null : onVoid,
                  icon: const Icon(Icons.undo_rounded),
                  label: const Text('Anular'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AssetTypeIcon extends StatelessWidget {
  const _AssetTypeIcon({required this.type});

  final TrackedInvestmentAssetType type;

  @override
  Widget build(BuildContext context) => Container(
    width: 44,
    height: 44,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: AppRadius.medium,
    ),
    child: Icon(
      type == TrackedInvestmentAssetType.stock
          ? Icons.candlestick_chart_outlined
          : Icons.apartment_rounded,
    ),
  );
}

class _CompactMetric extends StatelessWidget {
  const _CompactMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minWidth: 104),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: AppSpacing.xxs),
        Text(value, style: Theme.of(context).textTheme.labelLarge),
      ],
    ),
  );
}

class _TrackingNotice extends StatelessWidget {
  const _TrackingNotice();

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.visibility_outlined),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Acompanhamento manual',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.xxs),
                const Text(
                  'Investimentos não alteram contas ou saldo. Cotações automáticas ainda não estão disponíveis.',
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _EmptyInvestments extends StatelessWidget {
  const _EmptyInvestments({
    required this.hasArchived,
    required this.onCreate,
    required this.onArchived,
  });

  final bool hasArchived;
  final VoidCallback onCreate;
  final VoidCallback onArchived;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: <Widget>[
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 42,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Crie sua primeira carteira de acompanhamento',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Organize ações e FIIs cadastrados manualmente, sem misturar investimentos com seu saldo financeiro.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Criar carteira'),
          ),
          if (hasArchived) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            TextButton.icon(
              onPressed: onArchived,
              icon: const Icon(Icons.inventory_2_outlined),
              label: const Text('Ver carteiras arquivadas'),
            ),
          ],
        ],
      ),
    ),
  );
}

class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: <Widget>[
          Icon(
            Icons.inbox_outlined,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class _InvestmentsError extends StatelessWidget {
  const _InvestmentsError({required this.message, required this.onRetry});

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
