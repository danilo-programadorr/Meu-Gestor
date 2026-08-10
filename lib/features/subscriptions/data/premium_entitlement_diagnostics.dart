import 'package:flutter/foundation.dart';
import 'package:meu_gestor_financeiro/core/environment/app_environment.dart';

typedef PremiumEntitlementDiagnosticWriter = void Function(String message);

final class PremiumEntitlementDiagnostics {
  PremiumEntitlementDiagnostics({
    required AppEnvironment environment,
    PremiumEntitlementDiagnosticWriter? writer,
  }) : _enabled = environment == AppEnvironment.development,
       _writer = writer ?? debugPrint;

  final bool _enabled;
  final PremiumEntitlementDiagnosticWriter _writer;

  void record({
    required String operation,
    required String stage,
    required String category,
    Object? error,
    String? firestoreCode,
  }) {
    if (!_enabled) return;
    _writer(
      'PremiumEntitlementDiagnostic('
      'operation=$operation, stage=$stage, category=$category, '
      'firestoreCode=${firestoreCode ?? 'none'}, '
      'exceptionType=${error?.runtimeType ?? 'none'})',
    );
  }
}
