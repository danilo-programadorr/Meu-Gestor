import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:meu_gestor_financeiro/app/theme/app_radius.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
import 'package:meu_gestor_financeiro/core/dates/sao_paulo_civil_date.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_income_event.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/scaled_investment_value.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/tracked_investment_asset.dart';
import 'package:meu_gestor_financeiro/features/investments/presentation/widgets/investment_view_support.dart';

enum InvestmentIncomePeriodFilter {
  last3Months('3 meses', 3),
  last6Months('6 meses', 6),
  last12Months('12 meses', 12),
  all('Todo o período', null);

  const InvestmentIncomePeriodFilter(this.label, this.months);

  final String label;
  final int? months;
}

enum InvestmentIncomeHistoryMode {
  monthly('Mensal'),
  annual('Anual');

  const InvestmentIncomeHistoryMode(this.label);

  final String label;
}

final class InvestmentIncomeMonthBucket {
  const InvestmentIncomeMonthBucket({
    required this.label,
    required this.receivedCents,
    required this.expectedCents,
  });

  final String label;
  final int receivedCents;
  final int expectedCents;
}

final class InvestmentIncomeDistributionSlice {
  const InvestmentIncomeDistributionSlice({
    required this.assetId,
    required this.label,
    required this.amountCents,
    required this.fraction,
  });

  final String assetId;
  final String label;
  final int amountCents;
  final double fraction;
}

final class InvestmentIncomeHistoryBucket {
  const InvestmentIncomeHistoryBucket({
    required this.label,
    required this.receivedCents,
    required this.expectedCents,
  });

  final String label;
  final int receivedCents;
  final int expectedCents;
}

abstract final class InvestmentIncomeAnalytics {
  static List<InvestmentIncomeEvent> filter({
    required Iterable<InvestmentIncomeEvent> events,
    required String portfolioId,
    required InvestmentIncomePeriodFilter period,
    required DateTime now,
    String? assetId,
    InvestmentIncomeType? type,
    InvestmentIncomeStatus? status,
  }) {
    final DateTime? start = _periodStart(period, now);
    final List<InvestmentIncomeEvent> values = events
        .where((event) {
          final DateTime month = _monthOf(event.relevantDate);
          return event.portfolioId == portfolioId &&
              (assetId == null || event.assetId == assetId) &&
              (type == null || event.type == type) &&
              (status == null || event.status == status) &&
              (start == null || !month.isBefore(start));
        })
        .toList(growable: false);
    values.sort((first, second) {
      final int byDate = second.relevantDate.compareTo(first.relevantDate);
      return byDate != 0 ? byDate : second.id.compareTo(first.id);
    });
    return values;
  }

  static int receivedTotal(Iterable<InvestmentIncomeEvent> events) => events
      .where((event) => event.status == InvestmentIncomeStatus.received)
      .fold<int>(
        0,
        (int total, InvestmentIncomeEvent event) =>
            InvestmentArithmetic.checkedInt64(
              BigInt.from(total) + BigInt.from(event.netAmountCents),
            ),
      );

  static int expectedTotal(Iterable<InvestmentIncomeEvent> events) => events
      .where((event) => event.status == InvestmentIncomeStatus.expected)
      .fold<int>(
        0,
        (int total, InvestmentIncomeEvent event) =>
            InvestmentArithmetic.checkedInt64(
              BigInt.from(total) + BigInt.from(event.netAmountCents),
            ),
      );

  static List<InvestmentIncomeMonthBucket> last12Months({
    required Iterable<InvestmentIncomeEvent> events,
    required DateTime now,
  }) {
    final DateTime today = SaoPauloCivilDate.fromInstant(
      now,
    ).toUtcCalendarDate();
    final DateTime end = DateTime.utc(today.year, today.month);
    final DateTime start = _addMonths(end, -11);
    final Map<String, _IncomeTotals> totals = <String, _IncomeTotals>{};
    for (final InvestmentIncomeEvent event in events) {
      if (event.status != InvestmentIncomeStatus.received &&
          event.status != InvestmentIncomeStatus.expected) {
        continue;
      }
      final DateTime month = _monthOf(event.relevantDate);
      if (month.isBefore(start) || month.isAfter(end)) {
        continue;
      }
      totals
          .putIfAbsent('${month.year}-${month.month}', _IncomeTotals.new)
          .add(event);
    }
    return List<InvestmentIncomeMonthBucket>.generate(12, (int index) {
      final DateTime month = _addMonths(start, index);
      final _IncomeTotals values =
          totals['${month.year}-${month.month}'] ?? _IncomeTotals();
      return InvestmentIncomeMonthBucket(
        label: DateFormat('MM/yy', 'pt_BR').format(month),
        receivedCents: values.receivedCents,
        expectedCents: values.expectedCents,
      );
    }, growable: false);
  }

