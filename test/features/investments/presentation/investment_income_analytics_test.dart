import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_income_event.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/tracked_investment_asset.dart';
import 'package:meu_gestor_financeiro/features/investments/presentation/widgets/investment_income_analytics.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  test('totais consideram somente expected e received ativos', () {
    final List<InvestmentIncomeEvent> events = <InvestmentIncomeEvent>[
      _event('received', InvestmentIncomeStatus.received, 1000),
      _event('expected', InvestmentIncomeStatus.expected, 500),
      _event('cancelled', InvestmentIncomeStatus.cancelled, 300),
      _event('voided', InvestmentIncomeStatus.voided, 700),
    ];

    expect(InvestmentIncomeAnalytics.receivedTotal(events), 1000);
    expect(InvestmentIncomeAnalytics.expectedTotal(events), 500);
  });

  test('últimos 12 meses agrega recebido e previsto sem dados fictícios', () {
    final List<InvestmentIncomeMonthBucket> buckets =
        InvestmentIncomeAnalytics.last12Months(
          events: <InvestmentIncomeEvent>[
            _event(
              'received',
              InvestmentIncomeStatus.received,
              1000,
              date: DateTime.utc(2026, 7, 15, 3),
            ),
            _event(
              'expected',
              InvestmentIncomeStatus.expected,
              500,
              date: DateTime.utc(2026, 8, 20, 3),
            ),
          ],
          now: DateTime.utc(2026, 8, 10, 12),
        );

    expect(buckets, hasLength(12));
    expect(buckets[buckets.length - 2].receivedCents, 1000);
    expect(buckets.last.expectedCents, 500);
  });

  test('distribuição usa somente recebidos e ordena por valor', () {
    final List<InvestmentIncomeDistributionSlice> values =
        InvestmentIncomeAnalytics.distributionByAsset(
          events: <InvestmentIncomeEvent>[
            _event('a', InvestmentIncomeStatus.received, 300, assetId: 'a'),
            _event('b', InvestmentIncomeStatus.received, 700, assetId: 'b'),
            _event(
              'future',
              InvestmentIncomeStatus.expected,
              900,
              assetId: 'a',
            ),
          ],
          assets: <TrackedInvestmentAsset>[
            _asset('a', 'PETR4'),
            _asset('b', 'HGLG11'),
          ],
        );

    expect(values.map((value) => value.label), <String>['HGLG11', 'PETR4']);
    expect(values.first.fraction, 0.7);
  });

  test('filtros combinam período, ativo, tipo e status', () {
    final List<InvestmentIncomeEvent> values = InvestmentIncomeAnalytics.filter(
      events: <InvestmentIncomeEvent>[
        _event('a', InvestmentIncomeStatus.received, 300, assetId: 'a'),
        _event(
          'b',
          InvestmentIncomeStatus.received,
          700,
          assetId: 'b',
          type: InvestmentIncomeType.fiiIncome,
        ),
      ],
      portfolioId: 'portfolio-1',
      period: InvestmentIncomePeriodFilter.last12Months,
      now: DateTime.utc(2026, 8, 10, 12),
      assetId: 'b',
      type: InvestmentIncomeType.fiiIncome,
      status: InvestmentIncomeStatus.received,
    );

    expect(values.single.id, 'b');
  });

  test('histórico mensal e anual preserva totais reais', () {
    final List<InvestmentIncomeEvent> events = <InvestmentIncomeEvent>[
      _event('a', InvestmentIncomeStatus.received, 300),
      _event('b', InvestmentIncomeStatus.expected, 700),
    ];

    final List<InvestmentIncomeHistoryBucket> monthly =
        InvestmentIncomeAnalytics.history(
          events: events,
          mode: InvestmentIncomeHistoryMode.monthly,
        );
    final List<InvestmentIncomeHistoryBucket> annual =
        InvestmentIncomeAnalytics.history(
          events: events,
          mode: InvestmentIncomeHistoryMode.annual,
        );

    expect(monthly.single.receivedCents, 300);
    expect(monthly.single.expectedCents, 700);
    expect(annual.single.receivedCents, 300);
    expect(annual.single.expectedCents, 700);
  });

  test('ordenação desempata datas iguais pelo ID de forma estável', () {
    final List<InvestmentIncomeEvent> values = InvestmentIncomeAnalytics.filter(
      events: <InvestmentIncomeEvent>[
        _event('income-a', InvestmentIncomeStatus.expected, 100),
        _event('income-c', InvestmentIncomeStatus.expected, 100),
        _event('income-b', InvestmentIncomeStatus.expected, 100),
      ],
      portfolioId: 'portfolio-1',
      period: InvestmentIncomePeriodFilter.all,
      now: DateTime.utc(2026, 8, 10, 12),
    );

    expect(values.map((value) => value.id), <String>[
      'income-c',
      'income-b',
      'income-a',
    ]);
  });
}

InvestmentIncomeEvent _event(
  String id,
  InvestmentIncomeStatus status,
  int netCents, {
  String assetId = 'a',
  InvestmentIncomeType type = InvestmentIncomeType.dividend,
  DateTime? date,
}) {
  final DateTime value = date ?? DateTime.utc(2026, 8, 1, 3);
  return InvestmentIncomeEvent(
    id: id,
    ownerId: 'owner',
    portfolioId: 'portfolio-1',
    assetId: assetId,
    type: type,
    status: status,
    inputMode: InvestmentIncomeInputMode.total,
    exDate: null,
    expectedPaymentDate: value,
    receivedDate:
        status == InvestmentIncomeStatus.received ||
            status == InvestmentIncomeStatus.voided
        ? value
        : null,
    eligibleQuantityScaled: null,
    unitAmountScaled: null,
    grossAmountCents: netCents,
    withholdingTaxCents: 0,
    netAmountCents: netCents,
    notes: '',
    originType: InvestmentIncomeOriginType.manual,
    externalId: null,
    cancelledAt: status == InvestmentIncomeStatus.cancelled
        ? DateTime.utc(2026, 8, 2, 12)
        : null,
    voidedAt: status == InvestmentIncomeStatus.voided
        ? DateTime.utc(2026, 8, 2, 12)
        : null,
    mutationId: 'mutation-$id',
    createdAt: DateTime.utc(2026, 8, 1, 12),
    updatedAt: DateTime.utc(2026, 8, 1, 12),
    schemaVersion: 1,
    revision: 1,
  );
}

TrackedInvestmentAsset _asset(String id, String ticker) =>
    TrackedInvestmentAsset(
      id: id,
      ownerId: 'owner',
      portfolioId: 'portfolio-1',
      ticker: ticker,
      name: ticker,
      type: ticker.endsWith('11')
          ? TrackedInvestmentAssetType.fii
          : TrackedInvestmentAssetType.stock,
      currencyCode: 'BRL',
      currentQuantityScaled: 0,
      lastOperationId: null,
      lastOperationAt: null,
      createdAt: DateTime.utc(2026, 8, 1, 12),
      updatedAt: DateTime.utc(2026, 8, 1, 12),
      schemaVersion: 1,
      revision: 1,
    );
