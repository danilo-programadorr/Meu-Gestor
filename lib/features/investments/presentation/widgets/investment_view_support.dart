import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:meu_gestor_financeiro/core/dates/sao_paulo_civil_date.dart';
import 'package:meu_gestor_financeiro/core/money/money.dart';
import 'package:meu_gestor_financeiro/core/money/money_formatter.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/scaled_investment_value.dart';

abstract final class InvestmentViewSupport {
  static const String hiddenValue = '••••';

  static String money(int cents, {required bool visible}) =>
      visible ? MoneyFormatter.format(Money.fromCents(cents)) : hiddenValue;

  static String quantity(int scaled, {required bool visible}) => visible
      ? scaled == 0
            ? '0'
            : InvestmentQuantity.fromScaled(scaled).formatPtBr()
      : hiddenValue;

  static String unitPrice(int scaled, {required bool visible}) => visible
      ? scaled == 0
            ? '—'
            : 'R\$ ${InvestmentUnitPrice.fromScaled(scaled).formatPtBr()}'
      : hiddenValue;

  static String percentage(double fraction, {required bool visible}) => visible
      ? NumberFormat.percentPattern('pt_BR').format(fraction)
      : hiddenValue;

  static String date(DateTime value) => DateFormat(
    'dd/MM/yyyy',
    'pt_BR',
  ).format(SaoPauloCivilDate.fromInstant(value).toUtcCalendarDate());

  static Color resultColor(BuildContext context, int cents) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    if (cents > 0) {
      return colors.primary;
    }
    if (cents < 0) {
      return colors.error;
    }
    return colors.onSurfaceVariant;
  }

  static IconData resultIcon(int cents) => cents > 0
      ? Icons.trending_up_rounded
      : cents < 0
      ? Icons.trending_down_rounded
      : Icons.horizontal_rule_rounded;
}

class InvestmentPrivacyButton extends StatelessWidget {
  const InvestmentPrivacyButton({
    required this.valuesVisible,
    required this.onPressed,
    super.key,
  });

  final bool valuesVisible;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: valuesVisible
        ? 'Ocultar valores e quantidades'
        : 'Mostrar valores e quantidades',
    onPressed: onPressed,
    icon: Icon(
      valuesVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
    ),
  );
}