  static List<InvestmentIncomeDistributionSlice> distributionByAsset({
    required Iterable<InvestmentIncomeEvent> events,
    required Iterable<TrackedInvestmentAsset> assets,
  }) {
    final Map<String, int> totals = <String, int>{};
    for (final InvestmentIncomeEvent event in events) {
      if (event.status != InvestmentIncomeStatus.received) {
        continue;
      }
      totals.update(
        event.assetId,
        (int value) => InvestmentArithmetic.checkedInt64(
          BigInt.from(value) + BigInt.from(event.netAmountCents),
        ),
        ifAbsent: () => event.netAmountCents,
      );
    }
    final int total = totals.values.fold<int>(
      0,
      (int sum, int value) => InvestmentArithmetic.checkedInt64(
        BigInt.from(sum) + BigInt.from(value),
      ),
    );
    if (total <= 0) {
      return const <InvestmentIncomeDistributionSlice>[];
    }
    final Map<String, TrackedInvestmentAsset> byId =
        <String, TrackedInvestmentAsset>{
          for (final TrackedInvestmentAsset asset in assets) asset.id: asset,
        };
    final List<InvestmentIncomeDistributionSlice> result = totals.entries
        .map(
          (entry) => InvestmentIncomeDistributionSlice(
            assetId: entry.key,
            label: byId[entry.key]?.ticker ?? 'Ativo',
            amountCents: entry.value,
            fraction: entry.value / total,
          ),
        )
        .toList(growable: false);
    result.sort((first, second) {
      final int byAmount = second.amountCents.compareTo(first.amountCents);
      return byAmount != 0 ? byAmount : first.label.compareTo(second.label);
    });
    return result;
  }

  static List<InvestmentIncomeHistoryBucket> history({
    required Iterable<InvestmentIncomeEvent> events,
    required InvestmentIncomeHistoryMode mode,
  }) {
    final Map<String, _IncomeTotals> totals = <String, _IncomeTotals>{};
    final Map<String, DateTime> dates = <String, DateTime>{};
    for (final InvestmentIncomeEvent event in events) {
      if (event.status != InvestmentIncomeStatus.received &&
          event.status != InvestmentIncomeStatus.expected) {
        continue;
      }
      final DateTime month = _monthOf(event.relevantDate);
      final String key = mode == InvestmentIncomeHistoryMode.monthly
          ? '${month.year}-${month.month}'
          : '${month.year}';
      dates[key] = mode == InvestmentIncomeHistoryMode.monthly
          ? month
          : DateTime.utc(month.year);
      totals.putIfAbsent(key, _IncomeTotals.new).add(event);
    }
    final List<String> keys = totals.keys.toList(growable: false)
      ..sort((first, second) => dates[second]!.compareTo(dates[first]!));
    return keys
        .map((String key) {
          final DateTime date = dates[key]!;
          final _IncomeTotals values = totals[key]!;
          return InvestmentIncomeHistoryBucket(
            label: mode == InvestmentIncomeHistoryMode.monthly
                ? DateFormat('MMMM yyyy', 'pt_BR').format(date)
                : '${date.year}',
            receivedCents: values.receivedCents,
            expectedCents: values.expectedCents,
          );
        })
        .toList(growable: false);
  }

  static DateTime? _periodStart(
    InvestmentIncomePeriodFilter period,
    DateTime now,
  ) {
    if (period.months == null) {
      return null;
    }
    final DateTime today = SaoPauloCivilDate.fromInstant(
      now,
    ).toUtcCalendarDate();
    return _addMonths(
      DateTime.utc(today.year, today.month),
      -(period.months! - 1),
    );
  }

  static DateTime _monthOf(DateTime value) {
    final SaoPauloCivilDate date = SaoPauloCivilDate.fromInstant(value);
    return DateTime.utc(date.year, date.month);
  }

