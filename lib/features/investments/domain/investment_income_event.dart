import 'package:meu_gestor_financeiro/core/dates/sao_paulo_civil_date.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_failure.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/scaled_investment_value.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/tracked_investment_asset.dart';

enum InvestmentIncomeType {
  dividend('Dividendo'),
  jcp('Juros sobre capital próprio'),
  fiiIncome('Rendimento de FII');

  const InvestmentIncomeType(this.label);

  final String label;

  static InvestmentIncomeType fromStorage(String value) =>
      InvestmentIncomeType.values.firstWhere(
        (InvestmentIncomeType type) => type.name == value,
        orElse: () => throw const FormatException('invalid_income_type'),
      );

  bool isCompatibleWith(
    TrackedInvestmentAssetType assetType,
  ) => switch (assetType) {
    TrackedInvestmentAssetType.stock =>
      this == InvestmentIncomeType.dividend || this == InvestmentIncomeType.jcp,
    TrackedInvestmentAssetType.fii => this == InvestmentIncomeType.fiiIncome,
  };
}

enum InvestmentIncomeStatus {
  expected('Previsto'),
  received('Recebido'),
  cancelled('Cancelado'),
  voided('Anulado');

  const InvestmentIncomeStatus(this.label);

  final String label;

  static InvestmentIncomeStatus fromStorage(String value) =>
      InvestmentIncomeStatus.values.firstWhere(
        (InvestmentIncomeStatus status) => status.name == value,
        orElse: () => throw const FormatException('invalid_income_status'),
      );
}

enum InvestmentIncomeInputMode {
  total('Valor total'),
  perUnit('Valor por unidade');

  const InvestmentIncomeInputMode(this.label);

  final String label;

  static InvestmentIncomeInputMode fromStorage(String value) =>
      InvestmentIncomeInputMode.values.firstWhere(
        (InvestmentIncomeInputMode mode) => mode.name == value,
        orElse: () => throw const FormatException('invalid_income_input_mode'),
      );
}

enum InvestmentIncomeOriginType {
  manual('Manual');

  const InvestmentIncomeOriginType(this.label);

  final String label;

  static InvestmentIncomeOriginType fromStorage(String value) =>
      InvestmentIncomeOriginType.values.firstWhere(
        (InvestmentIncomeOriginType origin) => origin.name == value,
        orElse: () => throw const FormatException('invalid_income_origin'),
      );
}

final class InvestmentIncomeEvent {
  const InvestmentIncomeEvent({
    required this.id,
    required this.ownerId,
    required this.portfolioId,
    required this.assetId,
    required this.type,
    required this.status,
    required this.inputMode,
    required this.exDate,
    required this.expectedPaymentDate,
    required this.receivedDate,
    required this.eligibleQuantityScaled,
    required this.unitAmountScaled,
    required this.grossAmountCents,
    required this.withholdingTaxCents,
    required this.netAmountCents,
    required this.notes,
    required this.originType,
    required this.externalId,
    required this.cancelledAt,
    required this.voidedAt,
    required this.mutationId,
    required this.createdAt,
    required this.updatedAt,
    required this.schemaVersion,
    required this.revision,
  });

  static const int currentSchemaVersion = 1;
  static const int maximumNotesLength = 240;

  final String id;
  final String ownerId;
  final String portfolioId;
  final String assetId;
  final InvestmentIncomeType type;
  final InvestmentIncomeStatus status;
  final InvestmentIncomeInputMode inputMode;
  final DateTime? exDate;
  final DateTime expectedPaymentDate;
  final DateTime? receivedDate;
  final int? eligibleQuantityScaled;
  final int? unitAmountScaled;
  final int grossAmountCents;
  final int withholdingTaxCents;
  final int netAmountCents;
  final String notes;
  final InvestmentIncomeOriginType originType;
  final String? externalId;
  final DateTime? cancelledAt;
  final DateTime? voidedAt;
  final String mutationId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int schemaVersion;
  final int revision;

  bool get isExpected => status == InvestmentIncomeStatus.expected;
  bool get isTerminal =>
      status == InvestmentIncomeStatus.cancelled ||
      status == InvestmentIncomeStatus.voided;

  DateTime get relevantDate => receivedDate ?? expectedPaymentDate;

