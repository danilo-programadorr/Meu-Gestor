import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_failure.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_income_event.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_operation.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_portfolio.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/tracked_investment_asset.dart';

abstract final class FirestoreInvestmentPortfolioMapper {
  static const Set<String> fieldNamesV1 = <String>{
    'ownerId',
    'name',
    'description',
    'isArchived',
    'archivedAt',
    'createdAt',
    'updatedAt',
    'schemaVersion',
    'revision',
  };

  static const Set<String> fieldNamesV2 = <String>{
    ...fieldNamesV1,
    'hasHistory',
  };

  static InvestmentPortfolio fromMap({
    required Map<String, dynamic> data,
    required String documentId,
    required String expectedOwnerId,
  }) {
    try {
      final int schemaVersion = _integer(data, 'schemaVersion');
      _requireExactFields(
        data,
        schemaVersion == 1 ? fieldNamesV1 : fieldNamesV2,
      );
      final InvestmentPortfolio portfolio = InvestmentPortfolio(
        id: documentId,
        ownerId: _string(data, 'ownerId'),
        name: _string(data, 'name'),
        description: _string(data, 'description'),
        isArchived: _boolean(data, 'isArchived'),
        archivedAt: _nullableDateTime(data, 'archivedAt'),
        hasHistory: schemaVersion == 1 ? true : _boolean(data, 'hasHistory'),
        createdAt: _dateTime(data, 'createdAt'),
        updatedAt: _dateTime(data, 'updatedAt'),
        schemaVersion: schemaVersion,
        revision: _integer(data, 'revision'),
      );
      if (portfolio.ownerId != expectedOwnerId) {
        throw StateError('portfolio_owner_mismatch');
      }
      InvestmentPortfolio.validate(portfolio);
      return portfolio;
    } on InvestmentFailure {
      rethrow;
    } on Object {
      throw _conversionFailure('investment_portfolio_conversion_failed');
    }
  }

  static Map<String, Object?> creationMap({
    required String ownerId,
    required InvestmentPortfolioDraft draft,
  }) {
    final InvestmentPortfolioDraft normalized = draft.normalized();
    return <String, Object?>{
      'ownerId': ownerId,
      'name': normalized.name,
      'description': normalized.description,
      'isArchived': false,
      'archivedAt': null,
      'hasHistory': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'schemaVersion': InvestmentPortfolio.currentSchemaVersion,
      'revision': 1,
    };
  }

  static bool matchesDraft(
    InvestmentPortfolio portfolio,
    InvestmentPortfolioDraft draft,
  ) {
    final InvestmentPortfolioDraft normalized = draft.normalized();
    return portfolio.name == normalized.name &&
        portfolio.description == normalized.description;
  }
}

abstract final class FirestoreTrackedInvestmentAssetMapper {
  static const Set<String> fieldNamesV1 = <String>{
    'ownerId',
    'portfolioId',
    'ticker',
    'name',
    'assetType',
    'currencyCode',
    'currentQuantityScaled',
    'lastOperationId',
    'lastOperationAt',
    'createdAt',
    'updatedAt',
    'schemaVersion',
    'revision',
  };

  static const Set<String> fieldNamesV2 = <String>{
    ...fieldNamesV1,
    'isArchived',
    'archivedAt',
    'hasHistory',
  };

  static TrackedInvestmentAsset fromMap({
    required Map<String, dynamic> data,
    required String documentId,
    required String expectedOwnerId,
  }) {
    try {
      final int schemaVersion = _integer(data, 'schemaVersion');
      _requireExactFields(
        data,
        schemaVersion == 1 ? fieldNamesV1 : fieldNamesV2,
      );
      final TrackedInvestmentAsset asset = TrackedInvestmentAsset(
        id: documentId,
        ownerId: _string(data, 'ownerId'),
        portfolioId: _string(data, 'portfolioId'),
        ticker: _string(data, 'ticker'),
        name: _string(data, 'name'),
        type: TrackedInvestmentAssetType.fromStorage(
          _string(data, 'assetType'),
        ),
        currencyCode: _string(data, 'currencyCode'),
        currentQuantityScaled: _integer(data, 'currentQuantityScaled'),
        lastOperationId: _nullableString(data, 'lastOperationId'),
        lastOperationAt: _nullableDateTime(data, 'lastOperationAt'),
        isArchived: schemaVersion == 1 ? false : _boolean(data, 'isArchived'),
        archivedAt: schemaVersion == 1
            ? null
            : _nullableDateTime(data, 'archivedAt'),
        hasHistory: schemaVersion == 1 ? true : _boolean(data, 'hasHistory'),
        createdAt: _dateTime(data, 'createdAt'),
        updatedAt: _dateTime(data, 'updatedAt'),
        schemaVersion: schemaVersion,
        revision: _integer(data, 'revision'),
      );
      if (asset.ownerId != expectedOwnerId) {
        throw StateError('investment_asset_owner_mismatch');
      }
      TrackedInvestmentAsset.validate(asset);
      return asset;
    } on InvestmentFailure {
      rethrow;
    } on Object {
      throw _conversionFailure('investment_asset_conversion_failed');
    }
  }

