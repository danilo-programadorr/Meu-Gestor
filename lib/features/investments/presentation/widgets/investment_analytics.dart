import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:meu_gestor_financeiro/app/theme/app_radius.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
import 'package:meu_gestor_financeiro/app/theme/app_theme_colors.dart';
import 'package:meu_gestor_financeiro/core/dates/sao_paulo_civil_date.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_operation.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_position.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/scaled_investment_value.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/tracked_investment_asset.dart';
import 'package:meu_gestor_financeiro/features/investments/presentation/widgets/investment_view_support.dart';

enum InvestmentPeriodFilter {
  last3Months('3 meses', 3),
  last6Months('6 meses', 6),
  last12Months('12 meses', 12),
  all('Todo o período', null);

  const InvestmentPeriodFilter(this.label, this.months);

  final String label;
  final int? months;
}

enum InvestmentAssetFilter {
  all('Todos'),
  stocks('Ações'),
  realEstateFunds('FIIs');

  const InvestmentAssetFilter(this.label);

  final String label;

  bool accepts(InvestmentPosition position) => switch (this) {
    InvestmentAssetFilter.all => true,
    InvestmentAssetFilter.stocks =>
      position.asset.type == TrackedInvestmentAssetType.stock,
    InvestmentAssetFilter.realEstateFunds =>
      position.asset.type == TrackedInvestmentAssetType.fii,
  };
}

enum InvestmentPositionSort {
  ticker('Ticker'),
  highestCost('Maior custo'),
  name('Nome');

  const InvestmentPositionSort(this.label);

  final String label;
}

enum InvestmentAllocationMode {
  classes('Classes'),
  assets('Ativos');

  const InvestmentAllocationMode(this.label);

  final String label;
}

final class InvestmentEvolutionBucket {
  const InvestmentEvolutionBucket({
    required this.label,
    required this.buyCents,
    required this.sellCents,
  });

  final String label;
  final int buyCents;
  final int sellCents;
}

final class InvestmentAllocationSlice {
  const InvestmentAllocationSlice({
    required this.label,
    required this.secondaryLabel,
    required this.costCents,
    required this.fraction,
    this.assetId,
    this.type,
  });

  final String label;
  final String secondaryLabel;
  final int costCents;
  final double fraction;
  final String? assetId;
  final TrackedInvestmentAssetType? type;
}

final class InvestmentClassSummary {
  const InvestmentClassSummary({
    required this.type,
    required this.assetCount,
    required this.positionCount,
    required this.costCents,
    required this.fraction,
  });

  final TrackedInvestmentAssetType type;
  final int assetCount;
  final int positionCount;
  final int costCents;
  final double fraction;
}

abstract final class InvestmentAnalytics {
  static List<InvestmentOperation> activeOperations({
    required Iterable<InvestmentOperation> operations,
    required String portfolioId,
  }) {
    final List<InvestmentOperation> values = operations
        .where(
          (InvestmentOperation operation) =>
              operation.portfolioId == portfolioId && !operation.isVoided,
        )
        .toList(growable: false);
    values.sort(_compareOperations);
    return values;
  }

  static List<InvestmentEvolutionBucket> evolution({
    required Iterable<InvestmentOperation> operations,
    required String portfolioId,
    required InvestmentPeriodFilter period,
    required DateTime now,
  }) {
    final List<InvestmentOperation> active = activeOperations(
      operations: operations,
      portfolioId: portfolioId,
    );
    if (active.isEmpty) {
      return const <InvestmentEvolutionBucket>[];
    }
    final DateTime today = SaoPauloCivilDate.fromInstant(
      now,
    ).toUtcCalendarDate();
    final DateTime end = DateTime.utc(today.year, today.month);
    final DateTime firstOperationMonth = _monthOf(active.first.occurredAt);
    final int? requestedMonths = period.months;
    final DateTime start = requestedMonths == null
        ? firstOperationMonth
        : _addMonths(end, -(requestedMonths - 1));
    final int span = _monthDistance(start, end) + 1;
    if (span > 18) {
      return _yearBuckets(active, start: start, end: end);
    }
    final Map<String, _MutableAmounts> totals = <String, _MutableAmounts>{};
    for (final InvestmentOperation operation in active) {
      final DateTime month = _monthOf(operation.occurredAt);
      if (month.isBefore(start) || month.isAfter(end)) {
        continue;
      }
      final String key = '${month.year}-${month.month}';
      final _MutableAmounts amount = totals.putIfAbsent(
        key,
        _MutableAmounts.new,
      );
      amount.add(operation);
    }
    return List<InvestmentEvolutionBucket>.generate(span, (int index) {
      final DateTime month = _addMonths(start, index);
      final _MutableAmounts amounts =
          totals['${month.year}-${month.month}'] ?? _MutableAmounts();
      return InvestmentEvolutionBucket(
        label: DateFormat('MM/yy', 'pt_BR').format(month),
        buyCents: amounts.buyCents,
        sellCents: amounts.sellCents,
      );
    }, growable: false);
  }

