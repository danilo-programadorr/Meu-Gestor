import 'package:meu_gestor_financeiro/core/errors/app_exception.dart';
import 'package:meu_gestor_financeiro/core/money/currency.dart';

final class Money implements Comparable<Money> {
  const Money.fromCents(this.cents, {this.currency = Currency.brl});

  factory Money.fromMinorUnits(
    Object? value, {
    Currency currency = Currency.brl,
  }) {
    if (value is! int) {
      throw const InvalidMoneyException(
        code: 'minor_units_must_be_integer',
        message:
            'Valores monetários devem ser informados em centavos inteiros.',
      );
    }

    return Money.fromCents(value, currency: currency);
  }

  final int cents;
  final Currency currency;

  Money operator +(Money other) {
    _ensureSameCurrency(other);
    return Money.fromCents(cents + other.cents, currency: currency);
  }

  Money operator -(Money other) {
    _ensureSameCurrency(other);
    return Money.fromCents(cents - other.cents, currency: currency);
  }

  @override
  int compareTo(Money other) {
    _ensureSameCurrency(other);
    return cents.compareTo(other.cents);
  }

  void _ensureSameCurrency(Money other) {
    if (currency != other.currency) {
      throw CurrencyMismatchException(
        code: 'currency_mismatch',
        message:
            'Não é possível operar ${currency.code} com ${other.currency.code}.',
      );
    }
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Money && cents == other.cents && currency == other.currency;
  }

  @override
  int get hashCode => Object.hash(cents, currency);
}
