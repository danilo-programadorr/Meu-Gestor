abstract final class EmailMasker {
  static String mask(String? email) {
    if (email == null || !email.contains('@')) {
      return 'seu endereço de email';
    }
    final List<String> parts = email.split('@');
    if (parts.length != 2 || parts.first.isEmpty || parts.last.isEmpty) {
      return 'seu endereço de email';
    }

    final String local = parts.first;
    final String domain = parts.last;
    final int dotIndex = domain.lastIndexOf('.');
    final String domainName = dotIndex > 0
        ? domain.substring(0, dotIndex)
        : domain;
    final String suffix = dotIndex > 0 ? domain.substring(dotIndex) : '';
    return '${local[0]}***@${domainName[0]}***$suffix';
  }
}
