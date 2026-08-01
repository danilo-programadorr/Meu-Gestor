import 'package:meu_gestor_financeiro/core/errors/app_exception.dart';

abstract final class DisplayName {
  static const int minimumLength = 2;
  static const int maximumLength = 80;
  static final RegExp _whitespace = RegExp(r'\s+');
  static final RegExp _controlCharacters = RegExp(r'[\x00-\x1F\x7F]');

  static String normalize(String value) {
    return value.trim().replaceAll(_whitespace, ' ');
  }

  static String? validate(String? value) {
    final String normalized = normalize(value ?? '');
    if (normalized.length < minimumLength) {
      return 'Informe um nome com pelo menos $minimumLength caracteres.';
    }
    if (normalized.length > maximumLength) {
      return 'O nome deve ter no máximo $maximumLength caracteres.';
    }
    if (_controlCharacters.hasMatch(normalized)) {
      return 'O nome contém caracteres não permitidos.';
    }
    return null;
  }

  static String requireValid(String value) {
    final String normalized = normalize(value);
    final String? error = validate(normalized);
    if (error != null) {
      throw ValidationException(code: 'invalid_display_name', message: error);
    }
    return normalized;
  }
}
