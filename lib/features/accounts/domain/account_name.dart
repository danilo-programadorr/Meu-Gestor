import 'package:meu_gestor_financeiro/core/errors/app_exception.dart';

abstract final class AccountName {
  static const int minimumLength = 2;
  static const int maximumLength = 60;

  static String normalize(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ');

  static String? validate(String value) {
    if (RegExp(r'[\x00-\x1F\x7F]').hasMatch(value)) {
      return 'O nome contém caracteres não permitidos.';
    }
    final String normalized = normalize(value);
    if (normalized.length < minimumLength ||
        normalized.length > maximumLength) {
      return 'Informe um nome entre 2 e 60 caracteres.';
    }
    return null;
  }

  static String requireValid(String value) {
    final String? message = validate(value);
    if (message != null) {
      throw ValidationException(code: 'invalid_account_name', message: message);
    }
    return normalize(value);
  }
}