  static Map<String, Object?> creationMap({
    required String ownerId,
    required TrackedInvestmentAssetDraft draft,
  }) {
    final TrackedInvestmentAssetDraft normalized = draft.normalized();
    return <String, Object?>{
      'ownerId': ownerId,
      'portfolioId': normalized.portfolioId,
      'ticker': normalized.ticker,
      'name': normalized.name,
      'assetType': normalized.type.name,
      'currencyCode': TrackedInvestmentAsset.supportedCurrencyCode,
      'currentQuantityScaled': 0,
      'lastOperationId': null,
      'lastOperationAt': null,
      'isArchived': false,
      'archivedAt': null,
      'hasHistory': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'schemaVersion': TrackedInvestmentAsset.currentSchemaVersion,
      'revision': 1,
    };
  }

  static Map<String, Object?> updateMap({
    required TrackedInvestmentAsset asset,
    required TrackedInvestmentAssetUpdate update,
  }) {
    final TrackedInvestmentAssetUpdate normalized = update.normalized();
    return <String, Object?>{
      'name': normalized.name,
      'assetType': normalized.type.name,
      'updatedAt': FieldValue.serverTimestamp(),
      'revision': asset.revision + 1,
    };
  }
}

abstract final class FirestoreInvestmentOperationMapper {
  static const Set<String> fieldNames = <String>{
    'ownerId',
    'portfolioId',
    'assetId',
    'previousOperationId',
    'previousOperationAt',
    'kind',
    'occurredAt',
    'quantityScaled',
    'unitPriceScaled',
    'feesCents',
    'notes',
    'isVoided',
    'voidedAt',
    'mutationId',
    'createdAt',
    'updatedAt',
    'schemaVersion',
    'revision',
  };

  static InvestmentOperation fromMap({
    required Map<String, dynamic> data,
    required String documentId,
    required String expectedOwnerId,
    required DateTime now,
  }) {
    try {
      _requireExactFields(data, fieldNames);
      final InvestmentOperation operation = InvestmentOperation(
        id: documentId,
        ownerId: _string(data, 'ownerId'),
        portfolioId: _string(data, 'portfolioId'),
        assetId: _string(data, 'assetId'),
        previousOperationId: _nullableString(data, 'previousOperationId'),
        previousOperationAt: _nullableDateTime(data, 'previousOperationAt'),
        kind: InvestmentOperationKind.fromStorage(_string(data, 'kind')),
        occurredAt: _dateTime(data, 'occurredAt'),
        quantityScaled: _integer(data, 'quantityScaled'),
        unitPriceScaled: _integer(data, 'unitPriceScaled'),
        feesCents: _integer(data, 'feesCents'),
        notes: _string(data, 'notes'),
        isVoided: _boolean(data, 'isVoided'),
        voidedAt: _nullableDateTime(data, 'voidedAt'),
        mutationId: _string(data, 'mutationId'),
        createdAt: _dateTime(data, 'createdAt'),
        updatedAt: _dateTime(data, 'updatedAt'),
        schemaVersion: _integer(data, 'schemaVersion'),
        revision: _integer(data, 'revision'),
      );
      if (operation.ownerId != expectedOwnerId) {
        throw StateError('investment_operation_owner_mismatch');
      }
      InvestmentOperation.validate(operation, now: now);
      return operation;
    } on InvestmentFailure {
      rethrow;
    } on Object {
      throw _conversionFailure('investment_operation_conversion_failed');
    }
  }

