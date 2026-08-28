import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/assistant/domain/assistant_action.dart';
import 'package:meu_gestor_financeiro/features/assistant/domain/assistant_failure.dart';

void main() {
  test(
    'leitura é livre, mutação vira proposta e ações críticas são proibidas',
    () {
      expect(
        AssistantPermissionPolicy.decisionFor(AssistantActionKind.explain),
        AssistantActionDecision.readOnly,
      );
      expect(
        AssistantPermissionPolicy.decisionFor(AssistantActionKind.draftUpdate),
        AssistantActionDecision.proposalOnly,
      );
      expect(
        AssistantPermissionPolicy.decisionFor(
          AssistantActionKind.draftReminder,
        ),
        AssistantActionDecision.proposalOnly,
      );
      for (final AssistantActionKind kind in <AssistantActionKind>[
        AssistantActionKind.resetFinancialData,
        AssistantActionKind.deleteAccount,
        AssistantActionKind.changeAuthentication,
        AssistantActionKind.changeEntitlement,
        AssistantActionKind.changeOwnerAccess,
      ]) {
        expect(
          AssistantPermissionPolicy.decisionFor(kind),
          AssistantActionDecision.forbidden,
        );
      }
    },
  );

  test('proposta mutável exige confirmação exata, própria e recente', () {
    final DateTime now = DateTime.utc(2026, 8, 24, 12);
    final AssistantActionProposal proposal = AssistantActionProposal(
      proposalId: 'proposal_123456789',
      kind: AssistantActionKind.draftUpdate,
      targetAlias: 'account_1',
      preview: 'Alterar nome da conta após revisão.',
      previewDigest: 'digest_1234567890',
      expiresAt: now.add(const Duration(minutes: 5)),
      requiresExplicitConfirmation: true,
    );
    expect(
      () => AssistantActionConfirmationPolicy.assertConfirmed(
        proposal: proposal,
        confirmation: AssistantActionConfirmation(
          proposalId: proposal.proposalId,
          previewDigest: proposal.previewDigest,
          authenticatedUid: 'own-user',
          ownerId: 'own-user',
          confirmedAt: now,
        ),
        serverNow: now.add(const Duration(minutes: 1)),
      ),
      returnsNormally,
    );
  });

  test('recusa confirmação vencida, divergente ou cruzada', () {
    final DateTime now = DateTime.utc(2026, 8, 24, 12);
    final AssistantActionProposal proposal = AssistantActionProposal(
      proposalId: 'proposal_123456789',
      kind: AssistantActionKind.draftDelete,
      targetAlias: 'unused_asset_1',
      preview: 'Excluir ativo sem histórico após revalidação.',
      previewDigest: 'digest_1234567890',
      expiresAt: now.add(const Duration(minutes: 5)),
      requiresExplicitConfirmation: true,
    );
    for (final AssistantActionConfirmation confirmation
        in <AssistantActionConfirmation>[
          AssistantActionConfirmation(
            proposalId: proposal.proposalId,
            previewDigest: 'different_digest',
            authenticatedUid: 'own-user',
            ownerId: 'own-user',
            confirmedAt: now,
          ),
          AssistantActionConfirmation(
            proposalId: proposal.proposalId,
            previewDigest: proposal.previewDigest,
            authenticatedUid: 'own-user',
            ownerId: 'other-user',
            confirmedAt: now,
          ),
        ]) {
      expect(
        () => AssistantActionConfirmationPolicy.assertConfirmed(
          proposal: proposal,
          confirmation: confirmation,
          serverNow: now.add(const Duration(minutes: 1)),
        ),
        throwsA(isA<AssistantFailure>()),
      );
    }
    expect(
      () => AssistantActionConfirmationPolicy.assertConfirmed(
        proposal: proposal,
        confirmation: AssistantActionConfirmation(
          proposalId: proposal.proposalId,
          previewDigest: proposal.previewDigest,
          authenticatedUid: 'own-user',
          ownerId: 'own-user',
          confirmedAt: now,
        ),
        serverNow: now.add(const Duration(minutes: 6)),
      ),
      throwsA(isA<AssistantFailure>()),
    );
  });
}