  bool canTransitionTo(InvestmentIncomeStatus target) => switch (status) {
    InvestmentIncomeStatus.expected =>
      target == InvestmentIncomeStatus.received ||
          target == InvestmentIncomeStatus.cancelled,
    InvestmentIncomeStatus.received => target == InvestmentIncomeStatus.voided,
    InvestmentIncomeStatus.cancelled || InvestmentIncomeStatus.voided => false,
  };

  static String normalizeNotes(String value) {
    final String normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.length > maximumNotesLength) {
      throw const InvestmentFailure(
        kind: InvestmentFailureKind.validation,
        safeMessage: 'A observação deve ter no máximo 240 caracteres.',
        code: 'invalid_investment_income_notes',
      );
    }
    return normalized;
  }

  static DateTime normalizeCivilDate(DateTime value) =>
      SaoPauloCivilDate.fromInstant(value).toStorageInstant();

  static void validateReceivedDate(DateTime value, {required DateTime now}) {
    final SaoPauloCivilDate received = SaoPauloCivilDate.fromInstant(value);
    final SaoPauloCivilDate today = SaoPauloCivilDate.fromInstant(now);
    if (received.isAfter(today)) {
      throw const InvestmentFailure(
        kind: InvestmentFailureKind.validation,
        safeMessage: 'A data efetiva do recebimento não pode ser futura.',
        code: 'future_investment_income_received_date',
      );
    }
  }

  static int grossFromUnit({
    required int quantityScaled,
    required int unitAmountScaled,
  }) => InvestmentArithmetic.grossAmountCents(
    quantityScaled: quantityScaled,
    unitPriceScaled: unitAmountScaled,
  );

  static void validate(InvestmentIncomeEvent event, {required DateTime now}) {
    if (event.id.isEmpty ||
        event.id.contains('/') ||
        event.ownerId.isEmpty ||
        event.portfolioId.isEmpty ||
        event.portfolioId.contains('/') ||
        event.assetId.isEmpty ||
        event.assetId.contains('/') ||
        event.originType != InvestmentIncomeOriginType.manual ||
        event.externalId != null ||
        event.mutationId.isEmpty ||
        event.mutationId.contains('/') ||
        event.schemaVersion != currentSchemaVersion ||
        event.revision < 1 ||
        normalizeNotes(event.notes) != event.notes) {
      throw _incompatible();
    }
    _validateAmounts(
      inputMode: event.inputMode,
      eligibleQuantityScaled: event.eligibleQuantityScaled,
      unitAmountScaled: event.unitAmountScaled,
      grossAmountCents: event.grossAmountCents,
      withholdingTaxCents: event.withholdingTaxCents,
      netAmountCents: event.netAmountCents,
    );
    switch (event.status) {
      case InvestmentIncomeStatus.expected:
        if (event.receivedDate != null ||
            event.cancelledAt != null ||
            event.voidedAt != null) {
          throw _incompatible();
        }
        break;
      case InvestmentIncomeStatus.received:
        if (event.receivedDate == null ||
            event.cancelledAt != null ||
            event.voidedAt != null) {
          throw _incompatible();
        }
        validateReceivedDate(event.receivedDate!, now: now);
        break;
      case InvestmentIncomeStatus.cancelled:
        if (event.receivedDate != null ||
            event.cancelledAt == null ||
            event.voidedAt != null) {
          throw _incompatible();
        }
        break;
      case InvestmentIncomeStatus.voided:
        if (event.receivedDate == null ||
            event.cancelledAt != null ||
            event.voidedAt == null) {
          throw _incompatible();
        }
        validateReceivedDate(event.receivedDate!, now: now);
        break;
    }
  }

  static void _validateAmounts({
    required InvestmentIncomeInputMode inputMode,
    required int? eligibleQuantityScaled,
    required int? unitAmountScaled,
    required int grossAmountCents,
    required int withholdingTaxCents,
    required int netAmountCents,
  }) {
    if (grossAmountCents <= 0 ||
        grossAmountCents > InvestmentScale.maximumMoneyCents ||
        withholdingTaxCents < 0 ||
        withholdingTaxCents > grossAmountCents ||
        netAmountCents != grossAmountCents - withholdingTaxCents) {
      throw const InvestmentFailure(
        kind: InvestmentFailureKind.validation,
        safeMessage: 'Revise o valor bruto, o imposto e o valor líquido.',
        code: 'invalid_investment_income_amounts',
      );
    }
    switch (inputMode) {
      case InvestmentIncomeInputMode.total:
        if (eligibleQuantityScaled != null || unitAmountScaled != null) {
          throw _incompatible();
        }
        break;
      case InvestmentIncomeInputMode.perUnit:
        if (eligibleQuantityScaled == null || unitAmountScaled == null) {
          throw _incompatible();
        }
        InvestmentQuantity.fromScaled(eligibleQuantityScaled);
        InvestmentUnitPrice.fromScaled(unitAmountScaled);
        if (grossFromUnit(
              quantityScaled: eligibleQuantityScaled,
              unitAmountScaled: unitAmountScaled,
            ) !=
            grossAmountCents) {
          throw const InvestmentFailure(
            kind: InvestmentFailureKind.validation,
            safeMessage:
                'O valor bruto não corresponde à quantidade e ao valor por unidade.',
            code: 'investment_income_gross_mismatch',
          );
        }
        break;
    }
  }

  static InvestmentFailure _incompatible() => const InvestmentFailure(
    kind: InvestmentFailureKind.incompatible,
    safeMessage: 'Encontramos uma inconsistência neste provento.',
    code: 'invalid_investment_income_event',
  );
}

