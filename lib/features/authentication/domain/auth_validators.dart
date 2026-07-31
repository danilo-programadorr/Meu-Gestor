abstract final class AuthValidators {
  static const int maximumNameLength = 80;
  static const int minimumPasswordLength = 8;

  static String? name(String? value) {
    final String normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      return 'Informe seu nome completo.';
    }
    if (normalized.length < 2) {
      return 'Informe um nome válido.';
    }
    if (normalized.length > maximumNameLength) {
      return 'O nome deve ter no máximo $maximumNameLength caracteres.';
    }
    return null;
  }

  static String? email(String? value) {
    final String normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      return 'Informe seu email.';
    }
    final RegExp emailPattern = RegExp(
      r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$',
      caseSensitive: false,
    );
    if (!emailPattern.hasMatch(normalized)) {
      return 'Informe um email válido.';
    }
    return null;
  }

  static String? requiredPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Informe sua senha.';
    }
    return null;
  }

  static String? strongPassword(String? value) {
    final String? requiredError = requiredPassword(value);
    if (requiredError != null) {
      return requiredError;
    }
    final String password = value!;
    if (password.length < minimumPasswordLength ||
        !RegExp('[A-Z]').hasMatch(password) ||
        !RegExp('[a-z]').hasMatch(password) ||
        !RegExp('[0-9]').hasMatch(password)) {
      return 'Use 8 ou mais caracteres, com maiúscula, minúscula e número.';
    }
    return null;
  }

  static String? passwordConfirmation(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Confirme sua senha.';
    }
    if (value != password) {
      return 'As senhas não são iguais.';
    }
    return null;
  }
}