  static Map<String, Object?> creationMap({
    required String ownerId,
    required String operationId,
    required InvestmentOperationDraft draft,
    required String? previousOperationId,
    required DateTime? previousOperationAt,
  }) {
    return <String, Object?>{
      'ownerId': ownerId,
      'portfolioId': draft.portfolioId,
      'assetId': draft.assetId,
      'previousOperationId': previousOperationId,
      'previousOperationAt': previousOperationAt == null
          ? null
          : Timestamp.fromDate(previousOperationAt),
      'kind': draft.kind.name,
      'occurredAt': Timestamp.fromDate(draft.occurredAt),
      'quantityScaled': draft.quantityScaled,
      'unitPriceScaled': draft.unitPriceScaled,
      'feesCents': draft.feesCents,
      'notes': draft.notes,
      'isVoided': false,
      'voidedAt': null,
      'mutationId': operationId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'schemaVersion': InvestmentOperation.currentSchemaVersion,
      'revision': 1,
    };
  }

  static bool matchesDraft(
    InvestmentOperation operation,
    InvestmentOperationDraft draft,
  ) =>
      !operation.isVoided &&
      operation.portfolioId == draft.portfolioId &&
      operation.assetId == draft.assetId &&
      operation.kind == draft.kind &&
      operation.occurredAt == draft.occurredAt &&
      operation.quantityScaled == draft.quantityScaled &&
      operation.unitPriceScaled == draft.unitPriceScaled &&
      operation.feesCents == draft.feesCents &&
      operation.notes == draft.notes;
}

abstract final class FirestoreInvestmentIncomeEventMapper {
  static const Set<String> fieldNames = <String>{
    'ownerId',
    'portfolioId',
    'assetId',
    'incomeType',
    'status',
    'inputMode',
    'exDate',
    'expectedPaymentDate',
    'receivedDate',
    'eligibleQuantityScaled',
    'unitAmountScaled',
    'grossAmountCents',
    'withholdingTaxCents',
    'netAmountCents',
    'notes',
    'originType',
    'externalId',
    'cancelledAt',
    'voidedAt',
    'mutationId',
    'createdAt',
    'updatedAt',
    'schemaVersion',
    'revision',
  };

  static InvestmentIncomeEvent fromMap({
    required Map<String, dynamic> data,
    required String documentId,
    required String expectedOwnerId,
    required DateTime now,
  }) {
    try {
      _requireExactFields(data, fieldNames);
      final InvestmentIncomeEvent event = InvestmentIncomeEvent(
        id: documentId,
        ownerId: _string(data, 'ownerId'),
        portfolioId: _string(data, 'portfolioId'),
        assetId: _string(data, 'assetId'),
        type: InvestmentIncomeType.fromStorage(_string(data, 'incomeType')),
        status: InvestmentIncomeStatus.fromStorage(_string(data, 'status')),
        inputMode: InvestmentIncomeInputMode.fromStorage(
          _string(data, 'inputMode'),
        ),
        exDate: _nullableDateTime(data, 'exDate'),
        expectedPaymentDate: _dateTime(data, 'expectedPaymentDate'),
        receivedDate: _nullableDateTime(data, 'receivedDate'),
        eligibleQuantityScaled: _nullableInteger(
          data,
          'eligibleQuantityScaled',
        ),
        unitAmountScaled: _nullableInteger(data, 'unitAmountScaled'),
        grossAmountCents: _integer(data, 'grossAmountCents'),
        withholdingTaxCents: _integer(data, 'withholdingTaxCents'),
        netAmountCents: _integer(data, 'netAmountCents'),
        notes: _string(data, 'notes'),
        originType: InvestmentIncomeOriginType.fromStorage(
          _string(data, 'originType'),
        ),
        externalId: _nullableString(data, 'externalId'),
        cancelledAt: _nullableDateTime(data, 'cancelledAt'),
        voidedAt: _nullableDateTime(data, 'voidedAt'),
        mutationId: _string(data, 'mutationId'),
        createdAt: _dateTime(data, 'createdAt'),
        updatedAt: _dateTime(data, 'updatedAt'),
        schemaVersion: _integer(data, 'schemaVersion'),
        revision: _integer(data, 'revision'),
      );
      if (event.ownerId != expectedOwnerId) {
        throw StateError('investment_income_owner_mismatch');
      }
      InvestmentIncomeEvent.validate(event, now: now);
      return event;
    } on InvestmentFailure {
      rethrow;
    } on Object {
      throw _conversionFailure('investment_income_conversion_failed');
    }
  }

