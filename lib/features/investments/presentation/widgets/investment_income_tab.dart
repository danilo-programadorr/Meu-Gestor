import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_gestor_financeiro/app/routing/app_routes.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_income_event.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_portfolio.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/tracked_investment_asset.dart';
import 'package:meu_gestor_financeiro/features/investments/presentation/controllers/investment_action_controller.dart';
import 'package:meu_gestor_financeiro/features/investments/presentation/widgets/investment_income_analytics.dart';
import 'package:meu_gestor_financeiro/features/investments/presentation/widgets/investment_view_support.dart';

class InvestmentIncomeTab extends ConsumerStatefulWidget {
  const InvestmentIncomeTab({
    required this.portfolio,
    required this.assets,
    required this.events,
    required this.valuesVisible,
    required this.now,
    required this.onRefresh,
    super.key,
  });

  final InvestmentPortfolio portfolio;
  final List<TrackedInvestmentAsset> assets;
  final List<InvestmentIncomeEvent> events;
  final bool valuesVisible;
  final DateTime now;
  final Future<void> Function() onRefresh;

  @override
  ConsumerState<InvestmentIncomeTab> createState() =>
      _InvestmentIncomeTabState();
}

class _InvestmentIncomeTabState extends ConsumerState<InvestmentIncomeTab> {
  InvestmentIncomePeriodFilter _period =
      InvestmentIncomePeriodFilter.last12Months;
  InvestmentIncomeHistoryMode _historyMode =
      InvestmentIncomeHistoryMode.monthly;
  String? _assetId;
  InvestmentIncomeType? _type;
  InvestmentIncomeStatus? _status;

