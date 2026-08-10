import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_failure.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_income_event.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/scaled_investment_value.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/tracked_investment_asset.dart';

void main() {
  group('InvestmentIncomeDraft', () {
    test('valor total preserva bruto, imposto e líquido em centavos', () {
      final InvestmentIncomeDraft draft = _totalDraft().normalized(
        assetType: TrackedInvestmentAssetType.stock,
      );

      expect(draft.grossAmountCents, 12345);
      expect(draft.withholdingTaxCents, 1852);
      expect(draft.netAmountCents, 10493);
      expect(draft.grossAmountCents, isA<int>());
      expect(draft.netAmountCents, isA<int>());
    });

    test('valor por unidade calcula bruto com BigInt e half-up', () {
      final InvestmentIncomeDraft draft = _perUnitDraft(
        quantityScaled: 150000000,
        unitAmountScaled: 1234567,
        grossAmountCents: 185,
      ).normalized(assetType: TrackedInvestmentAssetType.fii);

      expect(draft.grossAmountCents, 185);
      expect(draft.netAmountCents, 185);
      expect(
        InvestmentIncomeEvent.grossFromUnit(
          quantityScaled: 150000000,
          unitAmountScaled: 1234567,
        ),
        185,
      );
    });

    test('arredonda meio centavo para cima deterministicamente', () {
      expect(
        InvestmentIncomeEvent.grossFromUnit(
          quantityScaled: 100000000,
          unitAmountScaled: 5000,
        ),
        1,
      );
    });

    test('aceita grande quantidade segura sem ponto flutuante', () {
      final int gross = InvestmentIncomeEvent.grossFromUnit(
        quantityScaled: 999999999999999,
        unitAmountScaled: 9999,
      );
      final InvestmentIncomeDraft draft = _perUnitDraft(
        quantityScaled: 999999999999999,
        unitAmountScaled: 9999,
        grossAmountCents: gross,
      ).normalized(assetType: TrackedInvestmentAssetType.fii);

      expect(gross, isA<int>());
      expect(draft.netAmountCents, gross);
    });

    test('rejeita imposto negativo ou superior ao bruto', () {
      expect(
        () => _totalDraft(
          taxCents: -1,
        ).normalized(assetType: TrackedInvestmentAssetType.stock),
        throwsA(isA<InvestmentFailure>()),
      );
      expect(
        () => _totalDraft(
          taxCents: 12346,
        ).normalized(assetType: TrackedInvestmentAssetType.stock),
        throwsA(isA<InvestmentFailure>()),
      );
    });

    test('rejeita divergência entre cálculo por unidade e bruto', () {
      expect(
        () => _perUnitDraft(
          quantityScaled: 100000000,
          unitAmountScaled: 1000000,
          grossAmountCents: 99,
        ).normalized(assetType: TrackedInvestmentAssetType.fii),
        throwsA(
          isA<InvestmentFailure>().having(
            (InvestmentFailure value) => value.code,
            'code',
            'investment_income_gross_mismatch',
          ),
        ),
      );
    });

    test('rejeita valor acima do limite monetário do Firestore', () {
      expect(
        () => InvestmentIncomeDraft(
          portfolioId: 'portfolio-1',
          assetId: 'asset-1',
          type: InvestmentIncomeType.dividend,
          inputMode: InvestmentIncomeInputMode.total,
          exDate: null,
          expectedPaymentDate: DateTime.utc(2026, 9, 1, 3),
          eligibleQuantityScaled: null,
          unitAmountScaled: null,
          grossAmountCents: InvestmentScale.maximumMoneyCents + 1,
          withholdingTaxCents: 0,
          notes: '',
        ).normalized(assetType: TrackedInvestmentAssetType.stock),
        throwsA(isA<InvestmentFailure>()),
      );
    });

    test('bloqueia combinações incompatíveis entre ativo e provento', () {
      expect(
        () => _totalDraft(
          type: InvestmentIncomeType.fiiIncome,
        ).normalized(assetType: TrackedInvestmentAssetType.stock),
        throwsA(isA<InvestmentFailure>()),
      );
      expect(
        () => _totalDraft(
          type: InvestmentIncomeType.dividend,
        ).normalized(assetType: TrackedInvestmentAssetType.fii),
        throwsA(isA<InvestmentFailure>()),
      );
    });

    test('normaliza datas previstas futuras como data civil de São Paulo', () {
      final InvestmentIncomeDraft draft = _totalDraft(
        expectedPaymentDate: DateTime(2027, 2, 10, 22),
      ).normalized(assetType: TrackedInvestmentAssetType.stock);

      expect(draft.expectedPaymentDate, DateTime.utc(2027, 2, 10, 3));
    });
  });

  group('InvestmentIncomeEvent', () {
    test('permite somente expected para received ou cancelled', () {
      final InvestmentIncomeEvent event = _event();

      expect(event.canTransitionTo(InvestmentIncomeStatus.received), isTrue);
      expect(event.canTransitionTo(InvestmentIncomeStatus.cancelled), isTrue);
      expect(event.canTransitionTo(InvestmentIncomeStatus.voided), isFalse);
    });

    test('received permite somente voided e terminais não restauram', () {
      final InvestmentIncomeEvent received = _event(
        status: InvestmentIncomeStatus.received,
        receivedDate: DateTime.utc(2026, 8, 4, 3),
      );
      final InvestmentIncomeEvent cancelled = _event(
        status: InvestmentIncomeStatus.cancelled,
        cancelledAt: DateTime.utc(2026, 8, 4, 12),
      );

      expect(received.canTransitionTo(InvestmentIncomeStatus.voided), isTrue);
      expect(
        received.canTransitionTo(InvestmentIncomeStatus.expected),
        isFalse,
      );
      expect(
        cancelled.canTransitionTo(InvestmentIncomeStatus.expected),
        isFalse,
      );
    });

    test('rejeita recebimento com data efetiva futura', () {
      expect(
        () => InvestmentIncomeEvent.validate(
          _event(
            status: InvestmentIncomeStatus.received,
            receivedDate: DateTime.utc(2026, 8, 11, 3),
          ),
          now: DateTime.utc(2026, 8, 10, 12),
        ),
        throwsA(isA<InvestmentFailure>()),
      );
    });

    test('anulação preserva datas e valores financeiros do recebimento', () {
      final InvestmentIncomeEvent event = _event(
        status: InvestmentIncomeStatus.voided,
        receivedDate: DateTime.utc(2026, 8, 4, 3),
        voidedAt: DateTime.utc(2026, 8, 5, 12),
      );

      InvestmentIncomeEvent.validate(event, now: DateTime.utc(2026, 8, 10, 12));
      expect(event.grossAmountCents, 12345);
      expect(event.netAmountCents, 10493);
      expect(event.receivedDate, DateTime.utc(2026, 8, 4, 3));
    });
  });
}

