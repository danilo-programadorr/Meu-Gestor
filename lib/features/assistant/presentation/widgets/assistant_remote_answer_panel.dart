// Responsabilidade: apresenta uma resposta remota somente como informação
// fundamentada, com fontes e período civil visíveis e ação sempre explícita.
import 'package:flutter/material.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
import 'package:meu_gestor_financeiro/features/assistant/domain/assistant_context.dart';
import 'package:meu_gestor_financeiro/features/assistant/domain/assistant_grounded_response.dart';
import 'package:meu_gestor_financeiro/features/assistant/presentation/controllers/assistant_remote_conversation_controller.dart';

class AssistantRemoteAnswerPanel extends StatelessWidget {
  const AssistantRemoteAnswerPanel({
    required this.state,
    required this.onRequest,
    super.key,
  });

  final AssistantRemoteConversationState state;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: 'Resposta fundamentada: ${state.message}',
    child: Card(
      color: const Color(0xFF1B252D),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Resposta fundamentada',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              state.message,
              style: const TextStyle(color: Color(0xFFD5DEE7)),
            ),
            if (state.isPreparing) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              const LinearProgressIndicator(),
            ],
            if (state.response
                case final AssistantGroundedResponse response) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Text(
                response.answer,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final AssistantGroundedAssertion assertion
                  in response.assertions)
                _EvidenceLine(assertion: assertion),
              const SizedBox(height: AppSpacing.xs),
              Text(
                response.disclaimer,
                style: const TextStyle(color: Color(0xFFB7E8FF)),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              key: const ValueKey<String>('assistant-grounded-answer-action'),
              onPressed: state.isPreparing ? null : onRequest,
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('Consultar resposta fundamentada'),
            ),
            const Text(
              'A consulta nunca é iniciada automaticamente por voz ou texto.',
              style: TextStyle(color: Color(0xFFB7E8FF)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
  );
}

class _EvidenceLine extends StatelessWidget {
  const _EvidenceLine({required this.assertion});

  final AssistantGroundedAssertion assertion;

  @override
  Widget build(BuildContext context) {
    final AssistantResponseEvidenceReference evidence = assertion.evidence;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(
        '${assertion.statement}\nFonte: ${_sourceLabel(evidence.source)} · '
        'Período: ${evidence.period.startDate} até antes de '
        '${evidence.period.endDateExclusive} (${evidence.period.timeZone})',
        style: const TextStyle(color: Color(0xFFD5DEE7)),
      ),
    );
  }
}

String _sourceLabel(AssistantContextSource source) => switch (source) {
  AssistantContextSource.accounts => 'Contas e carteiras',
  AssistantContextSource.transactions => 'Lançamentos',
  AssistantContextSource.payables => 'Contas a pagar',
  AssistantContextSource.receivables => 'Contas a receber',
  AssistantContextSource.financialCalendar => 'Calendário financeiro',
  AssistantContextSource.investmentPortfolios ||
  AssistantContextSource.investmentAssets ||
  AssistantContextSource.investmentOperations ||
  AssistantContextSource.investmentIncome ||
  AssistantContextSource.investmentPerformance => 'Investimentos',
  AssistantContextSource.dashboardSummary => 'Resumo financeiro',
  _ => 'Fonte confirmada',
};