  static List<InvestmentAllocationSlice> allocationByClass(
    InvestmentProjection projection,
  ) {
    final List<InvestmentPosition> open = projection.positions
        .where(
          (InvestmentPosition position) =>
              !position.isClosed && position.totalCostCents > 0,
        )
        .toList(growable: false);
    if (open.isEmpty || projection.totalCostCents <= 0) {
      return const <InvestmentAllocationSlice>[];
    }
    return TrackedInvestmentAssetType.values
        .map((TrackedInvestmentAssetType type) {
          final int cost = open
              .where(
                (InvestmentPosition position) => position.asset.type == type,
              )
              .fold<int>(
                0,
                (int total, InvestmentPosition position) =>
                    total + position.totalCostCents,
              );
          final int assets = open
              .where(
                (InvestmentPosition position) => position.asset.type == type,
              )
              .length;
          return InvestmentAllocationSlice(
            label: type.label,
            secondaryLabel: '$assets ${assets == 1 ? 'posição' : 'posições'}',
            costCents: cost,
            fraction: cost / projection.totalCostCents,
            type: type,
          );
        })
        .where((InvestmentAllocationSlice slice) => slice.costCents > 0)
        .toList(growable: false);
  }

  static List<InvestmentAllocationSlice> allocationByAsset(
    InvestmentProjection projection,
  ) {
    if (projection.totalCostCents <= 0) {
      return const <InvestmentAllocationSlice>[];
    }
    final List<InvestmentPosition> open =
        projection.positions
            .where(
              (InvestmentPosition position) =>
                  !position.isClosed && position.totalCostCents > 0,
            )
            .toList(growable: false)
          ..sort((InvestmentPosition first, InvestmentPosition second) {
            final int byCost = second.totalCostCents.compareTo(
              first.totalCostCents,
            );
            return byCost != 0
                ? byCost
                : first.asset.ticker.compareTo(second.asset.ticker);
          });
    return open
        .map(
          (InvestmentPosition position) => InvestmentAllocationSlice(
            label: position.asset.ticker,
            secondaryLabel: position.asset.type.label,
            costCents: position.totalCostCents,
            fraction: position.totalCostCents / projection.totalCostCents,
            assetId: position.asset.id,
            type: position.asset.type,
          ),
        )
        .toList(growable: false);
  }

  static List<InvestmentClassSummary> classes(
    InvestmentProjection projection,
  ) => TrackedInvestmentAssetType.values
      .map((TrackedInvestmentAssetType type) {
        final List<InvestmentPosition> values = projection.positions
            .where((InvestmentPosition position) => position.asset.type == type)
            .toList(growable: false);
        final int cost = values.fold<int>(
          0,
          (int total, InvestmentPosition position) =>
              total + position.totalCostCents,
        );
        return InvestmentClassSummary(
          type: type,
          assetCount: values.length,
          positionCount: values
              .where((InvestmentPosition position) => !position.isClosed)
              .length,
          costCents: cost,
          fraction: projection.totalCostCents <= 0
              ? 0
              : cost / projection.totalCostCents,
        );
      })
      .toList(growable: false);

  static List<InvestmentPosition> filterPositions({
    required Iterable<InvestmentPosition> positions,
    required String query,
    required InvestmentAssetFilter filter,
    required InvestmentPositionSort sort,
  }) {
    final String normalizedQuery = query.trim().toLowerCase();
    final List<InvestmentPosition> values = positions
        .where((position) {
          final bool matchesQuery =
              normalizedQuery.isEmpty ||
              position.asset.ticker.toLowerCase().contains(normalizedQuery) ||
              position.asset.name.toLowerCase().contains(normalizedQuery);
          return matchesQuery && filter.accepts(position);
        })
        .toList(growable: false);
    values.sort((InvestmentPosition first, InvestmentPosition second) {
      final int result = switch (sort) {
        InvestmentPositionSort.ticker => first.asset.ticker.compareTo(
          second.asset.ticker,
        ),
        InvestmentPositionSort.highestCost => second.totalCostCents.compareTo(
          first.totalCostCents,
        ),
        InvestmentPositionSort.name => first.asset.name.compareTo(
          second.asset.name,
        ),
      };
      return result != 0
          ? result
          : first.asset.ticker.compareTo(second.asset.ticker);
    });
    return values;
  }

