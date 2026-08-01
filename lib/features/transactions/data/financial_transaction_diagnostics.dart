import 'package:flutter/foundation.dart';
import 'package:meu_gestor_financeiro/core/environment/app_environment.dart';

final class FinancialTransactionDiagnostics {
  FinancialTransactionDiagnostics({
    required AppEnvironment environment,
    void Function(String message)? writer,
  }) : _environment = environment,
       _writer = writer ?? debugPrint;

  final AppEnvironment _environment;
  final void Function(String message) _writer;

  void record({
    required String operation,
    required String stage,
    required Duration duration,
    required String category,
    required String finalState,
    required Object error,
    String? firestoreCode,
  }) {
    if (_environment != AppEnvironment.development) {
      return;
    }
    _writer(
      '[transactions] operation=$operation stage=$stage '
      'durationMs=${duration.inMilliseconds} category=$category '
      'exceptionType=${error.runtimeType} '
      'firestoreCode=${firestoreCode ?? 'not_available'} '
      'finalState=$finalState',
    );
  }
}
