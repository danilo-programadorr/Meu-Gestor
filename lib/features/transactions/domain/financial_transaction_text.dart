import 'package:meu_gestor_financeiro/features/transactions/domain/financial_transaction_failure.dart';

abstract final class FinancialTransactionText {
  static const int minimumDescriptionLength = 2;
  static const int maximumDescriptionLength = 120;
  static const int maximumNotesLength = 500;

  static String normalizeDescription(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ');

  static String normalizeNotes(String value) => value.trim();

  static String? validateDescription(String value) {
    if (_hasControlCharacter(value)) {
      return 'A descrição contém caracteres não permitidos.';
    }
    final String normalized = normalizeDescription(value);
    if (normalized.length < minimumDescriptionLength ||
        normalized.length > maximumDescriptionLength) {
      return 'Informe uma descrição entre 2 e 120 caracteres.';
    }
    return null;
  }

  static String? validateNotes(String value) {
    if (_hasControlCharacter(value)) {
      return 'As observações contêm caracteres não permitidos.';
    }
    if (normalizeNotes(value).length > maximumNotesLength) {
      return 'As observações devem ter no máximo 500 caracteres.';
    }
    return null;
  }

  static String requireDescription(String value) {
    final String? message = validateDescription(value);
    if (message != null) {
      throw FinancialTransactionFailure(
        kind: FinancialTransactionFailureKind.invalidDescription,
        safeMessage: message,
        code: 'invalid_transaction_description',
      );
    }
    return normalizeDescription(value);
  }

  static String requireNotes(String value) {
    final String? message = validateNotes(value);
    if (message != null) {
      throw FinancialTransactionFailure(
        kind: FinancialTransactionFailureKind.invalidNotes,
        safeMessage: message,
        code: 'invalid_transaction_notes',
      );
    }
    return normalizeNotes(value);
  }

  static bool _hasControlCharacter(String value) =>
      RegExp(r'[\x00-\x1F\x7F]').hasMatch(value);
}