  static bool operationMatchesPeriod({
    required InvestmentOperation operation,
    required InvestmentPeriodFilter period,
    required DateTime now,
  }) {
    final int? months = period.months;
    if (months == null) {
      return true;
    }
    final DateTime today = SaoPauloCivilDate.fromInstant(
      now,
    ).toUtcCalendarDate();
    final DateTime start = _addMonths(
      DateTime.utc(today.year, today.month),
      -(months - 1),
    );
    return !_monthOf(operation.occurredAt).isBefore(start);
  }

  static int _compareOperations(
    InvestmentOperation first,
    InvestmentOperation second,
  ) {
    final int byDate = first.occurredAt.compareTo(second.occurredAt);
    if (byDate != 0) {
      return byDate;
    }
    final int byCreation = first.createdAt.compareTo(second.createdAt);
    return byCreation != 0 ? byCreation : first.id.compareTo(second.id);
  }

  static DateTime _monthOf(DateTime instant) {
    final DateTime date = SaoPauloCivilDate.fromInstant(
      instant,
    ).toUtcCalendarDate();
    return DateTime.utc(date.year, date.month);
  }

  static DateTime _addMonths(DateTime value, int months) {
    final int zeroBased = (value.year * 12) + value.month - 1 + months;
    return DateTime.utc(zeroBased ~/ 12, (zeroBased % 12) + 1);
  }

  static int _monthDistance(DateTime start, DateTime end) =>
      ((end.year - start.year) * 12) + end.month - start.month;

  static List<InvestmentEvolutionBucket> _yearBuckets(
    List<InvestmentOperation> operations, {
    required DateTime start,
    required DateTime end,
  }) {
    final Map<int, _MutableAmounts> totals = <int, _MutableAmounts>{};
    for (final InvestmentOperation operation in operations) {
      final DateTime month = _monthOf(operation.occurredAt);
      if (month.isBefore(start) || month.isAfter(end)) {
        continue;
      }
      totals.putIfAbsent(month.year, _MutableAmounts.new).add(operation);
    }
    return List<InvestmentEvolutionBucket>.generate(end.year - start.year + 1, (
      int index,
    ) {
      final int year = start.year + index;
      final _MutableAmounts amounts = totals[year] ?? _MutableAmounts();
      return InvestmentEvolutionBucket(
        label: '$year',
        buyCents: amounts.buyCents,
        sellCents: amounts.sellCents,
      );
    }, growable: false);
  }
}

final class _MutableAmounts {
  int buyCents = 0;
  int sellCents = 0;

  void add(InvestmentOperation operation) {
    if (operation.kind == InvestmentOperationKind.buy) {
      buyCents = InvestmentArithmetic.checkedInt64(
        BigInt.from(buyCents) +
            BigInt.from(operation.grossAmountCents) +
            BigInt.from(operation.feesCents),
      );
      return;
    }
    sellCents = InvestmentArithmetic.checkedInt64(
      BigInt.from(sellCents) +
          BigInt.from(operation.grossAmountCents) -
          BigInt.from(operation.feesCents),
    );
  }
}

class InvestmentEvolutionChart extends StatelessWidget {
  const InvestmentEvolutionChart({
    required this.buckets,
    required this.valuesVisible,
    super.key,
  });

  final List<InvestmentEvolutionBucket> buckets;
  final bool valuesVisible;