  @override
  void didUpdateWidget(covariant InvestmentIncomeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.portfolio.id != widget.portfolio.id) {
      _assetId = null;
      _type = null;
      _status = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final InvestmentActionState action = ref.watch(
      investmentActionControllerProvider,
    );
    final List<InvestmentIncomeEvent> filtered =
        InvestmentIncomeAnalytics.filter(
          events: widget.events,
          portfolioId: widget.portfolio.id,
          period: _period,
          now: widget.now,
          assetId: _assetId,
          type: _type,
          status: _status,
        );
    final List<InvestmentIncomeEvent> portfolioEvents = widget.events
        .where(
          (InvestmentIncomeEvent event) =>
              event.portfolioId == widget.portfolio.id,
        )
        .toList(growable: false);
    final List<InvestmentIncomeMonthBucket> evolution =
        InvestmentIncomeAnalytics.last12Months(
          events: portfolioEvents,
          now: widget.now,
        );
    final List<InvestmentIncomeDistributionSlice> distribution =
        InvestmentIncomeAnalytics.distributionByAsset(
          events: filtered,
          assets: widget.assets,
        );
    final List<InvestmentIncomeHistoryBucket> history =
        InvestmentIncomeAnalytics.history(events: filtered, mode: _historyMode);
    final Map<String, TrackedInvestmentAsset> assetsById =
        <String, TrackedInvestmentAsset>{
          for (final TrackedInvestmentAsset asset in widget.assets)
            asset.id: asset,
        };
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) => ListView(
          key: const ValueKey<String>('investment-income-scroll'),
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
            _IncomeHeader(
              portfolioName: widget.portfolio.name,
              canCreate: widget.assets.isNotEmpty && !action.isLoading,
              onCreate: () => context.push(
                AppRoutes.newInvestmentIncomeEvent(widget.portfolio.id),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _IncomeSummaryCard(
              receivedCents: InvestmentIncomeAnalytics.receivedTotal(filtered),
              expectedCents: InvestmentIncomeAnalytics.expectedTotal(filtered),
              valuesVisible: widget.valuesVisible,
              eventCount: filtered.length,
            ),
            const SizedBox(height: AppSpacing.md),
            _IncomeFilters(
              assets: widget.assets,
              period: _period,
              assetId: _assetId,
              type: _type,
              status: _status,
              onPeriodChanged: (InvestmentIncomePeriodFilter value) =>
                  setState(() => _period = value),
              onAssetChanged: (String? value) =>
                  setState(() => _assetId = value),
              onTypeChanged: (InvestmentIncomeType? value) =>
                  setState(() => _type = value),
              onStatusChanged: (InvestmentIncomeStatus? value) =>
                  setState(() => _status = value),
            ),
            const SizedBox(height: AppSpacing.md),
            _IncomeSectionCard(
              title: 'Recebido versus previsto',
              subtitle: 'Últimos 12 meses, sem projeções automáticas',
              child: InvestmentIncomeColumnsChart(
                buckets: evolution,
                valuesVisible: widget.valuesVisible,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _IncomeSectionCard(
              title: 'Distribuição por ativo',
              subtitle: 'Somente recebimentos confirmados nos filtros',
              child: InvestmentIncomeDonutChart(
                slices: distribution,
                valuesVisible: widget.valuesVisible,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Meus proventos',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              '${filtered.length} ${filtered.length == 1 ? 'registro' : 'registros'} no filtro atual',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            if (filtered.isEmpty)
              _IncomeEmpty(
                hasAny: portfolioEvents.isNotEmpty,
                canCreate: widget.assets.isNotEmpty,
                onCreate: () => context.push(
                  AppRoutes.newInvestmentIncomeEvent(widget.portfolio.id),
                ),
              )
            else
              for (final InvestmentIncomeEvent event in filtered)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _IncomeEventCard(
                    event: event,
                    asset: assetsById[event.assetId],
                    valuesVisible: widget.valuesVisible,
                    actionLoading: action.isLoading,
                    onEdit: () => context.push(
                      AppRoutes.editInvestmentIncomeEvent(event.id),
                    ),
                    onReceive: () => _receive(event),
                    onCancel: () => _cancel(event),
                    onVoid: () => _void(event),
                  ),
                ),
            const SizedBox(height: AppSpacing.lg),
            _IncomeHistory(
              mode: _historyMode,
              values: history,
              valuesVisible: widget.valuesVisible,
              onModeChanged: (InvestmentIncomeHistoryMode value) =>
                  setState(() => _historyMode = value),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _receive(InvestmentIncomeEvent event) async {
    final DateTime today = InvestmentIncomeEvent.normalizeCivilDate(widget.now);
    DateTime selected = event.expectedPaymentDate.isAfter(today)
        ? today
        : event.expectedPaymentDate;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) => AlertDialog(
          title: const Text('Confirmar recebimento?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text(
                'O provento será marcado como recebido somente na carteira de investimentos. Nenhuma conta ou saldo será alterado.',
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Pagamento previsto: ${InvestmentViewSupport.date(event.expectedPaymentDate)}',
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.lg,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  _IncomeMetric(
                    label: 'Bruto',
                    value: InvestmentViewSupport.money(
                      event.grossAmountCents,
                      visible: widget.valuesVisible,
                    ),
                  ),
                  _IncomeMetric(
                    label: 'Imposto',
                    value: InvestmentViewSupport.money(
                      event.withholdingTaxCents,
                      visible: widget.valuesVisible,
                    ),
                  ),
                  _IncomeMetric(
                    label: 'Líquido',
                    value: InvestmentViewSupport.money(
                      event.netAmountCents,
                      visible: widget.valuesVisible,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: () async {
                  final DateTime? value = await showDatePicker(
                    context: dialogContext,
                    initialDate: selected,
                    firstDate: DateTime(1900),
                    lastDate: today,
                  );
                  if (value != null) {
                    setDialogState(() => selected = value);
                  }
                },
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text(
                  'Data efetiva: ${InvestmentViewSupport.date(selected)}',
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Voltar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Confirmar'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    final bool success = await ref
        .read(investmentActionControllerProvider.notifier)
        .receiveIncomeEvent(event: event, receivedDate: selected);
    _showResult(success);
  }

  Future<void> _cancel(InvestmentIncomeEvent event) async {
    if (!await _confirmTerminal(
      title: 'Cancelar esta previsão?',
      message:
          'O registro será preservado como cancelado e não poderá ser restaurado.',
      action: 'Cancelar previsão',
    )) {
      return;
    }
    final bool success = await ref
        .read(investmentActionControllerProvider.notifier)
        .cancelIncomeEvent(event);
    _showResult(success);
  }

  Future<void> _void(InvestmentIncomeEvent event) async {
    if (!await _confirmTerminal(
      title: 'Anular este recebimento?',
      message:
          'O histórico será preservado como anulado. Nenhum lançamento, conta ou saldo será modificado.',
      action: 'Anular recebimento',
    )) {
      return;
    }
    final bool success = await ref
        .read(investmentActionControllerProvider.notifier)
        .voidIncomeEvent(event);
    _showResult(success);
  }

  Future<bool> _confirmTerminal({
    required String title,
    required String message,
    required String action,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Voltar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  void _showResult(bool success) {
    if (!mounted) {
      return;
    }
    final InvestmentActionState action = ref.read(
      investmentActionControllerProvider,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          action.message ??
              (success ? 'Provento atualizado.' : 'Não foi possível concluir.'),
        ),
      ),
    );
  }
}

class _IncomeHeader extends StatelessWidget {
  const _IncomeHeader({
    required this.portfolioName,
    required this.canCreate,
    required this.onCreate,
  });

  final String portfolioName;
  final bool canCreate;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      final bool compact =
          constraints.maxWidth <= 360 ||
          MediaQuery.textScalerOf(context).scale(16) >= 24;
      final Widget description = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Proventos', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Acompanhamento manual de $portfolioName',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      );
      final Widget action = FilledButton.icon(
        onPressed: canCreate ? onCreate : null,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Adicionar'),
      );
      if (compact) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            description,
            const SizedBox(height: AppSpacing.sm),
            Align(alignment: Alignment.centerLeft, child: action),
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(child: description),
          const SizedBox(width: AppSpacing.sm),
          action,
        ],
      );
    },
  );
}

class _IncomeSummaryCard extends StatelessWidget {
  const _IncomeSummaryCard({
    required this.receivedCents,
    required this.expectedCents,
    required this.valuesVisible,
    required this.eventCount,
  });

  final int receivedCents;
  final int expectedCents;
  final bool valuesVisible;
  final int eventCount;

  @override
  Widget build(BuildContext context) => Semantics(
    label: valuesVisible
        ? 'Resumo de proventos: recebido ${InvestmentViewSupport.money(receivedCents, visible: true)}, previsto ${InvestmentViewSupport.money(expectedCents, visible: true)}, $eventCount registros.'
        : 'Resumo de proventos com valores ocultos.',
    child: Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Resumo do período',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.xl,
              runSpacing: AppSpacing.md,
              children: <Widget>[
                _IncomeMetric(
                  label: 'Líquido recebido',
                  value: InvestmentViewSupport.money(
                    receivedCents,
                    visible: valuesVisible,
                  ),
                ),
                _IncomeMetric(
                  label: 'Líquido previsto',
                  value: InvestmentViewSupport.money(
                    expectedCents,
                    visible: valuesVisible,
                  ),
                ),
                _IncomeMetric(label: 'Registros', value: '$eventCount'),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _IncomeFilters extends StatelessWidget {
  const _IncomeFilters({
    required this.assets,
    required this.period,
    required this.assetId,
    required this.type,
    required this.status,
    required this.onPeriodChanged,
    required this.onAssetChanged,
    required this.onTypeChanged,
    required this.onStatusChanged,
  });

  final List<TrackedInvestmentAsset> assets;
  final InvestmentIncomePeriodFilter period;
  final String? assetId;
  final InvestmentIncomeType? type;
  final InvestmentIncomeStatus? status;
  final ValueChanged<InvestmentIncomePeriodFilter> onPeriodChanged;
  final ValueChanged<String?> onAssetChanged;
  final ValueChanged<InvestmentIncomeType?> onTypeChanged;
  final ValueChanged<InvestmentIncomeStatus?> onStatusChanged;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('Filtros', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<InvestmentIncomePeriodFilter>(
            initialValue: period,
            decoration: const InputDecoration(labelText: 'Período'),
            items: InvestmentIncomePeriodFilter.values
                .map(
                  (value) =>
                      DropdownMenuItem(value: value, child: Text(value.label)),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value != null) {
                onPeriodChanged(value);
              }
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String?>(
            initialValue: assetId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Ativo'),
            items: <DropdownMenuItem<String?>>[
              const DropdownMenuItem<String?>(child: Text('Todos os ativos')),
              ...assets.map(
                (asset) => DropdownMenuItem<String?>(
                  value: asset.id,
                  child: Text(asset.ticker),
                ),
              ),
            ],
            onChanged: onAssetChanged,
          ),
          const SizedBox(height: AppSpacing.sm),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool compact =
                  constraints.maxWidth <= 360 ||
                  MediaQuery.textScalerOf(context).scale(16) >= 24;
              final Widget typeField =
                  DropdownButtonFormField<InvestmentIncomeType?>(
                    initialValue: type,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Tipo'),
                    items: <DropdownMenuItem<InvestmentIncomeType?>>[
                      const DropdownMenuItem<InvestmentIncomeType?>(
                        child: Text('Todos'),
                      ),
                      ...InvestmentIncomeType.values.map(
                        (value) => DropdownMenuItem<InvestmentIncomeType?>(
                          value: value,
                          child: Text(
                            value.label,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: onTypeChanged,
                  );
              final Widget statusField =
                  DropdownButtonFormField<InvestmentIncomeStatus?>(
                    initialValue: status,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: <DropdownMenuItem<InvestmentIncomeStatus?>>[
                      const DropdownMenuItem<InvestmentIncomeStatus?>(
                        child: Text('Todos'),
                      ),
                      ...InvestmentIncomeStatus.values.map(
                        (value) => DropdownMenuItem<InvestmentIncomeStatus?>(
                          value: value,
                          child: Text(value.label),
                        ),
                      ),
                    ],
                    onChanged: onStatusChanged,
                  );
              if (compact) {
                return Column(
                  children: <Widget>[
                    typeField,
                    const SizedBox(height: AppSpacing.sm),
                    statusField,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(child: typeField),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: statusField),
                ],
              );
            },
          ),
        ],
      ),
    ),
  );
}

class _IncomeSectionCard extends StatelessWidget {
  const _IncomeSectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

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
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    ),
  );
}

class _IncomeEventCard extends StatelessWidget {
  const _IncomeEventCard({
    required this.event,
    required this.asset,
    required this.valuesVisible,
    required this.actionLoading,
    required this.onEdit,
    required this.onReceive,
    required this.onCancel,
    required this.onVoid,
  });

  final InvestmentIncomeEvent event;
  final TrackedInvestmentAsset? asset;
  final bool valuesVisible;
  final bool actionLoading;
  final VoidCallback onEdit;
  final VoidCallback onReceive;
  final VoidCallback onCancel;
  final VoidCallback onVoid;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                asset?.type == TrackedInvestmentAssetType.fii
                    ? Icons.apartment_rounded
                    : Icons.payments_outlined,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${asset?.ticker ?? 'Ativo'} · ${event.type.label}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      'Previsto para ${InvestmentViewSupport.date(event.expectedPaymentDate)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Chip(label: Text(event.status.label)),
            ],
          ),
          const Divider(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              _IncomeMetric(
                label: 'Bruto',
                value: InvestmentViewSupport.money(
                  event.grossAmountCents,
                  visible: valuesVisible,
                ),
              ),
              _IncomeMetric(
                label: 'Imposto',
                value: InvestmentViewSupport.money(
                  event.withholdingTaxCents,
                  visible: valuesVisible,
                ),
              ),
              _IncomeMetric(
                label: 'Líquido',
                value: InvestmentViewSupport.money(
                  event.netAmountCents,
                  visible: valuesVisible,
                ),
              ),
              if (event.eligibleQuantityScaled != null)
                _IncomeMetric(
                  label: 'Quantidade elegível',
                  value: InvestmentViewSupport.quantity(
                    event.eligibleQuantityScaled!,
                    visible: valuesVisible,
                  ),
                ),
            ],
          ),
          if (event.receivedDate != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Recebido em ${InvestmentViewSupport.date(event.receivedDate!)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (event.notes.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(event.notes),
          ],
          if (!event.isTerminal) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                if (event.status ==
                    InvestmentIncomeStatus.expected) ...<Widget>[
                  TextButton.icon(
                    onPressed: actionLoading ? null : onEdit,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Editar'),
                  ),
                  TextButton.icon(
                    onPressed: actionLoading ? null : onCancel,
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Cancelar'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: actionLoading ? null : onReceive,
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: const Text('Receber'),
                  ),
                ] else if (event.status == InvestmentIncomeStatus.received)
                  TextButton.icon(
                    onPressed: actionLoading ? null : onVoid,
                    icon: const Icon(Icons.undo_rounded),
                    label: const Text('Anular recebimento'),
                  ),
              ],
            ),
          ],
        ],
      ),
    ),
  );
}

