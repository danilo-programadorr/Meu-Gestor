import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/assistant/domain/assistant_consent.dart';
import 'package:meu_gestor_financeiro/features/assistant/domain/assistant_failure.dart';

void main() {
  AssistantAuthorizationContext authorization({
    bool authenticated = true,
    bool appCheckVerified = true,
    bool emailVerified = true,
    bool legalProfileVerified = true,
    String uid = 'own-user',
    String ownerId = 'own-user',
    bool consent = true,
    String? policy = AssistantConsentPolicy.currentVersion,
    bool fromServer = true,
    bool pending = false,
  }) => AssistantAuthorizationContext(
    authenticated: authenticated,
    appCheckVerified: appCheckVerified,
    emailVerified: emailVerified,
    legalProfileVerified: legalProfileVerified,
    authenticatedUid: uid,
    requestedOwnerId: ownerId,
    aiConsentEnabled: consent,
    acceptedPolicyVersion: policy,
    aiConsentUpdatedAt: DateTime.utc(2026, 8, 24),
    profileFromServer: fromServer,
    profileHasPendingWrites: pending,
  );

  test('autoriza contexto próprio com consentimento atual server-only', () {
    expect(
      () => AssistantConsentPolicy.assertCanUse(authorization()),
      returnsNormally,
    );
  });

  test('owner não ignora UID nem consentimento', () {
    expect(
      () => AssistantConsentPolicy.assertCanUse(
        authorization(ownerId: 'other-user'),
      ),
      throwsA(
        isA<AssistantFailure>().having(
          (failure) => failure.kind,
          'kind',
          AssistantFailureKind.ownerMismatch,
        ),
      ),
    );
    expect(
      () => AssistantConsentPolicy.assertCanUse(authorization(consent: false)),
      throwsA(isA<AssistantFailure>()),
    );
  });

  test('cache, escrita pendente e política antiga falham fechados', () {
    for (final AssistantAuthorizationContext context
        in <AssistantAuthorizationContext>[
          authorization(fromServer: false),
          authorization(pending: true),
          authorization(policy: 'old-policy'),
        ]) {
      expect(
        () => AssistantConsentPolicy.assertCanUse(context),
        throwsA(isA<AssistantFailure>()),
      );
    }
  });

  test('memória persistente começa desabilitada e exige opt-in separado', () {
    expect(AssistantMemoryPolicy.defaultMode, AssistantMemoryMode.none);
    expect(
      AssistantMemoryPolicy.canPersist(
        mode: AssistantMemoryMode.savedSummary,
        separateMemoryConsent: false,
        implementationAvailable: true,
      ),
      isFalse,
    );
    expect(
      AssistantMemoryPolicy.canPersist(
        mode: AssistantMemoryMode.savedSummary,
        separateMemoryConsent: true,
        implementationAvailable: false,
      ),
      isFalse,
    );
  });
}
