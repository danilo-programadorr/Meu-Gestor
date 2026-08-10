import 'package:flutter/foundation.dart';
import 'package:meu_gestor_financeiro/core/environment/app_environment.dart';

final class InvestmentDiagnostics {
  InvestmentDiagnostics({
    required AppEnvironment environment,
    void Function(String message)? writer,
  }) : _environment = environment,
       _writer = writer ?? debugPrint;

  final AppEnvironment _environment;
  final void Function(String message) _writer;

  void record({
    required String operation,
    required String stage,
    required String category,
    required Object error,
    String? firestoreCode,
  }) {
    if (_environment != AppEnvironment.development) {
      return;
    }
    _writer(
      '[investments] operation=$operation stage=$stage category=$category '
      'exceptionType=${error.runtimeType} '
      'firestoreCode=${firestoreCode ?? 'not_available'}',
    );
  }
}