  static DateTime _addMonths(DateTime value, int months) {
    final int zeroBased = (value.year * 12) + value.month - 1 + months;
    return DateTime.utc(zeroBased ~/ 12, (zeroBased % 12) + 1);
  }
}

final class _IncomeTotals {
  int receivedCents = 0;
  int expectedCents = 0;

  void add(InvestmentIncomeEvent event) {
    if (event.status == InvestmentIncomeStatus.received) {
      receivedCents = InvestmentArithmetic.checkedInt64(
        BigInt.from(receivedCents) + BigInt.from(event.netAmountCents),
      );
    } else if (event.status == InvestmentIncomeStatus.expected) {
      expectedCents = InvestmentArithmetic.checkedInt64(
        BigInt.from(expectedCents) + BigInt.from(event.netAmountCents),
      );
    }
  }
}

class InvestmentIncomeColumnsChart extends StatelessWidget {
  const InvestmentIncomeColumnsChart({
    required this.buckets,
    required this.valuesVisible,
    super.key,
  });

  final List<InvestmentIncomeMonthBucket> buckets;
  final bool valuesVisible;

  @override
  Widget build(BuildContext context) {
    if (!valuesVisible) {
      return const _IncomePrivacyState();
    }
    final bool hasValues = buckets.any(
      (bucket) => bucket.receivedCents > 0 || bucket.expectedCents > 0,
    );
    if (!hasValues) {
      return const _IncomeEmptyState(
        message: 'Ainda não há valores nos últimos 12 meses.',
      );
    }
    final Color received = Theme.of(context).colorScheme.primary;
    final Color expected = Theme.of(context).colorScheme.secondary;
    final String semantics = buckets
        .where((bucket) => bucket.receivedCents > 0 || bucket.expectedCents > 0)
        .map(
          (bucket) =>
              '${bucket.label}: recebido ${InvestmentViewSupport.money(bucket.receivedCents, visible: true)}, previsto ${InvestmentViewSupport.money(bucket.expectedCents, visible: true)}',
        )
        .join('; ');
    return Semantics(
      label: 'Evolução de proventos. $semantics',
      child: Column(
        children: <Widget>[
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              _IncomeLegend(color: received, label: 'Recebido'),
              _IncomeLegend(color: expected, label: 'Previsto'),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 190,
            child: CustomPaint(
              painter: _IncomeColumnsPainter(
                buckets: buckets,
                receivedColor: received,
                expectedColor: expected,
                gridColor: Theme.of(context).dividerColor,
                labelColor: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }
}

class InvestmentIncomeDonutChart extends StatelessWidget {
  const InvestmentIncomeDonutChart({
    required this.slices,
    required this.valuesVisible,
    super.key,
  });

  final List<InvestmentIncomeDistributionSlice> slices;
  final bool valuesVisible;

  static const List<Color> _colors = <Color>[
    Color(0xFF246B87),
    Color(0xFF5A8FB0),
    Color(0xFF8CB8CC),
    Color(0xFF6F7FA1),
    Color(0xFF91A8B7),
  ];

  @override
  Widget build(BuildContext context) {
    if (!valuesVisible) {
      return const _IncomePrivacyState();
    }
    if (slices.isEmpty) {
      return const _IncomeEmptyState(
        message: 'Confirme um recebimento para ver a distribuição por ativo.',
      );
    }
    final String semantics = slices
        .map(
          (slice) =>
              '${slice.label}: ${(slice.fraction * 100).toStringAsFixed(1)} por cento, ${InvestmentViewSupport.money(slice.amountCents, visible: true)}',
        )
        .join('; ');
    return Semantics(
      label: 'Distribuição de proventos recebidos por ativo. $semantics',
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool compact = constraints.maxWidth < 380;
          final Widget chart = SizedBox(
            width: 156,
            height: 156,
            child: CustomPaint(
              painter: _IncomeDonutPainter(slices: slices, colors: _colors),
            ),
          );
          final Widget legend = Column(
            children: List<Widget>.generate(slices.length, (int index) {
              final InvestmentIncomeDistributionSlice slice = slices[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _colors[index % _colors.length],
                        borderRadius: AppRadius.small,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(child: Text(slice.label)),
                    Text('${(slice.fraction * 100).toStringAsFixed(1)}%'),
                  ],
                ),
              );
            }),
          );
          return compact
              ? Column(
                  children: <Widget>[
                    chart,
                    const SizedBox(height: AppSpacing.md),
                    legend,
                  ],
                )
              : Row(
                  children: <Widget>[
                    chart,
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: legend),
                  ],
                );
        },
      ),
    );
  }
}

