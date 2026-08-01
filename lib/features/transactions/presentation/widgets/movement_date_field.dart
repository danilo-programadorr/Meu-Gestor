import 'package:flutter/material.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_transaction_date.dart';
import 'package:meu_gestor_financeiro/features/transactions/presentation/widgets/transaction_view_support.dart';

const String movementDateExplanation =
    'Dia em que o dinheiro entrou ou saiu. Não é a data de vencimento.';
const String futureMovementExplanation =
    'Lançamentos futuros serão adicionados posteriormente em Contas a pagar e receber.';

final class MovementDateField extends StatelessWidget {
  const MovementDateField({
    required this.selectedDate,
    required this.onPressed,
    this.enabled = true,
    this.errorText,
    super.key,
  });

  final DateTime? selectedDate;
  final VoidCallback onPressed;
  final bool enabled;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final DateTime? date = selectedDate;
    final String buttonText = date == null
        ? 'Selecionar data da movimentação'
        : 'Data da movimentação: ${formatFinancialDate(FinancialTransactionDate.fromCalendarDate(date))}';
    final TextStyle? explanationStyle = Theme.of(context).textTheme.bodySmall;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          container: true,
          button: true,
          enabled: enabled,
          label: 'Selecionar data da movimentação',
          excludeSemantics: true,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
            ),
            onPressed: enabled ? onPressed : null,
            child: Row(
              children: <Widget>[
                const Icon(Icons.calendar_today_outlined),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(buttonText)),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(movementDateExplanation, style: explanationStyle),
        const SizedBox(height: AppSpacing.xxs),
        Text(futureMovementExplanation, style: explanationStyle),
        if (errorText case final String error) ...<Widget>[
          const SizedBox(height: AppSpacing.xxs),
          Semantics(
            liveRegion: true,
            child: Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ],
    );
  }
}

Future<DateTime?> showMovementDatePicker({
  required BuildContext context,
  required DateTime selectedDate,
  required DateTime today,
}) {
  final DateTime initialDate = _pickerDate(selectedDate);
  final DateTime lastDate = _pickerDate(today);
  return showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: DateTime(1900),
    lastDate: lastDate,
    currentDate: lastDate,
    initialDatePickerMode: DatePickerMode.day,
    initialEntryMode: DatePickerEntryMode.calendarOnly,
    locale: const Locale('pt', 'BR'),
    helpText: 'Data da movimentação',
  );
}

DateTime _pickerDate(DateTime date) =>
    DateTime(date.year, date.month, date.day);
