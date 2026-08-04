import 'package:flutter/material.dart';
import 'package:meu_gestor_financeiro/app/theme/app_radius.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
import 'package:meu_gestor_financeiro/app/theme/app_theme_colors.dart';
import 'package:meu_gestor_financeiro/core/money/money.dart';
import 'package:meu_gestor_financeiro/core/money/money_formatter.dart';
import 'package:meu_gestor_financeiro/features/accounts/domain/financial_account.dart';
import 'package:meu_gestor_financeiro/features/accounts/presentation/widgets/account_view_support.dart';

class AccountCard extends StatelessWidget {
  const AccountCard({
    required this.account,
    required this.onTap,
    this.currentBalance,
    this.onEdit,
    this.onArchive,
    this.onRestore,
    this.actionsEnabled = true,
    super.key,
  });

  final FinancialAccount account;
  final VoidCallback onTap;
  final Money? currentBalance;
  final VoidCallback? onEdit;
  final VoidCallback? onArchive;
  final VoidCallback? onRestore;
  final bool actionsEnabled;

  @override
  Widget build(BuildContext context) {
    final Money balance = currentBalance ?? account.openingBalance;
    final AppThemeColors themeColors = AppThemeColors.of(context);
    final bool negative = balance.cents < 0;
    final bool zero = balance.cents == 0;
    final Color stateColor = negative
        ? themeColors.expense
        : zero
        ? themeColors.info
        : themeColors.success;
    final String stateLabel = negative
        ? 'Saldo negativo'
        : zero
        ? 'Saldo zerado'
        : 'Saldo positivo';
    final IconData stateIcon = negative
        ? Icons.trending_down_rounded
        : zero
        ? Icons.trending_flat_rounded
        : Icons.trending_up_rounded;
    final bool hasActions =
        onEdit != null || onArchive != null || onRestore != null;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.large,
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            button: true,
            label:
                '${account.name}, ${account.type.label}, $stateLabel, '
                '${MoneyFormatter.format(balance)}. Abrir detalhes.',
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final bool stacked =
                        constraints.maxWidth < 310 ||
                        MediaQuery.textScalerOf(context).scale(16) > 22;
                    final Widget identity = Row(
                      children: <Widget>[
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.12),
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          child: Text(_monogram(account.name)),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                account.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Row(
                                children: <Widget>[
                                  Icon(
                                    accountTypeIcon(account.type),
                                    size: 16,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: AppSpacing.xxs),
                                  Expanded(
                                    child: Text(
                                      account.type.label,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                      ],
                    );
                    final Widget amount = Column(
                      crossAxisAlignment: stacked
                          ? CrossAxisAlignment.start
                          : CrossAxisAlignment.end,
                      children: <Widget>[
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: stacked
                              ? Alignment.centerLeft
                              : Alignment.centerRight,
                          child: Text(
                            MoneyFormatter.format(balance),
                            style: Theme.of(
                              context,
                            ).textTheme.titleLarge?.copyWith(color: stateColor),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(stateIcon, size: 16, color: stateColor),
                            const SizedBox(width: AppSpacing.xxs),
                            Text(
                              stateLabel,
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(color: stateColor),
                            ),
                          ],
                        ),
                        if (!account.includeInTotal)
                          Text(
                            'Não participa do total geral',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                      ],
                    );
                    if (stacked) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          identity,
                          const SizedBox(height: AppSpacing.md),
                          amount,
                        ],
                      );
                    }
                    return Row(
                      children: <Widget>[
                        Expanded(child: identity),
                        const SizedBox(width: AppSpacing.md),
                        Flexible(child: amount),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          if (hasActions) ...<Widget>[
            Divider(
              height: 1,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  if (onEdit != null)
                    Semantics(
                      button: true,
                      enabled: actionsEnabled,
                      label: 'Editar conta',
                      child: ExcludeSemantics(
                        child: IconButton(
                          tooltip: 'Editar conta',
                          onPressed: actionsEnabled ? onEdit : null,
                          icon: const Icon(Icons.edit_outlined),
                        ),
                      ),
                    ),
                  if (onEdit != null &&
                      (onArchive != null || onRestore != null))
                    const SizedBox(width: AppSpacing.xs),
                  if (onArchive != null)
                    Semantics(
                      button: true,
                      enabled: actionsEnabled,
                      label: 'Arquivar conta',
                      child: ExcludeSemantics(
                        child: IconButton(
                          tooltip: 'Arquivar conta',
                          onPressed: actionsEnabled ? onArchive : null,
                          icon: const Icon(Icons.archive_outlined),
                        ),
                      ),
                    ),
                  if (onRestore != null)
                    Semantics(
                      button: true,
                      enabled: actionsEnabled,
                      label: 'Restaurar conta',
                      child: ExcludeSemantics(
                        child: IconButton(
                          tooltip: 'Restaurar conta',
                          onPressed: actionsEnabled ? onRestore : null,
                          icon: const Icon(Icons.restore_rounded),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _monogram(String name) {
  final String normalized = name.trim();
  return normalized.isEmpty ? 'C' : normalized.characters.first.toUpperCase();
}
