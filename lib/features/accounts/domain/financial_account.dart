import 'package:meu_gestor_financeiro/core/money/currency.dart';
import 'package:meu_gestor_financeiro/core/money/money.dart';
import 'package:meu_gestor_financeiro/features/accounts/domain/account_name.dart';

enum FinancialAccountType {
  checking('Conta corrente'),
  savings('Poupança'),
  cash('Dinheiro'),
  digitalWallet('Carteira digital'),
  investment('Investimentos'),
  other('Outra conta');

  const FinancialAccountType(this.label);

  final String label;

  static FinancialAccountType fromStorage(String value) =>
      FinancialAccountType.values.firstWhere(
        (FinancialAccountType type) => type.name == value,
        orElse: () => throw const FormatException('invalid_account_type'),
      );
}

final class FinancialAccount {
  const FinancialAccount({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.type,
    required this.openingBalanceCents,
    required this.currencyCode,
    required this.includeInTotal,
    required this.isArchived,
    required this.archivedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.schemaVersion,
  });

  static const int currentSchemaVersion = 1;
  static const int minimumOpeningBalanceCents = -9999999999;
  static const int maximumOpeningBalanceCents = 9999999999;
  static const String supportedCurrencyCode = 'BRL';

  final String id;
  final String ownerId;
  final String name;
  final FinancialAccountType type;
  final int openingBalanceCents;
  final String currencyCode;
  final bool includeInTotal;
  final bool isArchived;
  final DateTime? archivedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int schemaVersion;

  Money get openingBalance => Money.fromCents(
    openingBalanceCents,
    currency: Currency.fromCode(currencyCode),
  );

  FinancialAccount copyWith({
    String? name,
    FinancialAccountType? type,
    int? openingBalanceCents,
    bool? includeInTotal,
    bool? isArchived,
    DateTime? archivedAt,
    bool clearArchivedAt = false,
    DateTime? updatedAt,
  }) => FinancialAccount(
    id: id,
    ownerId: ownerId,
    name: name ?? this.name,
    type: type ?? this.type,
    openingBalanceCents: openingBalanceCents ?? this.openingBalanceCents,
    currencyCode: currencyCode,
    includeInTotal: includeInTotal ?? this.includeInTotal,
    isArchived: isArchived ?? this.isArchived,
    archivedAt: clearArchivedAt ? null : archivedAt ?? this.archivedAt,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    schemaVersion: schemaVersion,
  );

  static void validateOpeningBalance(int cents) {
    if (cents < minimumOpeningBalanceCents ||
        cents > maximumOpeningBalanceCents) {
      throw const FormatException('opening_balance_out_of_range');
    }
  }

  static void validate(FinancialAccount account) {
    if (account.id.isEmpty ||
        account.ownerId.isEmpty ||
        AccountName.requireValid(account.name) != account.name ||
        account.currencyCode != supportedCurrencyCode ||
        account.schemaVersion != currentSchemaVersion ||
        account.isArchived != (account.archivedAt != null)) {
      throw const FormatException('invalid_financial_account');
    }
    validateOpeningBalance(account.openingBalanceCents);
  }
}

final class FinancialAccountDraft {
  const FinancialAccountDraft({
    required this.name,
    required this.type,
    required this.openingBalanceCents,
    required this.includeInTotal,
  });

  final String name;
  final FinancialAccountType type;
  final int openingBalanceCents;
  final bool includeInTotal;

  FinancialAccountDraft normalized() {
    final String normalizedName = AccountName.requireValid(name);
    FinancialAccount.validateOpeningBalance(openingBalanceCents);
    return FinancialAccountDraft(
      name: normalizedName,
      type: type,
      openingBalanceCents: openingBalanceCents,
      includeInTotal: includeInTotal,
    );
  }
}
