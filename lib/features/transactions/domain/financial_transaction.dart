import 'package:meu_gestor_financeiro/core/money/money.dart';
import 'package:meu_gestor_financeiro/features/categories/domain/financial_category.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_transaction_date.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_transaction_failure.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_transaction_text.dart';

enum FinancialTransactionKind {
  income('Receita'),
  expense('Despesa');

  const FinancialTransactionKind(this.label);

  final String label;

  FinancialCategoryKind get categoryKind => switch (this) {
    FinancialTransactionKind.income => FinancialCategoryKind.income,
    FinancialTransactionKind.expense => FinancialCategoryKind.expense,
  };

  static FinancialTransactionKind fromStorage(String value) =>
      FinancialTransactionKind.values.firstWhere(
        (FinancialTransactionKind kind) => kind.name == value,
        orElse: () => throw const FormatException('invalid_transaction_kind'),
      );
}

final class FinancialTransaction {
  const FinancialTransaction({
    required this.id,
    required this.ownerId,
    required this.accountId,
    required this.categoryId,
    required this.kind,
    required this.description,
    required this.amountCents,
    required this.occurredAt,
    required this.notes,
    required this.isVoided,
    required this.voidedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.schemaVersion,
  });

  static const int currentSchemaVersion = 1;
  static const int maximumAmountCents = 9999999999;

  final String id;
  final String ownerId;
  final String accountId;
  final String categoryId;
  final FinancialTransactionKind kind;
  final String description;
  final int amountCents;
  final DateTime occurredAt;
  final String notes;
  final bool isVoided;
  final DateTime? voidedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int schemaVersion;

  Money get amount => Money.fromCents(amountCents);

  int get signedAmountCents => switch (kind) {
    FinancialTransactionKind.income => amountCents,
    FinancialTransactionKind.expense => -amountCents,
  };

  FinancialTransaction copyWith({
    String? categoryId,
    String? description,
    DateTime? occurredAt,
    String? notes,
    bool? isVoided,
    DateTime? voidedAt,
    DateTime? updatedAt,
  }) => FinancialTransaction(
    id: id,
    ownerId: ownerId,
    accountId: accountId,
    categoryId: categoryId ?? this.categoryId,
    kind: kind,
    description: description ?? this.description,
    amountCents: amountCents,
    occurredAt: occurredAt ?? this.occurredAt,
    notes: notes ?? this.notes,
    isVoided: isVoided ?? this.isVoided,
    voidedAt: voidedAt ?? this.voidedAt,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    schemaVersion: schemaVersion,
  );

  static void validateAmount(int cents) {
    if (cents <= 0 || cents > maximumAmountCents) {
      throw const FinancialTransactionFailure(
        kind: FinancialTransactionFailureKind.invalidAmount,
        safeMessage: 'Informe um valor maior que zero.',
        code: 'transaction_amount_out_of_range',
      );
    }
  }

  static void validate(
    FinancialTransaction transaction, {
    required DateTime now,
  }) {
    if (transaction.id.isEmpty ||
        transaction.ownerId.isEmpty ||
        transaction.accountId.isEmpty ||
        transaction.categoryId.isEmpty ||
        FinancialTransactionText.requireDescription(transaction.description) !=
            transaction.description ||
        FinancialTransactionText.requireNotes(transaction.notes) !=
            transaction.notes ||
        transaction.schemaVersion != currentSchemaVersion ||
        transaction.isVoided != (transaction.voidedAt != null)) {
      throw const FinancialTransactionFailure(
        kind: FinancialTransactionFailureKind.incompatible,
        safeMessage: 'Encontramos uma inconsistência neste lançamento.',
        code: 'invalid_financial_transaction',
      );
    }
    validateAmount(transaction.amountCents);
    FinancialTransactionDate.validateNotFuture(transaction.occurredAt, now);
  }
}

final class FinancialTransactionDraft {
  const FinancialTransactionDraft({
    required this.accountId,
    required this.categoryId,
    required this.kind,
    required this.description,
    required this.amountCents,
    required this.occurredAt,
    required this.notes,
  });

  final String accountId;
  final String categoryId;
  final FinancialTransactionKind kind;
  final String description;
  final int amountCents;
  final DateTime occurredAt;
  final String notes;

  FinancialTransactionDraft normalized({required DateTime now}) {
    if (accountId.isEmpty || categoryId.isEmpty) {
      throw const FinancialTransactionFailure(
        kind: FinancialTransactionFailureKind.validation,
        safeMessage: 'Escolha uma conta e uma categoria.',
        code: 'transaction_reference_required',
      );
    }
    FinancialTransaction.validateAmount(amountCents);
    FinancialTransactionDate.validateNotFuture(occurredAt, now);
    return FinancialTransactionDraft(
      accountId: accountId,
      categoryId: categoryId,
      kind: kind,
      description: FinancialTransactionText.requireDescription(description),
      amountCents: amountCents,
      occurredAt: occurredAt.toUtc(),
      notes: FinancialTransactionText.requireNotes(notes),
    );
  }
}

final class FinancialTransactionEdit {
  const FinancialTransactionEdit({
    required this.categoryId,
    required this.description,
    required this.occurredAt,
    required this.notes,
  });

  final String categoryId;
  final String description;
  final DateTime occurredAt;
  final String notes;

  FinancialTransactionEdit normalized({required DateTime now}) {
    if (categoryId.isEmpty) {
      throw const FinancialTransactionFailure(
        kind: FinancialTransactionFailureKind.validation,
        safeMessage: 'Escolha uma categoria.',
        code: 'transaction_category_required',
      );
    }
    FinancialTransactionDate.validateNotFuture(occurredAt, now);
    return FinancialTransactionEdit(
      categoryId: categoryId,
      description: FinancialTransactionText.requireDescription(description),
      occurredAt: occurredAt.toUtc(),
      notes: FinancialTransactionText.requireNotes(notes),
    );
  }
}
