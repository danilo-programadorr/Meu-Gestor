import 'package:flutter/material.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
import 'package:meu_gestor_financeiro/app/theme/app_theme_colors.dart';
import 'package:meu_gestor_financeiro/core/money/money.dart';
import 'package:meu_gestor_financeiro/core/money/money_formatter.dart';

class AccountsTotalCard extends StatelessWidget {
  const AccountsTotalCard({
    required this.total,
    required this.activeAccountCount,
    super.key,
  });

  final Money total;
  final int activeAccountCount;

  @override
  Widget build(BuildContext context) {
    final AppThemeColors themeColors = AppThemeColors.of(context);
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Semantics(
      label:
          'Total das contas incluídas ${MoneyFormatter.format(total)}. '
          '$activeAccountCount contas ativas.',
      child: Card(
        key: const ValueKey<String>('accounts-total-card'),
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: Theme.of(context).brightness == Brightness.dark
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      themeColors.balanceGradientStart,
                      themeColors.balanceGradientEnd,
                    ],
                  )
                : null,
            color: Theme.of(context).brightness == Brightness.light
                ? themeColors.subtleSurface
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 20,
                        color: colors.primary,
                        semanticLabel: 'Saldo das contas',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Saldo atual das contas',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    MoneyFormatter.format(total),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.check_circle_outline_rounded,
                      size: 16,
                      color: colors.primary,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Wrap(
                        spacing: AppSpacing.xxs,
                        children: <Widget>[
                          Text(
                            '$activeAccountCount ${activeAccountCount == 1 ? 'conta ativa' : 'contas ativas'}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            '• Lançamentos confirmados',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
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
