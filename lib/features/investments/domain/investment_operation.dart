import 'package:meu_gestor_financeiro/core/dates/sao_paulo_civil_date.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_failure.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/scaled_investment_value.dart';

enum InvestmentOperationKind {
  buy('Compra'),
  sell('Venda');

  const InvestmentOperationKind(this.label);
  final String label;

  static InvestmentOperationKind fromStorage(String value) =>
      InvestmentOperationKind.values.firstWhere(
        (InvestmentOperationKind kind) => kind.name == value,
        orElse: () => throw const FormatException('invalid_operation_kind'),
      );
}

final class InvestmentOperation {
  const InvestmentOperation({
    required this.id,
    required this.ownerId,
    required this.portfolioId,
    required this.assetId,
    required this.previousOperationId,
    required this.previousOperationAt,
    required this.kind,
    required this.occurredAt,
    required this.quantityScaled,
    required this.unitPriceScaled,
    required this.feesCents,
    required this.notes,
    required this.isVoided,
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
  final String? previousOperationId;
  final DateTime? previousOperationAt;
  final InvestmentOperationKind kind;
  final DateTime occurredAt;
  final int quantityScaled;
  final int unitPriceScaled;
  final int feesCents;
  final String notes;
  final bool isVoided;
  final DateTime? voidedAt;
  final String mutationId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int schemaVersion;
  final int revision;

  int get grossAmountCents => InvestmentArithmetic.grossAmountCents(
    quantityScaled: quantityScaled,
    unitPriceScaled: unitPriceScaled,
  );

  static String normalizeNotes(String value) {
    final String normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.length > maximumNotesLength) {
      throw const InvestmentFailure(
        kind: InvestmentFailureKind.validation,
        safeMessage: 'A observação deve ter no máximo 240 caracteres.',
        code: 'invalid_investment_operation_notes',
      );
    }
    return normalized;
  }

  static DateTime fromCalendarDate(DateTime date) =>
      SaoPauloCivilDate.fromCalendarDate(date).toStorageInstant();

  static void validateNotFuture(DateTime occurredAt, DateTime now) {
    final SaoPauloCivilDate operationDate = SaoPauloCivilDate.fromInstant(
      occurredAt,
    );
    final SaoPauloCivilDate today = SaoPauloCivilDate.fromInstant(now);
    if (operationDate.isAfter(today)) {
      throw const InvestmentFailure(
        kind: InvestmentFailureKind.validation,
        safeMessage: 'Escolha uma data de hoje ou anterior.',
        code: 'future_investment_operation_date',
      );
    }
  }

  static void validate(InvestmentOperation operation, {required DateTime now}) {
    InvestmentQuantity.fromScaled(operation.quantityScaled);
    InvestmentUnitPrice.fromScaled(operation.unitPriceScaled);
    if (operation.id.isEmpty ||
        operation.ownerId.isEmpty ||
        operation.portfolioId.isEmpty ||
        operation.assetId.isEmpty ||
        (operation.previousOperationId == null) !=
            (operation.previousOperationAt == null) ||
        operation.previousOperationId?.contains('/') == true ||
        (operation.previousOperationAt?.isAfter(operation.occurredAt) ??
            false) ||
        operation.feesCents < 0 ||
        operation.feesCents > InvestmentScale.maximumFeesCents ||
        normalizeNotes(operation.notes) != operation.notes ||
        operation.isVoided != (operation.voidedAt != null) ||
        operation.mutationId.isEmpty ||
        operation.mutationId.contains('/') ||
        operation.schemaVersion != currentSchemaVersion ||
        operation.revision < 1) {
      throw const InvestmentFailure(
        kind: InvestmentFailureKind.incompatible,
        safeMessage: 'Encontramos uma inconsistência nesta operação.',
        code: 'invalid_investment_operation',
      );
    }
    validateNotFuture(operation.occurredAt, now);
    if (operation.kind == InvestmentOperationKind.sell &&
        operation.feesCents > operation.grossAmountCents) {
      throw const InvestmentFailure(
        kind: InvestmentFailureKind.validation,
        safeMessage: 'As taxas não podem superar o valor da venda.',
        code: 'investment_sell_fees_exceed_gross',
      );
    }
  }
}

final class InvestmentOperationDraft {
  const InvestmentOperationDraft({
    required this.portfolioId,
    required this.assetId,
    required this.kind,
    required this.occurredAt,
    required this.quantityScaled,
    required this.unitPriceScaled,
    required this.feesCents,
    required this.notes,
  });

  final String portfolioId;
  final String assetId;
  final InvestmentOperationKind kind;
  final DateTime occurredAt;
  final int quantityScaled;
  final int unitPriceScaled;
  final int feesCents;
  final String notes;

  InvestmentOperationDraft normalized({required DateTime now}) {
    if (portfolioId.isEmpty ||
        portfolioId.contains('/') ||
        assetId.isEmpty ||
        assetId.contains('/')) {
      throw const InvestmentFailure(
        kind: InvestmentFailureKind.validation,
        safeMessage: 'Escolha uma carteira e um ativo válidos.',
        code: 'invalid_investment_operation_reference',
      );
    }
    InvestmentQuantity.fromScaled(quantityScaled);
    InvestmentUnitPrice.fromScaled(unitPriceScaled);
    if (feesCents < 0 || feesCents > InvestmentScale.maximumFeesCents) {
      throw const InvestmentFailure(
        kind: InvestmentFailureKind.validation,
        safeMessage: 'Informe taxas válidas.',
        code: 'invalid_investment_operation_fees',
      );
    }
    final DateTime normalizedDate = SaoPauloCivilDate.fromInstant(
      occurredAt,
    ).toStorageInstant();
    InvestmentOperation.validateNotFuture(normalizedDate, now);
    final int gross = InvestmentArithmetic.grossAmountCents(
      quantityScaled: quantityScaled,
      unitPriceScaled: unitPriceScaled,
    );
    if (gross <= 0 ||
        (kind == InvestmentOperationKind.sell && feesCents > gross)) {
      throw const InvestmentFailure(
        kind: InvestmentFailureKind.validation,
        safeMessage: 'Revise quantidade, preço e taxas da operação.',
        code: 'invalid_investment_operation_amounts',
      );
    }
    return InvestmentOperationDraft(
      portfolioId: portfolioId,
      assetId: assetId,
      kind: kind,
      occurredAt: normalizedDate,
      quantityScaled: quantityScaled,
      unitPriceScaled: unitPriceScaled,
      feesCents: feesCents,
      notes: InvestmentOperation.normalizeNotes(notes),
    );
  }
}
