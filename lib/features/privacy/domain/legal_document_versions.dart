abstract final class LegalDocumentVersions {
  static const String terms = 'terms-dev-1.0.0';
  static const String privacy = 'privacy-dev-1.0.0';

  static bool areCurrent({
    required String termsVersion,
    required String privacyVersion,
  }) {
    return termsVersion == terms && privacyVersion == privacy;
  }
}
