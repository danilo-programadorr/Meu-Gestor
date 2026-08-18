import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:meu_gestor_financeiro/app/routing/app_routes.dart';
import 'package:meu_gestor_financeiro/app/routing/safe_back_navigation.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
import 'package:meu_gestor_financeiro/core/privacy/financial_privacy_controller.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_performance.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_quote.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/scaled_investment_value.dart';
import 'package:meu_gestor_financeiro/features/investments/presentation/controllers/investment_quotes_controller.dart';
import 'package:meu_gestor_financeiro/features/investments/presentation/widgets/investment_view_support.dart';

/// Painel de leitura para snapshots globais já confirmados pelo backend futuro.
/// A fonte local não contém snapshots e, por isso, a tela começa indisponível.
class InvestmentQuotesPage extends ConsumerWidget {
  const InvestmentQuotesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool visible = ref.watch(financialPrivacyControllerProvider);
    final AsyncValue<InvestmentPortfolioPerformance> performance = ref.watch(
      investmentPortfolioPerformanceProvider,
    );
    return SafeBackScope(
      fallbackLocation: AppRoutes.investments,
      child: Scaffold(
        appBar: AppBar(
          leading: const SafeBackButton(
            fallbackLocation: AppRoutes.investments,
          ),
          title: const Text('Cotações e rentabilidade'),
          actions: <Widget>[
            InvestmentPrivacyButton(
              valuesVisible: visible,
              onPressed: () => ref
                  .read(financialPrivacyControllerProvider.notifier)
                  .toggle(),
            ),
          ],
        ),
        body: SafeArea(
          child: performance.when(
            loading: () => const Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Carregando cotações confirmadas',
              ),
            ),
            error: (Object _, StackTrace _) => _Unavailable(
              onRetry: () =>
                  ref.invalidate(investmentPortfolioPerformanceProvider),
            ),
            data: (InvestmentPortfolioPerformance result) => ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.compactPageHorizontal,
                AppSpacing.md,
                AppSpacing.compactPageHorizontal,
                AppSpacing.xxl,
              ),
              children: <Widget>[
                const _Notice(),
                const SizedBox(height: AppSpacing.md),
                if (result.quotedAssetCount == 0) ...<Widget>[
                  _Unavailable(
                    onRetry: () =>
                        ref.invalidate(investmentPortfolioPerformanceProvider),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                _Filters(
                  hasAssets: result.totalAssetCount > 0,
                  quoted: result.quotedAssetCount,
                  total: result.totalAssetCount,
                ),
                const SizedBox(height: AppSpacing.md),
                _PerformanceCard(performance: result, visible: visible),
                const SizedBox(height: AppSpacing.md),
                if (result.quotedAssetCount > 0)
                  ...result.positions.map(
                    (InvestmentPositionPerformance position) =>
                        _QuoteTile(performance: position, visible: visible),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice();

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: 'Cotações informativas e atrasadas',
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: const Text(
          'Cotações são informativas, podem ter atraso e não constituem recomendação financeira. '
          'Nenhum preço altera suas operações, posição, saldo ou proventos.',
        ),
      ),
    ),
  );
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.hasAssets,
    required this.quoted,
    required this.total,
  });

  final bool hasAssets;
  final int quoted;
  final int total;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Cobertura da carteira',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            hasAssets
                ? '$quoted de $total ativos possuem uma cotação confirmada.'
                : 'Cadastre ativos para acompanhar a cobertura quando o serviço estiver disponível.',
          ),
          const SizedBox(height: AppSpacing.sm),
          const Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              Chip(label: Text('Carteira: todas')),
              Chip(label: Text('Classe: todas')),
              Chip(label: Text('Ativo: todos')),
              Chip(label: Text('Período: disponível')),
            ],
          ),
        ],
      ),
    ),
  );
}

class _PerformanceCard extends StatelessWidget {
  const _PerformanceCard({required this.performance, required this.visible});

  final InvestmentPortfolioPerformance performance;
  final bool visible;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Resultado econômico',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          _MoneyLine(
            label: 'Patrimônio estimado',
            value: performance.estimatedMarketValueCents,
            visible: visible,
          ),
          _MoneyLine(
            label: 'Resultado não realizado',
            value: performance.unrealizedResultCents,
            visible: visible,
          ),
          _MoneyLine(
            label: 'Resultado realizado',
            value: performance.realizedResultCents,
            visible: visible,
          ),
          _MoneyLine(
            label: 'Proventos recebidos',
            value: performance.receivedIncomeCents,
            visible: visible,
          ),
          _MoneyLine(
            label: 'Total econômico',
            value: performance.totalEconomicResultCents,
            visible: visible,
          ),
          if (!performance.hasFullCoverage) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'O total não é exibido enquanto faltarem cotações. Não há gráfico de evolução sem snapshots reais.',
            ),
          ],
        ],
      ),
    ),
  );
}

class _MoneyLine extends StatelessWidget {
  const _MoneyLine({
    required this.label,
    required this.value,
    required this.visible,
  });
  final String label;
  final int? value;
  final bool visible;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
    child: Row(
      children: <Widget>[
        Expanded(child: Text(label)),
        Text(
          value == null
              ? 'Indisponível'
              : InvestmentViewSupport.money(value!, visible: visible),
          textAlign: TextAlign.end,
        ),
      ],
    ),
  );
}

class _QuoteTile extends StatelessWidget {
  const _QuoteTile({required this.performance, required this.visible});
  final InvestmentPositionPerformance performance;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final InvestmentQuote? quote = performance.quote;
    return Card(
      child: ListTile(
        title: Text(performance.position.asset.ticker),
        subtitle: Text(
          quote == null || !quote.hasPrice
              ? 'Cotação indisponível'
              : '${_quoteLabel(quote)} · R\$ ${InvestmentUnitPrice.fromScaled(quote.unitPriceScaled).formatPtBr()} · '
                    '${_formatVariation(quote.variationBasisPoints!)} · '
                    '${DateFormat('dd/MM HH:mm', 'pt_BR').format(quote.observedAt.toLocal())} · '
                    '${quote.declaredDelay.inMinutes} min de atraso',
        ),
        trailing: Text(
          performance.estimatedMarketValueCents == null
              ? 'Indisponível'
              : InvestmentViewSupport.money(
                  performance.estimatedMarketValueCents!,
                  visible: visible,
                ),
        ),
      ),
    );
  }

  String _quoteLabel(InvestmentQuote quote) => switch (quote.availability) {
    InvestmentQuoteAvailability.available => 'Disponível',
    InvestmentQuoteAvailability.delayed => 'Atrasada',
    InvestmentQuoteAvailability.marketClosed => 'Mercado fechado',
    InvestmentQuoteAvailability.corporateActionPossible =>
      'Possível evento corporativo',
    InvestmentQuoteAvailability.invalid => 'Cotação inválida',
    InvestmentQuoteAvailability.unavailable => 'Cotação indisponível',
  };

  String _formatVariation(int basisPoints) {
    final String signal = basisPoints > 0 ? '+' : '';
    final int absolute = basisPoints.abs();
    return '$signal${basisPoints < 0 ? '-' : ''}${absolute ~/ 100},${(absolute % 100).toString().padLeft(2, '0')}%';
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: <Widget>[
          const Icon(Icons.cloud_off_outlined, size: 40),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Cotações indisponíveis',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Ainda não existe um provedor autorizado nem snapshots de mercado confirmados para exibir.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Atualizar estado'),
          ),
        ],
      ),
    ),
  );
}
