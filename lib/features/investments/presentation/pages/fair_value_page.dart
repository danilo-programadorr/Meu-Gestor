import 'package:flutter/material.dart';
import 'package:meu_gestor_financeiro/app/routing/app_routes.dart';
import 'package:meu_gestor_financeiro/app/routing/safe_back_navigation.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/fair_value.dart';

class FairValuePage extends StatelessWidget {
  const FairValuePage({super.key, this.snapshot});
  final FairValueSnapshot? snapshot;

  @override
  Widget build(BuildContext context) {
    final FairValueResult result = FairValueCalculator.calculate(snapshot);
    return SafeBackScope(
      fallbackLocation: AppRoutes.investmentTools,
      child: Scaffold(
        appBar: AppBar(
          leading: const SafeBackButton(
            fallbackLocation: AppRoutes.investmentTools,
          ),
          title: const Text('Preço justo'),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: <Widget>[
              Text('Análises', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Referências patrimoniais e fundamentais',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.md),
              _ResultCard(result: result, snapshot: snapshot),
              const SizedBox(height: AppSpacing.md),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: Text(
                    'Esta tela não é recomendação de compra ou venda. Valores só aparecem após dados automáticos validados, com fonte, data/hora, moeda e atraso declarados.',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result, required this.snapshot});
  final FairValueResult result;
  final FairValueSnapshot? snapshot;
  @override
  Widget build(BuildContext context) {
    final String message = switch (result.status) {
      FairValueStatus.unavailable => 'Aguardando dados fundamentais validados.',
      FairValueStatus.stale =>
        'Dados desatualizados: aguarde uma fonte automática validada.',
      FairValueStatus.incompatible => 'Moeda incompatível com esta análise.',
      FairValueStatus.bdrPendingNormalization =>
        'BDR aguardando normalização da relação do recibo, moeda e ativo subjacente.',
      FairValueStatus.available =>
        snapshot!.kind == FairValueAssetKind.fii
            ? 'Referência patrimonial disponível: valor patrimonial por cota, P/VP e deságio/ágio.'
            : 'Número de Graham estimado e potencial teórico disponíveis.',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(message, style: Theme.of(context).textTheme.titleMedium),
            if (result.status == FairValueStatus.available) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              if (result.fairPriceCents != null)
                Text('Preço justo estimado: disponível com dados validados.'),
              if (result.theoreticalPotentialBasisPoints != null)
                const Text(
                  'Potencial teórico: disponível com cotação compatível.',
                ),
              if (result.priceToBookBasisPoints != null)
                const Text(
                  'P/VP e deságio/ágio: referência patrimonial, não Graham.',
                ),
            ],
            if (snapshot != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Moeda: ${snapshot!.currencyCode} • Fonte: dados automáticos validados • Data/hora: ${snapshot!.sourceAt.toLocal()}',
              ),
            ],
          ],
        ),
      ),
    );
  }
}
