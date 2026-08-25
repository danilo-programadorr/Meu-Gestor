import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/assistant/domain/assistant_context.dart';
import 'package:meu_gestor_financeiro/features/assistant/presentation/controllers/assistant_summary_provider.dart';
import 'package:meu_gestor_financeiro/features/commitments/domain/financial_commitment.dart';
import 'package:meu_gestor_financeiro/features/commitments/presentation/controllers/financial_commitments_controller.dart';
import 'package:meu_gestor_financeiro/features/investments/presentation/controllers/investments_controller.dart';
import 'package:meu_gestor_financeiro/features/transactions/presentation/controllers/financial_transactions_controller.dart';

void main() {
  test('leituras ainda não confirmadas falham fechadas sem estimar seções', () {
    final AssistantReadModel model = buildAssistantReadModel(
      now: DateTime.utc(2026, 8, 25, 15),
      workspace: const AsyncLoading<FinancialWorkspace>(),
      payables: const AsyncLoading<FinancialCommitmentsState<Payable>>(),
      receivables: const AsyncLoading<FinancialCommitmentsState<Receivable>>(),
      investments: const AsyncLoading<InvestmentsState>(),
    );

    expect(model.isLoading, isTrue);
    expect(model.snapshot.core, isNull);
    expect(model.snapshot.commitments, isNull);
    expect(model.snapshot.investments, isNull);
    expect(
      model.unavailableSources,
      containsAll(<AssistantContextSource>{
        AssistantContextSource.accounts,
        AssistantContextSource.transactions,
        AssistantContextSource.payables,
        AssistantContextSource.receivables,
        AssistantContextSource.investmentOperations,
      }),
    );
  });
}
