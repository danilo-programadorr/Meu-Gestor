sealed class AppException implements Exception {
  const AppException({required this.code, required this.message});

  final String code;
  final String message;

  @override
  String toString() => '$runtimeType($code): $message';
}

final class ConfigurationException extends AppException {
  const ConfigurationException({required super.code, required super.message});
}

class ValidationException extends AppException {
  const ValidationException({required super.code, required super.message});
}

final class InvalidMoneyException extends ValidationException {
  const InvalidMoneyException({required super.code, required super.message});
}

final class InvalidCurrencyException extends ValidationException {
  const InvalidCurrencyException({required super.code, required super.message});
}

final class CurrencyMismatchException extends ValidationException {
  const CurrencyMismatchException({
    required super.code,
    required super.message,
  });
}
