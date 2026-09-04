import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/assistant/domain/assistant_context.dart';
import 'package:meu_gestor_financeiro/features/assistant/domain/assistant_failure.dart';
import 'package:meu_gestor_financeiro/features/assistant/domain/assistant_grounded_response.dart';

void main() {
  final AssistantCivilPeriod period = AssistantCivilPeriod(
    startDate: '2026-09-01',
    endDateExclusive: '2026-09-02',
  );

  test('representa resposta com referência efêmera e período civil', () {
    final AssistantGroundedResponse response = AssistantGroundedResponse(
      status: AssistantGroundedResponseStatus.grounded,
      answer: 'Resumo confirmado.',
      assertions: <AssistantGroundedAssertion>[
        AssistantGroundedAssertion(
          statement: 'Há uma evidência confirmada.',
          evidence: AssistantResponseEvidenceReference(
            alias: 'ev_accounts_001',
            source: AssistantContextSource.accounts,
            period: period,
          ),
        ),
      ],
      missingData: const <String>[],
      disclaimer:
          'Conteúdo informativo; nenhuma ação financeira foi realizada.',
    );
    expect(
      response.assertions.single.evidence.period.timeZone,
      'America/Sao_Paulo',
    );
  });

  test('bloqueia recomendação e resposta sem evidência', () {
    expect(
      () => AssistantGroundedAssertion(
        statement: 'Compre este ativo.',
        evidence: AssistantResponseEvidenceReference(
          alias: 'ev_accounts_001',
          source: AssistantContextSource.accounts,
          period: period,
        ),
      ),
      throwsA(isA<AssistantFailure>()),
    );
    expect(
      () => AssistantGroundedResponse(
        status: AssistantGroundedResponseStatus.grounded,
        answer: 'Resumo confirmado.',
        assertions: const <AssistantGroundedAssertion>[],
        missingData: const <String>[],
        disclaimer:
            'Conteúdo informativo; nenhuma ação financeira foi realizada.',
      ),
      throwsA(isA<AssistantFailure>()),
    );
  });
}
