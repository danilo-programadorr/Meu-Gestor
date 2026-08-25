import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_gestor_financeiro/features/investments/data/investment_providers.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_income_event.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_performance.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_quote.dart';
import 'package:meu_gestor_financeiro/features/investments/presentation/controllers/investments_controller.dart';

final FutureProvider<InvestmentQuoteReadResult> investmentQuotesProvider =
    FutureProvider.autoDispose<InvestmentQuoteReadResult>((Ref ref) async {
      final InvestmentsState workspace = await ref.watch(
        investmentsControllerProvider.future,
      );
      return ref
          .read(investmentQuoteRepositoryProvider)
          .readQuotes(
            tickers: workspace.assets.map((asset) => asset.ticker),
            serverOnly: true,
          );
    });

final FutureProvider<InvestmentPortfolioPerformance>
investmentPortfolioPerformanceProvider =
    FutureProvider.autoDispose<InvestmentPortfolioPerformance>((Ref ref) async {
      final InvestmentsState workspace = await ref.watch(
        investmentsControllerProvider.future,
      );
      final InvestmentQuoteReadResult quoteResult = await ref.watch(
        investmentQuotesProvider.future,
      );
      final positions = workspace.portfolios.expand(
        (portfolio) => workspace.projectionForPortfolio(portfolio.id).positions,
      );
      final int receivedIncome = workspace.incomeEvents
          .where((event) => event.status == InvestmentIncomeStatus.received)
          .fold<int>(0, (sum, event) => sum + event.netAmountCents);
      return InvestmentPerformanceCalculator.calculate(
        positions: positions,
        quotes: quoteResult.quotes,
        receivedIncomeCents: receivedIncome,
        referenceInstant: ref.read(investmentClockProvider)(),
      );
    });
