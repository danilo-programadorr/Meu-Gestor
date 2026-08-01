import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/core/environment/app_environment.dart';
import 'package:meu_gestor_financeiro/features/profile/data/profile_diagnostics.dart';

void main() {
  test('development registra somente diagnóstico sanitizado', () {
    final List<String> messages = <String>[];
    final ProfileDiagnostics diagnostics = ProfileDiagnostics(
      environment: AppEnvironment.development,
      writer: messages.add,
    );

    diagnostics.record(
      operation: 'read_profile',
      category: 'permissionDenied',
      stage: 'server_read',
      error: StateError('conteúdo que não pode entrar no log'),
      firestoreCode: 'permission-denied',
    );

    expect(messages, hasLength(1));
    expect(messages.single, contains('operation=read_profile'));
    expect(messages.single, contains('category=permissionDenied'));
    expect(messages.single, contains('stage=server_read'));
    expect(messages.single, contains('firestoreCode=permission-denied'));
    expect(messages.single, isNot(contains('conteúdo que não pode')));
  });

  test('production não registra diagnóstico de perfil', () {
    final List<String> messages = <String>[];
    final ProfileDiagnostics diagnostics = ProfileDiagnostics(
      environment: AppEnvironment.production,
      writer: messages.add,
    );

    diagnostics.record(
      operation: 'update_profile',
      category: 'unknown',
      stage: 'transaction',
      error: StateError('erro'),
    );

    expect(messages, isEmpty);
  });

  test('portão registra somente campos técnicos autorizados', () {
    final List<String> messages = <String>[];
    final ProfileDiagnostics diagnostics = ProfileDiagnostics(
      environment: AppEnvironment.development,
      writer: messages.add,
    );

    diagnostics.recordGateEvent(
      stage: 'profile-read-error',
      duration: const Duration(milliseconds: 125),
      finalState: 'recoverableError',
      error: StateError('dado pessoal proibido'),
      errorCode: 'PROFILE_PERMISSION_DENIED',
    );

    expect(messages, hasLength(1));
    expect(messages.single, contains('stage=profile-read-error'));
    expect(messages.single, contains('durationMs=125'));
    expect(messages.single, contains('exceptionType=StateError'));
    expect(messages.single, contains('PROFILE_PERMISSION_DENIED'));
    expect(messages.single, contains('finalState=recoverableError'));
    expect(messages.single, isNot(contains('dado pessoal proibido')));
  });
}
