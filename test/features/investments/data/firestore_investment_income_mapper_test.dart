import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/investments/data/firestore_investment_mappers.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_failure.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_income_event.dart';

void main() {
  test('mapper estrito converte provento manual previsto', () {
    final InvestmentIncomeEvent event =
        FirestoreInvestmentIncomeEventMapper.fromMap(
          data: _map(),
          documentId: 'income-1',
          expectedOwnerId: 'owner',
          now: DateTime.utc(2026, 8, 10, 12),
        );

    expect(event.status, InvestmentIncomeStatus.expected);
    expect(event.originType, InvestmentIncomeOriginType.manual);
    expect(event.netAmountCents, 850);
  });

  test('mapper rejeita campo extra, ausente ou proprietário divergente', () {
    expect(
      () => FirestoreInvestmentIncomeEventMapper.fromMap(
        data: <String, dynamic>{..._map(), 'extra': true},
        documentId: 'income-1',
        expectedOwnerId: 'owner',
        now: DateTime.utc(2026, 8, 10, 12),
      ),
      throwsA(isA<InvestmentFailure>()),
    );
    final Map<String, dynamic> missing = _map()..remove('netAmountCents');
    expect(
      () => FirestoreInvestmentIncomeEventMapper.fromMap(
        data: missing,
        documentId: 'income-1',
        expectedOwnerId: 'owner',
        now: DateTime.utc(2026, 8, 10, 12),
      ),
      throwsA(isA<InvestmentFailure>()),
    );
    expect(
      () => FirestoreInvestmentIncomeEventMapper.fromMap(
        data: _map(),
        documentId: 'income-1',
        expectedOwnerId: 'other',
        now: DateTime.utc(2026, 8, 10, 12),
      ),
      throwsA(isA<InvestmentFailure>()),
    );
  });

  test(
    'mapper rejeita líquido divergente e origem automática não suportada',
    () {
      expect(
        () => FirestoreInvestmentIncomeEventMapper.fromMap(
          data: _map(<String, Object?>{'netAmountCents': 851}),
          documentId: 'income-1',
          expectedOwnerId: 'owner',
          now: DateTime.utc(2026, 8, 10, 12),
        ),
        throwsA(isA<InvestmentFailure>()),
      );
      expect(
        () => FirestoreInvestmentIncomeEventMapper.fromMap(
          data: _map(<String, Object?>{'originType': 'provider'}),
          documentId: 'income-1',
          expectedOwnerId: 'owner',
          now: DateTime.utc(2026, 8, 10, 12),
        ),
        throwsA(isA<InvestmentFailure>()),
      );
    },
  );

  test('mapa de criação contém campos exatos e valores canônicos', () {
    final InvestmentIncomeDraft draft = InvestmentIncomeDraft(
      portfolioId: 'portfolio-1',
      assetId: 'portfolio-1__PETR4',
      type: InvestmentIncomeType.dividend,
      inputMode: InvestmentIncomeInputMode.total,
      exDate: null,
      expectedPaymentDate: DateTime.utc(2026, 9, 1, 3),
      eligibleQuantityScaled: null,
      unitAmountScaled: null,
      grossAmountCents: 1000,
      withholdingTaxCents: 150,
      notes: '',
    );
    final Map<String, Object?> map =
        FirestoreInvestmentIncomeEventMapper.creationMap(
          ownerId: 'owner',
          eventId: 'income-1',
          draft: draft,
        );

    expect(map.keys.toSet(), FirestoreInvestmentIncomeEventMapper.fieldNames);
    expect(map['status'], 'expected');
    expect(map['netAmountCents'], 850);
    expect(map['mutationId'], 'income-1');
    expect(map['externalId'], isNull);
  });

  test('matchesDraft não aceita alteração financeira após tentativa', () {
    final InvestmentIncomeEvent event =
        FirestoreInvestmentIncomeEventMapper.fromMap(
          data: _map(),
          documentId: 'income-1',
          expectedOwnerId: 'owner',
          now: DateTime.utc(2026, 8, 10, 12),
        );
    final InvestmentIncomeDraft same = InvestmentIncomeDraft(
      portfolioId: event.portfolioId,
      assetId: event.assetId,
      type: event.type,
      inputMode: event.inputMode,
      exDate: event.exDate,
      expectedPaymentDate: event.expectedPaymentDate,
      eligibleQuantityScaled: event.eligibleQuantityScaled,
      unitAmountScaled: event.unitAmountScaled,
      grossAmountCents: event.grossAmountCents,
      withholdingTaxCents: event.withholdingTaxCents,
      notes: event.notes,
    );

    expect(
      FirestoreInvestmentIncomeEventMapper.matchesDraft(event, same),
      isTrue,
    );
    expect(
      FirestoreInvestmentIncomeEventMapper.matchesDraft(
        event,
        InvestmentIncomeDraft(
          portfolioId: same.portfolioId,
          assetId: same.assetId,
          type: same.type,
          inputMode: same.inputMode,
          exDate: same.exDate,
          expectedPaymentDate: same.expectedPaymentDate,
          eligibleQuantityScaled: same.eligibleQuantityScaled,
          unitAmountScaled: same.unitAmountScaled,
          grossAmountCents: 999,
          withholdingTaxCents: 149,
          notes: same.notes,
        ),
      ),
      isFalse,
    );
  });
}

Map<String, dynamic> _map([Map<String, Object?> overrides = const {}]) =>
    <String, dynamic>{
      'ownerId': 'owner',
      'portfolioId': 'portfolio-1',
      'assetId': 'portfolio-1__PETR4',
      'incomeType': 'dividend',
      'status': 'expected',
      'inputMode': 'total',
      'exDate': null,
      'expectedPaymentDate': Timestamp.fromDate(DateTime.utc(2026, 9, 1, 3)),
      'receivedDate': null,
      'eligibleQuantityScaled': null,
      'unitAmountScaled': null,
      'grossAmountCents': 1000,
      'withholdingTaxCents': 150,
      'netAmountCents': 850,
      'notes': '',
      'originType': 'manual',
      'externalId': null,
      'cancelledAt': null,
      'voidedAt': null,
      'mutationId': 'income-1',
      'createdAt': Timestamp.fromDate(DateTime.utc(2026, 8, 1, 12)),
      'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 8, 1, 12)),
      'schemaVersion': 1,
      'revision': 1,
      ...overrides,
    };