InvestmentIncomeDraft _totalDraft({
  InvestmentIncomeType type = InvestmentIncomeType.dividend,
  int taxCents = 1852,
  DateTime? expectedPaymentDate,
}) => InvestmentIncomeDraft(
  portfolioId: 'portfolio-1',
  assetId: 'portfolio-1__PETR4',
  type: type,
  inputMode: InvestmentIncomeInputMode.total,
  exDate: DateTime.utc(2026, 8, 1, 3),
  expectedPaymentDate: expectedPaymentDate ?? DateTime.utc(2026, 9, 1, 3),
  eligibleQuantityScaled: null,
  unitAmountScaled: null,
  grossAmountCents: 12345,
  withholdingTaxCents: taxCents,
  notes: 'Provento manual',
);

InvestmentIncomeDraft _perUnitDraft({
  required int quantityScaled,
  required int unitAmountScaled,
  required int grossAmountCents,
}) => InvestmentIncomeDraft(
  portfolioId: 'portfolio-1',
  assetId: 'portfolio-1__HGLG11',
  type: InvestmentIncomeType.fiiIncome,
  inputMode: InvestmentIncomeInputMode.perUnit,
  exDate: null,
  expectedPaymentDate: DateTime.utc(2026, 9, 15, 3),
  eligibleQuantityScaled: quantityScaled,
  unitAmountScaled: unitAmountScaled,
  grossAmountCents: grossAmountCents,
  withholdingTaxCents: 0,
  notes: '',
);

InvestmentIncomeEvent _event({
  InvestmentIncomeStatus status = InvestmentIncomeStatus.expected,
  DateTime? receivedDate,
  DateTime? cancelledAt,
  DateTime? voidedAt,
}) => InvestmentIncomeEvent(
  id: 'income-1',
  ownerId: 'owner',
  portfolioId: 'portfolio-1',
  assetId: 'portfolio-1__PETR4',
  type: InvestmentIncomeType.dividend,
  status: status,
  inputMode: InvestmentIncomeInputMode.total,
  exDate: DateTime.utc(2026, 8, 1, 3),
  expectedPaymentDate: DateTime.utc(2026, 9, 1, 3),
  receivedDate: receivedDate,
  eligibleQuantityScaled: null,
  unitAmountScaled: null,
  grossAmountCents: 12345,
  withholdingTaxCents: 1852,
  netAmountCents: 10493,
  notes: 'Provento manual',
  originType: InvestmentIncomeOriginType.manual,
  externalId: null,
  cancelledAt: cancelledAt,
  voidedAt: voidedAt,
  mutationId: 'mutation-1',
  createdAt: DateTime.utc(2026, 8, 1, 12),
  updatedAt: DateTime.utc(2026, 8, 1, 12),
  schemaVersion: 1,
  revision: 1,
);
