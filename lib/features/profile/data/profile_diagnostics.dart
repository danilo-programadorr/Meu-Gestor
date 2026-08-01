import 'package:flutter/foundation.dart';
import 'package:meu_gestor_financeiro/core/environment/app_environment.dart';

typedef ProfileDiagnosticWriter = void Function(String message);

final class ProfileDiagnostics {
  ProfileDiagnostics({
    required AppEnvironment environment,
    ProfileDiagnosticWriter? writer,
  }) : _enabled = environment == AppEnvironment.development,
       _writer = writer ?? debugPrint;

  final bool _enabled;
  final ProfileDiagnosticWriter _writer;

  void recordGateEvent({
    required String stage,
    required Duration duration,
    required String finalState,
    Object? error,
    String? errorCode,
  }) {
    if (!_enabled) {
      return;
    }
    _writer(
      'ProfileGateDiagnostic('
      'stage=$stage, '
      'durationMs=${duration.inMilliseconds}, '
      'exceptionType=${error?.runtimeType ?? 'none'}, '
      'errorCode=${errorCode ?? 'none'}, '
      'finalState=$finalState)',
    );
  }

  void record({
    required String operation,
    required String category,
    required String stage,
    required Object error,
    String? firestoreCode,
  }) {
    if (!_enabled) {
      return;
    }
    _writer(
      'ProfileDiagnostic('
      'operation=$operation, '
      'category=$category, '
      'stage=$stage, '
      'exceptionType=${error.runtimeType}, '
      'firestoreCode=${firestoreCode ?? 'none'})',
    );
  }
}