final class InvestmentIncomeDraft {
  const InvestmentIncomeDraft({
    required this.portfolioId,
    required this.assetId,
    required this.type,
    required this.inputMode,
    required this.exDate,
    required this.expectedPaymentDate,
    required this.eligibleQuantityScaled,
    required this.unitAmountScaled,
    required this.grossAmountCents,
    required this.withholdingTaxCents,
    required this.notes,
  });

  final String portfolioId;
  final String assetId;
  final InvestmentIncomeType type;
  final InvestmentIncomeInputMode inputMode;
  final DateTime? exDate;
  final DateTime expectedPaymentDate;
  final int? eligibleQuantityScaled;
  final int? unitAmountScaled;
  final int grossAmountCents;
  final int withholdingTaxCents;
  final String notes;

  int get netAmountCents => InvestmentArithmetic.checkedInt64(
    BigInt.from(grossAmountCents) - BigInt.from(withholdingTaxCents),
  );

  InvestmentIncomeDraft normalized({
    required TrackedInvestmentAssetType assetType,
  }) {
    if (portfolioId.isEmpty ||
        portfolioId.contains('/') ||
        assetId.isEmpty ||
        assetId.contains('/')) {
      throw const InvestmentFailure(
        kind: InvestmentFailureKind.validation,
        safeMessage: 'Escolha uma carteira e um ativo válidos.',
        code: 'invalid_investment_income_reference',
      );
    }
    if (!type.isCompatibleWith(assetType)) {
      throw const InvestmentFailure(
        kind: InvestmentFailureKind.validation,
        safeMessage: 'O tipo de provento não é compatível com este ativo.',
        code: 'incompatible_investment_income_type',
      );
    }
    final DateTime normalizedPayment = InvestmentIncomeEvent.normalizeCivilDate(
      expectedPaymentDate,
    );
    final DateTime? normalizedExDate = exDate == null
        ? null
        : InvestmentIncomeEvent.normalizeCivilDate(exDate!);
    InvestmentIncomeEvent._validateAmounts(
      inputMode: inputMode,
      eligibleQuantityScaled: eligibleQuantityScaled,
      unitAmountScaled: unitAmountScaled,
      grossAmountCents: grossAmountCents,
      withholdingTaxCents: withholdingTaxCents,
      netAmountCents: netAmountCents,
    );
    return InvestmentIncomeDraft(
      portfolioId: portfolioId,
      assetId: assetId,
      type: type,
      inputMode: inputMode,
      exDate: normalizedExDate,
      expectedPaymentDate: normalizedPayment,
      eligibleQuantityScaled: eligibleQuantityScaled,
      unitAmountScaled: unitAmountScaled,
      grossAmountCents: grossAmountCents,
      withholdingTaxCents: withholdingTaxCents,
      notes: InvestmentIncomeEvent.normalizeNotes(notes),
    );
  }
}
