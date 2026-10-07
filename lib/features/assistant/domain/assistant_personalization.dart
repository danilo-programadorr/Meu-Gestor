// Responsabilidade: define a identidade pública da assistente e o tratamento
// local escolhido pela pessoa, sem transportar essa preferência ao provedor.
enum AssistantAddressMode { profileFirstName, customName, none }

final class AssistantPersonalization {
  AssistantPersonalization({required this.mode, String? customName})
    : customName = mode == AssistantAddressMode.customName
          ? requireValidAddressName(customName ?? '')
          : null {
    if (mode != AssistantAddressMode.customName && customName != null) {
      throw const FormatException('assistant_personalization_invalid');
    }
  }

  const AssistantPersonalization.profileFirstName()
    : mode = AssistantAddressMode.profileFirstName,
      customName = null;

  const AssistantPersonalization.none()
    : mode = AssistantAddressMode.none,
      customName = null;

  static const String assistantName = 'Luma';
  static const int maximumAddressLength = 40;

  final AssistantAddressMode mode;
  final String? customName;

  String? addressName({required String profileDisplayName}) => switch (mode) {
    AssistantAddressMode.profileFirstName => firstName(profileDisplayName),
    AssistantAddressMode.customName => customName,
    AssistantAddressMode.none => null,
  };

  static String firstName(String displayName) {
    final String normalized = _normalize(displayName);
    if (normalized.isEmpty) return '';
    return normalized.split(' ').first;
  }

  static String requireValidAddressName(String value) {
    final String normalized = _normalize(value);
    if (normalized.length < 2 ||
        normalized.length > maximumAddressLength ||
        RegExp(r'[\x00-\x1F\x7F]').hasMatch(normalized)) {
      throw const FormatException('assistant_address_name_invalid');
    }
    return normalized;
  }

  static String? validateAddressName(String? value) {
    try {
      requireValidAddressName(value ?? '');
      return null;
    } on FormatException {
      return 'Use um nome ou apelido entre 2 e $maximumAddressLength caracteres.';
    }
  }

  static String _normalize(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ');
}

// Responsabilidade: compõe apenas o cumprimento local da sessão a partir da
// preferência já resolvida, sem incluir identidade na consulta remota.
String assistantSessionGreeting(String? addressName) => switch (addressName) {
  final String name when name.isNotEmpty =>
    'Oi, $name. O que você quer conversar sobre suas finanças?',
  _ => 'Oi. O que você quer conversar sobre suas finanças?',
};

abstract interface class AssistantPersonalizationRepository {
  Future<AssistantPersonalization> readOwn({required String ownerId});

  Future<void> saveOwn({
    required String ownerId,
    required AssistantPersonalization personalization,
  });
}
