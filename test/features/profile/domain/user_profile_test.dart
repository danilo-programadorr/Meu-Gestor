import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/privacy/domain/legal_document_versions.dart';

import '../../../support/profile_fixtures.dart';

void main() {
  test('perfil com versões atuais está apto ao portão jurídico', () {
    final profile = createTestProfile();

    expect(profile.hasCurrentLegalVersions, isTrue);
    expect(profile.aiConsentEnabled, isFalse);
    expect(profile.analyticsConsentEnabled, isFalse);
  });

  test('perfil com termos antigos exige novo aceite', () {
    final profile = createTestProfile(termsVersion: 'terms-dev-0.9.0');

    expect(profile.hasCurrentLegalVersions, isFalse);
  });

  test('versões jurídicas ficam centralizadas', () {
    expect(LegalDocumentVersions.terms, 'terms-dev-1.0.0');
    expect(LegalDocumentVersions.privacy, 'privacy-dev-1.0.0');
  });
}
