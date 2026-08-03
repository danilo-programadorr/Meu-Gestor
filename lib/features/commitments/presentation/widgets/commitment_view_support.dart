import 'package:flutter/material.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
import 'package:meu_gestor_financeiro/core/dates/sao_paulo_civil_date.dart';
import 'package:meu_gestor_financeiro/core/money/money_formatter.dart';
import 'package:meu_gestor_financeiro/features/commitments/domain/financial_commitment.dart';

extension FinancialCommitmentKindView on FinancialCommitmentKind {
  String get singular => this == FinancialCommitmentKind.payable
      ? 'Conta a pagar'
      : 'Conta a receber';

  String get plural => this == FinancialCommitmentKind.payable
      ? 'Contas a pagar'
      : 'Contas a receber';

  String get settlementVerb =>
      this == FinancialCommitmentKind.payable ? 'Pagar' : 'Receber';

  String get settledLabel =>
      this == FinancialCommitmentKind.payable ? 'Pago' : 'Recebido';

  IconData get icon => this == FinancialCommitmentKind.payable
      ? Icons.outbox_outlined
      : Icons.move_to_inbox_outlined;
}

String formatCivilDate(SaoPauloCivilDate date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/${date.year}';

String commitmentStatusLabel(
  FinancialCommitment commitment,
  SaoPauloCivilDate today,
) {
  if (commitment.isOverdue(today)) {
    return 'Atrasado';
  }
  if (commitment.isPending) {
    return 'Pendente';
  }
  if (commitment.isSettled) {
    return commitment.kind.settledLabel;
  }
  if (commitment.isCancelled) {
    return 'Cancelado';
  }
  return 'Anulado';
}

Color commitmentStatusColor(
  BuildContext context,
  FinancialCommitment commitment,
  SaoPauloCivilDate today,
) {
  final ColorScheme colors = Theme.of(context).colorScheme;
  if (commitment.isOverdue(today)) {
    return colors.error;
  }
  if (commitment.isSettled) {
    return colors.primary;
  }
  if (commitment.isCancelled || commitment.isVoided) {
    return colors.outline;
  }
  return colors.tertiary;
}

final class CommitmentCard extends StatelessWidget {
  const CommitmentCard({
    required this.commitment,
    required this.categoryName,
    required this.today,
    required this.onTap,
    super.key,
  });

  final FinancialCommitment commitment;
  final String categoryName;
  final SaoPauloCivilDate today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String status = commitmentStatusLabel(commitment, today);
    return Semantics(
      button: true,
      label:
          '${commitment.description}, ${MoneyFormatter.format(commitment.amount)}, vencimento ${formatCivilDate(commitment.dueDate)}, $status',
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                CircleAvatar(child: Icon(commitment.kind.icon)),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        commitment.description,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(categoryName),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Vencimento: ${formatCivilDate(commitment.dueDate)}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      MoneyFormatter.format(commitment.amount),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      status,
                      style: TextStyle(
                        color: commitmentStatusColor(
                          context,
                          commitment,
                          today,
                        ),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class CivilDateField extends StatelessWidget {
  const CivilDateField({
    required this.label,
    required this.selectedDate,
    required this.onPressed,
    this.helperText,
    this.errorText,
    this.enabled = true,
    super.key,
  });

  final String label;
  final SaoPauloCivilDate? selectedDate;
  final VoidCallback onPressed;
  final String? helperText;
  final String? errorText;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      Semantics(
        button: true,
        enabled: enabled,
        label: label,
        child: OutlinedButton.icon(
          onPressed: enabled ? onPressed : null,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            alignment: Alignment.centerLeft,
          ),
          icon: const Icon(Icons.calendar_today_outlined),
          label: Text(
            selectedDate == null
                ? 'Selecionar $label'
                : '$label: ${formatCivilDate(selectedDate!)}',
          ),
        ),
      ),
      if (helperText != null) ...<Widget>[
        const SizedBox(height: AppSpacing.xs),
        Text(helperText!, style: Theme.of(context).textTheme.bodySmall),
      ],
      if (errorText != null) ...<Widget>[
        const SizedBox(height: AppSpacing.xs),
        Semantics(
          liveRegion: true,
          child: Text(
            errorText!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ],
    ],
  );
}

Future<SaoPauloCivilDate?> showCivilDatePicker({
  required BuildContext context,
  required SaoPauloCivilDate selectedDate,
  DateTime? lastDate,
  required String helpText,
}) async {
  final DateTime? selected = await showDatePicker(
    context: context,
    initialDate: selectedDate.toUtcCalendarDate(),
    firstDate: DateTime(1900),
    lastDate: lastDate ?? DateTime(2200),
    currentDate: selectedDate.toUtcCalendarDate(),
    locale: const Locale('pt', 'BR'),
    helpText: helpText,
    initialDatePickerMode: DatePickerMode.day,
    initialEntryMode: DatePickerEntryMode.calendarOnly,
  );
  return selected == null ? null : SaoPauloCivilDate.fromCalendarDate(selected);
}
