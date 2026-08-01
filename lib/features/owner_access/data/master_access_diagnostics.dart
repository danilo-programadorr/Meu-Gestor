import 'package:flutter/foundation.dart';
import 'package:meu_gestor_financeiro/core/environment/app_environment.dart';

typedef MasterAccessDiagnosticWriter = void Function(String message);

final class MasterAccessDiagnostics {
  MasterAccessDiagnostics({
    required AppEnvironment environment,
    MasterAccessDiagnosticWriter? writer,
  }) : _enabled = environment == AppEnvironment.development,
       _writer = writer ?? debugPrint;

  final bool _enabled;
  final MasterAccessDiagnosticWriter _writer;

  void record({
    required String operation,
    required String stage,
    required Duration duration,
    required String finalState,
    Object? error,
    String? firestoreCode,
  }) {
    if (!_enabled) {
      return;
    }
    _writer(
      'MasterAccessDiagnostic('
      'operation=$operation, '
      'stage=$stage, '
      'durationMs=${duration.inMilliseconds}, '
      'firestoreCode=${firestoreCode ?? 'none'}, '
      'exceptionType=${error?.runtimeType ?? 'none'}, '
      'finalState=$finalState)',
    );
  }
}