  @override
  Widget build(BuildContext context) {
    if (buckets.isEmpty ||
        buckets.every(
          (InvestmentEvolutionBucket bucket) =>
              bucket.buyCents == 0 && bucket.sellCents == 0,
        )) {
      return const _ChartEmptyState(
        icon: Icons.bar_chart_rounded,
        message: 'Registre uma compra ou venda para formar este gráfico.',
      );
    }
    final AppThemeColors colors = AppThemeColors.of(context);
    final int totalBuys = buckets.fold<int>(
      0,
      (int total, InvestmentEvolutionBucket bucket) => total + bucket.buyCents,
    );
    final int totalSells = buckets.fold<int>(
      0,
      (int total, InvestmentEvolutionBucket bucket) => total + bucket.sellCents,
    );
    final String semantic = valuesVisible
        ? 'Evolução de aportes e vendas. Compras ${InvestmentViewSupport.money(totalBuys, visible: true)}. Vendas ${InvestmentViewSupport.money(totalSells, visible: true)}.'
        : 'Evolução de aportes e vendas com valores ocultos.';
    if (!valuesVisible) {
      return Semantics(
        image: true,
        label: semantic,
        child: const _ChartPrivacyState(),
      );
    }
    return Semantics(
      image: true,
      label: semantic,
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                _ChartLegend(
                  label: 'Compras',
                  value: InvestmentViewSupport.money(
                    totalBuys,
                    visible: valuesVisible,
                  ),
                  color: colors.info,
                  icon: Icons.south_east_rounded,
                ),
                _ChartLegend(
                  label: 'Vendas',
                  value: InvestmentViewSupport.money(
                    totalSells,
                    visible: valuesVisible,
                  ),
                  color: colors.warning,
                  icon: Icons.north_east_rounded,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              key: const ValueKey<String>('investment-evolution-chart'),
              height: MediaQuery.textScalerOf(context).scale(16) > 22
                  ? 188
                  : 156,
              child: CustomPaint(
                painter: _InvestmentEvolutionPainter(
                  buckets: buckets,
                  buyColor: colors.info,
                  sellColor: colors.warning,
                  trackColor: colors.chartTrack,
                  labelColor: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Icon(icon, size: 18, color: color),
      const SizedBox(width: AppSpacing.xs),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          Text(value, style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    ],
  );
}

class _InvestmentEvolutionPainter extends CustomPainter {
  const _InvestmentEvolutionPainter({
    required this.buckets,
    required this.buyColor,
    required this.sellColor,
    required this.trackColor,
    required this.labelColor,
  });

  final List<InvestmentEvolutionBucket> buckets;
  final Color buyColor;
  final Color sellColor;
  final Color trackColor;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    const double labelHeight = 24;
    final double baseline = size.height - labelHeight;
    final Paint baselinePaint = Paint()
      ..color = trackColor
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(0, baseline),
      Offset(size.width, baseline),
      baselinePaint,
    );
    final int maximum = buckets.fold<int>(0, (int value, bucket) {
      return math.max(value, math.max(bucket.buyCents, bucket.sellCents));
    });
    if (maximum <= 0) {
      return;
    }
    final double groupWidth = size.width / buckets.length;
    final double barWidth = math.min(14, math.max(3, groupWidth * 0.24));
    final double availableHeight = baseline - 8;
    for (int index = 0; index < buckets.length; index += 1) {
      final InvestmentEvolutionBucket bucket = buckets[index];
      final double center = (index + 0.5) * groupWidth;
      _drawBar(
        canvas,
        center - (barWidth * 0.62),
        baseline,
        barWidth,
        availableHeight * bucket.buyCents / maximum,
        buyColor,
      );
      _drawBar(
        canvas,
        center + (barWidth * 0.62),
        baseline,
        barWidth,
        availableHeight * bucket.sellCents / maximum,
        sellColor,
      );
    }
    final List<int> labelIndexes = buckets.length <= 6
        ? List<int>.generate(buckets.length, (int index) => index)
        : <int>[0, buckets.length ~/ 2, buckets.length - 1];
    for (final int index in labelIndexes.toSet()) {
      final TextPainter label = TextPainter(
        text: TextSpan(
          text: buckets[index].label,
          style: TextStyle(color: labelColor, fontSize: 10),
        ),
        textDirection: ui.TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: math.max(42, groupWidth * 2));
      final double center = (index + 0.5) * groupWidth;
      label.paint(
        canvas,
        Offset(
          (center - label.width / 2).clamp(0, size.width - label.width),
          baseline + 6,
        ),
      );
    }
  }

  void _drawBar(
    Canvas canvas,
    double center,
    double baseline,
    double width,
    double height,
    Color color,
  ) {
    if (height <= 0) {
      return;
    }
    final Rect rect = Rect.fromLTWH(
      center - width / 2,
      baseline - height,
      width,
      height,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color.lerp(color, Colors.white, 0.22)!, color],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_InvestmentEvolutionPainter oldDelegate) =>
      oldDelegate.buckets != buckets ||
      oldDelegate.buyColor != buyColor ||
      oldDelegate.sellColor != sellColor ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.labelColor != labelColor;
}

class InvestmentAllocationChart extends StatelessWidget {
  const InvestmentAllocationChart({
    required this.slices,
    required this.valuesVisible,
    required this.onSelected,
    super.key,
  });

  final List<InvestmentAllocationSlice> slices;
  final bool valuesVisible;
  final ValueChanged<InvestmentAllocationSlice> onSelected;

  @override
  Widget build(BuildContext context) {
    if (slices.isEmpty) {
      return const _ChartEmptyState(
        icon: Icons.donut_large_rounded,
        message: 'Abra uma posição para visualizar a alocação.',
      );
    }
    final AppThemeColors themeColors = AppThemeColors.of(context);
    final ColorScheme colors = Theme.of(context).colorScheme;
    final List<Color> palette = <Color>[
      colors.primary,
      colors.secondary,
      themeColors.warning,
      themeColors.success,
      colors.tertiary,
      colors.primaryContainer,
    ];
    final String details = valuesVisible
        ? slices
              .map(
                (InvestmentAllocationSlice slice) =>
                    '${slice.label} ${InvestmentViewSupport.percentage(slice.fraction, visible: true)}',
              )
              .join(', ')
        : 'percentuais ocultos';
    return Semantics(
      container: true,
      label: 'Gráfico de alocação por custo acompanhado: $details.',
      child: Column(
        children: <Widget>[
          SizedBox.square(
            key: const ValueKey<String>('investment-allocation-chart'),
            dimension: 164,
            child: CustomPaint(
              painter: _InvestmentDonutPainter(
                fractions: valuesVisible
                    ? slices
                          .map(
                            (InvestmentAllocationSlice slice) => slice.fraction,
                          )
                          .toList(growable: false)
                    : const <double>[1],
                colors: valuesVisible
                    ? palette
                    : <Color>[themeColors.chartTrack],
                trackColor: themeColors.chartTrack,
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(44),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          valuesVisible
                              ? '${slices.length}'
                              : InvestmentViewSupport.hiddenValue,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        Text(
                          slices.length == 1 ? 'grupo' : 'grupos',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (int index = 0; index < slices.length; index += 1)
            _AllocationLegendRow(
              slice: slices[index],
              color: palette[index % palette.length],
              valuesVisible: valuesVisible,
              onTap: () => onSelected(slices[index]),
            ),
        ],
      ),
    );
  }
}

class _InvestmentDonutPainter extends CustomPainter {
  const _InvestmentDonutPainter({
    required this.fractions,
    required this.colors,
    required this.trackColor,
  });

  final List<double> fractions;
  final List<Color> colors;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = (size.shortestSide - 22) / 2;
    final Rect rect = Rect.fromCircle(center: center, radius: radius);
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.butt;
    canvas.drawCircle(center, radius, paint..color = trackColor);
    double cursor = -math.pi / 2;
    const double gap = 0.025;
    for (int index = 0; index < fractions.length; index += 1) {
      final double sweep = (fractions[index] * math.pi * 2) - gap;
      if (sweep <= 0) {
        continue;
      }
      canvas.drawArc(
        rect,
        cursor,
        sweep,
        false,
        paint..color = colors[index % colors.length],
      );
      cursor += sweep + gap;
    }
  }

  @override
  bool shouldRepaint(_InvestmentDonutPainter oldDelegate) =>
      oldDelegate.fractions != fractions ||
      oldDelegate.colors != colors ||
      oldDelegate.trackColor != trackColor;
}

class _AllocationLegendRow extends StatelessWidget {
  const _AllocationLegendRow({
    required this.slice,
    required this.color,
    required this.valuesVisible,
    required this.onTap,
  });

  final InvestmentAllocationSlice slice;
  final Color color;
  final bool valuesVisible;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label:
        '${slice.label}, ${slice.secondaryLabel}, ${InvestmentViewSupport.percentage(slice.fraction, visible: valuesVisible)}',
    child: InkWell(
      onTap: onTap,
      borderRadius: AppRadius.medium,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: AppSpacing.minimumTapTarget,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Row(
            children: <Widget>[
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      slice.label,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    Text(
                      valuesVisible
                          ? slice.secondaryLabel
                          : 'Composição oculta',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    InvestmentViewSupport.percentage(
                      slice.fraction,
                      visible: valuesVisible,
                    ),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  Text(
                    InvestmentViewSupport.money(
                      slice.costCents,
                      visible: valuesVisible,
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(width: AppSpacing.xxs),
              const Icon(Icons.chevron_right_rounded, size: 20),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ChartEmptyState extends StatelessWidget {
  const _ChartEmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 132),
    alignment: Alignment.center,
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: AppRadius.medium,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(height: AppSpacing.sm),
        Text(message, textAlign: TextAlign.center),
      ],
    ),
  );
}

class _ChartPrivacyState extends StatelessWidget {
  const _ChartPrivacyState();

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 132),
    alignment: Alignment.center,
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: AppRadius.medium,
    ),
    child: const Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(Icons.visibility_off_outlined),
        SizedBox(height: AppSpacing.sm),
        Text('Dados do gráfico ocultos', textAlign: TextAlign.center),
      ],
    ),
  );
}
