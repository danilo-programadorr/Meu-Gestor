// Responsabilidade: apresenta a resposta remota com fontes e período civil
// visíveis no modo de texto, sem expor termos internos do contrato técnico.
import 'package:flutter/material.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
import 'package:meu_gestor_financeiro/features/assistant/domain/assistant_context.dart';
import 'package:meu_gestor_financeiro/features/assistant/domain/assistant_grounded_response.dart';
import 'package:meu_gestor_financeiro/features/assistant/presentation/controllers/assistant_remote_conversation_controller.dart';

class AssistantRemoteAnswerPanel extends StatelessWidget {
  const AssistantRemoteAnswerPanel({required this.state, super.key});

  final AssistantRemoteConversationState state;

  @override
  Widget build(BuildContext context) {
    final String title = switch (state.phase) {
      AssistantRemoteConversationPhase.clarificationRequired =>
        'Vamos continuar',
      AssistantRemoteConversationPhase.grounded => 'Luma',
      _ => 'Luma',
    };
    final AssistantGroundedResponse? response = state.response;
    final Map<String, AssistantResponseEvidenceReference> evidenceByPeriod =
        <String, AssistantResponseEvidenceReference>{};
    if (response != null) {
      for (final AssistantGroundedAssertion assertion in response.assertions) {
        final AssistantResponseEvidenceReference evidence = assertion.evidence;
        evidenceByPeriod.putIfAbsent(
          '${evidence.source.name}|${evidence.period.startDate}|'
          '${evidence.period.endDateExclusive}|${evidence.period.timeZone}',
          () => evidence,
        );
      }
    }
    final String semanticMessage = response?.answer ?? state.message;
    return Semantics(
      liveRegion: true,
      label: '$title: $semanticMessage',
      child: Card(
        color: const Color(0xFF1B252D),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.xs),
              if (state.phase != AssistantRemoteConversationPhase.grounded)
                Text(
                  state.message,
                  style: const TextStyle(color: Color(0xFFD5DEE7)),
                ),
              if (state.isPreparing) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                const LinearProgressIndicator(),
              ],
              if (response != null) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  response.answer,
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final AssistantResponseEvidenceReference evidence
                    in evidenceByPeriod.values)
                  _EvidenceLine(evidence: evidence),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  response.disclaimer,
                  style: const TextStyle(color: Color(0xFFB7E8FF)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EvidenceLine extends StatelessWidget {
  const _EvidenceLine({required this.evidence});

  final AssistantResponseEvidenceReference evidence;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(
        'Fonte: ${_sourceLabel(evidence.source)} · '
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
