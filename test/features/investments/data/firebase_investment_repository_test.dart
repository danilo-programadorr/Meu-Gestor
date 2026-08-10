import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/core/environment/app_environment.dart';
import 'package:meu_gestor_financeiro/features/investments/data/firebase_investment_repository.dart';
import 'package:meu_gestor_financeiro/features/investments/data/investment_diagnostics.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_failure.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_repository.dart';

void main() {
  group('FirebaseInvestmentRepository', () {
    test('mapeia timeout, concorrência e permissão para falhas tipadas', () {
      expect(
        FirebaseInvestmentRepository.mapFailure(TimeoutException('late')).kind,
        InvestmentFailureKind.timeout,
      );
      expect(
        FirebaseInvestmentRepository.mapFailure(
          FirebaseException(plugin: 'cloud_firestore', code: 'aborted'),
        ).kind,
        InvestmentFailureKind.aborted,
      );
      expect(
        FirebaseInvestmentRepository.mapFailure(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          ),
        ).kind,
        InvestmentFailureKind.permissionDenied,
      );
    });

    test('preserva falha de domínio e neutraliza falha desconhecida', () {
      const InvestmentFailure original = InvestmentFailure(
        kind: InvestmentFailureKind.validation,
        safeMessage: 'Revise o valor.',
      );
      expect(FirebaseInvestmentRepository.mapFailure(original), same(original));
      expect(
        FirebaseInvestmentRepository.mapFailure(StateError('sensitive')).kind,
        InvestmentFailureKind.unknown,
      );
    });

    test(
      'decodifica workspace estrito, ordenado e com metadados explícitos',
      () {
        final Timestamp time = Timestamp.fromDate(DateTime.utc(2026, 8, 1, 3));
        final InvestmentWorkspaceReadResult result =
            FirebaseInvestmentRepository.decodeWorkspace(
              ownerId: 'owner',
              portfolioDocuments: <InvestmentDocumentData>[
                InvestmentDocumentData(
                  id: 'z',
                  data: _portfolio(time, name: 'Zeta'),
                ),
                InvestmentDocumentData(
                  id: 'a',
                  data: _portfolio(time, name: 'Alfa'),
                ),
              ],
              assetDocuments: const <InvestmentDocumentData>[],
              operationDocuments: const <InvestmentDocumentData>[],
              isFromCache: false,
              hasPendingWrites: false,
              now: DateTime.utc(2026, 8, 2),
            );
        expect(result.portfolios.map((value) => value.name), <String>[
          'Alfa',
          'Zeta',
        ]);
        expect(result.isFromServer, isTrue);
        expect(result.hasPendingWrites, isFalse);
      },
    );

    test('rejeita documento incompatível sem aceitar campos parciais', () {
      final Timestamp time = Timestamp.fromDate(DateTime.utc(2026, 8, 1, 3));
      expect(
        () => FirebaseInvestmentRepository.decodeWorkspace(
          ownerId: 'owner',
          portfolioDocuments: <InvestmentDocumentData>[
            InvestmentDocumentData(
              id: 'a',
              data: _portfolio(time)..remove('revision'),
            ),
          ],
          assetDocuments: const <InvestmentDocumentData>[],
          operationDocuments: const <InvestmentDocumentData>[],
          isFromCache: false,
          hasPendingWrites: false,
          now: DateTime.utc(2026, 8, 2),
        ),
        throwsA(isA<InvestmentFailure>()),
      );
    });
  });

  test('diagnóstico não registra mensagem, e-mail ou valor da exceção', () {
    final List<String> messages = <String>[];
    final InvestmentDiagnostics diagnostics = InvestmentDiagnostics(
      environment: AppEnvironment.development,
      writer: messages.add,
    );
    diagnostics.record(
      operation: 'read_workspace',
      stage: 'server_read',
      category: 'unknown',
      error: Exception('pessoa@exemplo.com saldo=999'),
    );
    expect(messages, hasLength(1));
    expect(messages.single, contains('exceptionType=_Exception'));
    expect(messages.single, isNot(contains('pessoa@exemplo.com')));
    expect(messages.single, isNot(contains('999')));
  });
}

Map<String, dynamic> _portfolio(Timestamp time, {String name = 'Carteira'}) =>
    <String, dynamic>{
      'ownerId': 'owner',
      'name': name,
      'description': '',
      'isArchived': false,
      'archivedAt': null,
      'createdAt': time,
      'updatedAt': time,
      'schemaVersion': 1,
      'revision': 1,
    };