  static Map<String, Object?> creationMap({
    required String ownerId,
    required String eventId,
    required InvestmentIncomeDraft draft,
  }) => <String, Object?>{
    'ownerId': ownerId,
    'portfolioId': draft.portfolioId,
    'assetId': draft.assetId,
    'incomeType': draft.type.name,
    'status': InvestmentIncomeStatus.expected.name,
    'inputMode': draft.inputMode.name,
    'exDate': draft.exDate == null ? null : Timestamp.fromDate(draft.exDate!),
    'expectedPaymentDate': Timestamp.fromDate(draft.expectedPaymentDate),
    'receivedDate': null,
    'eligibleQuantityScaled': draft.eligibleQuantityScaled,
    'unitAmountScaled': draft.unitAmountScaled,
    'grossAmountCents': draft.grossAmountCents,
    'withholdingTaxCents': draft.withholdingTaxCents,
    'netAmountCents': draft.netAmountCents,
    'notes': draft.notes,
    'originType': InvestmentIncomeOriginType.manual.name,
    'externalId': null,
    'cancelledAt': null,
    'voidedAt': null,
    'mutationId': eventId,
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
    'schemaVersion': InvestmentIncomeEvent.currentSchemaVersion,
    'revision': 1,
  };

  static Map<String, Object?> expectedUpdateMap({
    required InvestmentIncomeDraft draft,
    required String mutationId,
    required int revision,
  }) => <String, Object?>{
    'incomeType': draft.type.name,
    'inputMode': draft.inputMode.name,
    'exDate': draft.exDate == null ? null : Timestamp.fromDate(draft.exDate!),
    'expectedPaymentDate': Timestamp.fromDate(draft.expectedPaymentDate),
    'eligibleQuantityScaled': draft.eligibleQuantityScaled,
    'unitAmountScaled': draft.unitAmountScaled,
    'grossAmountCents': draft.grossAmountCents,
    'withholdingTaxCents': draft.withholdingTaxCents,
    'netAmountCents': draft.netAmountCents,
    'notes': draft.notes,
    'mutationId': mutationId,
    'updatedAt': FieldValue.serverTimestamp(),
    'revision': revision,
  };

  static bool matchesDraft(
    InvestmentIncomeEvent event,
    InvestmentIncomeDraft draft,
  ) =>
      event.portfolioId == draft.portfolioId &&
      event.assetId == draft.assetId &&
      event.type == draft.type &&
      event.inputMode == draft.inputMode &&
      event.exDate == draft.exDate &&
      event.expectedPaymentDate == draft.expectedPaymentDate &&
      event.eligibleQuantityScaled == draft.eligibleQuantityScaled &&
      event.unitAmountScaled == draft.unitAmountScaled &&
      event.grossAmountCents == draft.grossAmountCents &&
      event.withholdingTaxCents == draft.withholdingTaxCents &&
      event.netAmountCents == draft.netAmountCents &&
      event.notes == draft.notes;
}

void _requireExactFields(Map<String, dynamic> data, Set<String> expected) {
  final Set<String> actual = data.keys.toSet();
  if (actual.difference(expected).isNotEmpty ||
      expected.difference(actual).isNotEmpty) {
    throw StateError('unexpected_investment_fields');
  }
}

bool _boolean(Map<String, dynamic> data, String field) {
  final Object? value = data[field];
  if (value is! bool) {
    throw StateError('invalid_boolean');
  }
  return value;
}

DateTime _dateTime(Map<String, dynamic> data, String field) {
  final Object? value = data[field];
  if (value is! Timestamp) {
    throw StateError('invalid_or_pending_timestamp');
  }
  return value.toDate().toUtc();
}

DateTime? _nullableDateTime(Map<String, dynamic> data, String field) {
  final Object? value = data[field];
  if (value == null) {
    return null;
  }
  if (value is! Timestamp) {
    throw StateError('invalid_timestamp');
  }
  return value.toDate().toUtc();
}

int _integer(Map<String, dynamic> data, String field) {
  final Object? value = data[field];
  if (value is! int) {
    throw StateError('invalid_integer');
  }
  return value;
}

int? _nullableInteger(Map<String, dynamic> data, String field) {
  final Object? value = data[field];
  if (value == null) {
    return null;
  }
  if (value is! int) {
    throw StateError('invalid_nullable_integer');
  }
  return value;
}

String _string(Map<String, dynamic> data, String field) {
  final Object? value = data[field];
  if (value is! String) {
    throw StateError('invalid_string');
  }
  return value;
}

String? _nullableString(Map<String, dynamic> data, String field) {
  final Object? value = data[field];
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw StateError('invalid_nullable_string');
  }
  return value;
}

InvestmentFailure _conversionFailure(String code) => InvestmentFailure(
  kind: InvestmentFailureKind.incompatible,
  safeMessage:
      'Encontramos uma inconsistência nos investimentos. Nenhum dado foi alterado.',
  code: code,
);