class _IncomeColumnsPainter extends CustomPainter {
  const _IncomeColumnsPainter({
    required this.buckets,
    required this.receivedColor,
    required this.expectedColor,
    required this.gridColor,
    required this.labelColor,
  });

  final List<InvestmentIncomeMonthBucket> buckets;
  final Color receivedColor;
  final Color expectedColor;
  final Color gridColor;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    const double bottom = 30;
    const double top = 8;
    final Rect plot = Rect.fromLTWH(
      0,
      top,
      size.width,
      size.height - top - bottom,
    );
    final int maximum = buckets.fold<int>(0, (int value, bucket) {
      return math.max(
        value,
        math.max(bucket.receivedCents, bucket.expectedCents),
      );
    });
    final Paint grid = Paint()..color = gridColor.withValues(alpha: 0.45);
    for (int index = 0; index <= 3; index += 1) {
      final double y = plot.bottom - (plot.height * index / 3);
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
    }
    final double groupWidth = plot.width / buckets.length;
    final double barWidth = math.max(3, math.min(10, groupWidth * 0.28));
    for (int index = 0; index < buckets.length; index += 1) {
      final InvestmentIncomeMonthBucket bucket = buckets[index];
      final double center = plot.left + groupWidth * (index + 0.5);
      _drawBar(
        canvas,
        plot,
        x: center - barWidth - 1,
        width: barWidth,
        amount: bucket.receivedCents,
        maximum: maximum,
        color: receivedColor,
      );
      _drawBar(
        canvas,
        plot,
        x: center + 1,
        width: barWidth,
        amount: bucket.expectedCents,
        maximum: maximum,
        color: expectedColor,
      );
      if (index.isEven) {
        final TextPainter label = TextPainter(
          text: TextSpan(
            text: bucket.label,
            style: TextStyle(color: labelColor, fontSize: 9),
          ),
          textDirection: ui.TextDirection.ltr,
        )..layout(maxWidth: groupWidth * 2);
        label.paint(canvas, Offset(center - label.width / 2, plot.bottom + 8));
      }
    }
  }

  void _drawBar(
    Canvas canvas,
    Rect plot, {
    required double x,
    required double width,
    required int amount,
    required int maximum,
    required Color color,
  }) {
    if (amount <= 0 || maximum <= 0) {
      return;
    }
    final double height = math.max(2, plot.height * amount / maximum);
    final RRect bar = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, plot.bottom - height, width, height),
      const Radius.circular(4),
    );
    canvas.drawRRect(bar, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_IncomeColumnsPainter oldDelegate) =>
      oldDelegate.buckets != buckets ||
      oldDelegate.receivedColor != receivedColor ||
      oldDelegate.expectedColor != expectedColor;
}

class _IncomeDonutPainter extends CustomPainter {
  const _IncomeDonutPainter({required this.slices, required this.colors});

  final List<InvestmentIncomeDistributionSlice> slices;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = math.min(size.width, size.height) / 2 - 8;
    final Rect rect = Rect.fromCircle(center: center, radius: radius);
    double start = -math.pi / 2;
    for (int index = 0; index < slices.length; index += 1) {
      final double sweep = math.pi * 2 * slices[index].fraction;
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..color = colors[index % colors.length]
          ..style = PaintingStyle.stroke
          ..strokeWidth = 28
          ..strokeCap = StrokeCap.butt,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_IncomeDonutPainter oldDelegate) =>
      oldDelegate.slices != slices;
}

class _IncomeLegend extends StatelessWidget {
  const _IncomeLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: color, borderRadius: AppRadius.small),
      ),
      const SizedBox(width: AppSpacing.xs),
      Text(label),
    ],
  );
}

class _IncomeEmptyState extends StatelessWidget {
  const _IncomeEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 128,
    child: Center(child: Text(message, textAlign: TextAlign.center)),
  );
}

class _IncomePrivacyState extends StatelessWidget {
  const _IncomePrivacyState();

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 128,
    child: Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.visibility_off_outlined),
          SizedBox(width: AppSpacing.sm),
          Flexible(child: Text('Gráfico oculto pela privacidade financeira.')),
        ],
      ),
    ),
  );
}
