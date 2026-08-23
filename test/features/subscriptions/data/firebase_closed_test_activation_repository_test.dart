import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/data/firebase_closed_test_activation_repository.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/closed_test_activation_repository.dart';

void main() {
  test(
    'envia payload estritamente vazio e aceita confirmação estrita',
    () async {
      Map<String, Object?>? received;
      final FirebaseClosedTestActivationRepository repository =
          FirebaseClosedTestActivationRepository.withInvoker(
            invoker: (Map<String, Object?> payload) async {
              received = payload;
              return <String, Object?>{
                'status': 'active',
                'revision': 1,
                'requiresServerRefresh': true,
              };
            },
          );

      await repository.activateCurrentUser();

      expect(received, isEmpty);
    },
  );

  test('rejeita resposta com entitlement ainda não confirmado', () async {
    final FirebaseClosedTestActivationRepository repository =
        FirebaseClosedTestActivationRepository.withInvoker(
          invoker: (_) async => <String, Object?>{
            'status': 'active',
            'revision': 1,
            'requiresServerRefresh': false,
          },
        );

    await expectLater(
      repository.activateCurrentUser(),
      throwsA(
        isA<ClosedTestActivationFailure>().having(
          (ClosedTestActivationFailure failure) => failure.kind,
          'kind',
          ClosedTestActivationFailureKind.invalidResponse,
        ),
      ),
    );
  });

  test('mapeia usuário não autorizado sem revelar diretório privado', () async {
    final FirebaseClosedTestActivationRepository repository =
        FirebaseClosedTestActivationRepository.withInvoker(
          invoker: (_) async => throw FirebaseFunctionsException(
            code: 'permission-denied',
            message: 'Synthetic denied.',
            details: null,
          ),
        );

    await expectLater(
      repository.activateCurrentUser(),
      throwsA(
        isA<ClosedTestActivationFailure>().having(
          (ClosedTestActivationFailure failure) => failure.kind,
          'kind',
          ClosedTestActivationFailureKind.notAuthorized,
        ),
      ),
    );
  });

  test('falha fechada quando App Check é rejeitado', () async {
    final FirebaseClosedTestActivationRepository repository =
        FirebaseClosedTestActivationRepository.withInvoker(
          invoker: (_) async => throw FirebaseFunctionsException(
            code: 'failed-precondition',
            message: 'Synthetic App Check failure.',
            details: null,
          ),
        );

    await expectLater(
      repository.activateCurrentUser(),
      throwsA(
        isA<ClosedTestActivationFailure>().having(
          (ClosedTestActivationFailure failure) => failure.kind,
          'kind',
          ClosedTestActivationFailureKind.appCheckRejected,
        ),
      ),
    );
  });

  test('timeout local nunca é tratado como ativação concluída', () async {
    final Completer<Object?> response = Completer<Object?>();
    final FirebaseClosedTestActivationRepository repository =
        FirebaseClosedTestActivationRepository.withInvoker(
          invoker: (_) => response.future,
          timeout: const Duration(milliseconds: 10),
        );

    await expectLater(
      repository.activateCurrentUser(),
      throwsA(
        isA<ClosedTestActivationFailure>().having(
          (ClosedTestActivationFailure failure) => failure.kind,
          'kind',
          ClosedTestActivationFailureKind.timeout,
        ),
      ),
    );
  });
}