class _IncomeHistory extends StatelessWidget {
  const _IncomeHistory({
    required this.mode,
    required this.values,
    required this.valuesVisible,
    required this.onModeChanged,
  });

  final InvestmentIncomeHistoryMode mode;
  final List<InvestmentIncomeHistoryBucket> values;
  final bool valuesVisible;
  final ValueChanged<InvestmentIncomeHistoryMode> onModeChanged;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('Histórico', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: SegmentedButton<InvestmentIncomeHistoryMode>(
              segments: InvestmentIncomeHistoryMode.values
                  .map(
                    (value) =>
                        ButtonSegment(value: value, label: Text(value.label)),
                  )
                  .toList(growable: false),
              selected: <InvestmentIncomeHistoryMode>{mode},
              onSelectionChanged: (values) => onModeChanged(values.first),
              showSelectedIcon: false,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (values.isEmpty)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Text('Nenhum histórico disponível para os filtros.'),
            )
          else
            for (final InvestmentIncomeHistoryBucket value in values)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Row(
                  children: <Widget>[
                    Expanded(child: Text(value.label)),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Text(
                          InvestmentViewSupport.money(
                            value.receivedCents,
                            visible: valuesVisible,
                          ),
                        ),
                        Text(
                          'Previsto ${InvestmentViewSupport.money(value.expectedCents, visible: valuesVisible)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
        ],
      ),
    ),
  );
}

class _IncomeMetric extends StatelessWidget {
  const _IncomeMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minWidth: 108),
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

class _IncomeEmpty extends StatelessWidget {
  const _IncomeEmpty({
    required this.hasAny,
    required this.canCreate,
    required this.onCreate,
  });

  final bool hasAny;
  final bool canCreate;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: <Widget>[
          const Icon(Icons.payments_outlined, size: 38),
          const SizedBox(height: AppSpacing.sm),
          Text(
            hasAny
                ? 'Nenhum provento corresponde aos filtros.'
                : 'Nenhum provento manual nesta carteira.',
            textAlign: TextAlign.center,
          ),
          if (!hasAny && canCreate) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Adicionar provento'),
            ),
          ],
        ],
      ),
    ),
  );
}
