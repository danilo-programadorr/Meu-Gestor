import 'package:flutter/material.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
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
    return Semantics(
      label:
          'Total das contas incluídas ${MoneyFormatter.format(total)}. '
          '$activeAccountCount contas ativas.',
      child: Card(
        color: Theme.of(context).colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Total atual das contas incluídas',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                MoneyFormatter.format(total),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '$activeAccountCount ${activeAccountCount == 1 ? 'conta ativa' : 'contas ativas'}',
              ),
              const SizedBox(height: AppSpacing.xxs),
              const Text('Calculado com saldos iniciais e lançamentos ativos.'),
            ],
          ),
        ),
      ),
    );
  }
}
