import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/core/environment/app_environment.dart';
import 'package:meu_gestor_financeiro/features/investments/data/firebase_investment_repository.dart';
import 'package:meu_gestor_financeiro/features/investments/data/investment_diagnostics.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_failure.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_income_event.dart';
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

    test('decodifica proventos em coleção própria sem afetar operações', () {
      final Timestamp createdAt = Timestamp.fromDate(
        DateTime.utc(2026, 7, 1, 12),
      );
      final Timestamp expectedAt = Timestamp.fromDate(
        DateTime.utc(2026, 8, 10, 3),
      );
      final InvestmentWorkspaceReadResult result =
          FirebaseInvestmentRepository.decodeWorkspace(
            ownerId: 'owner',
            portfolioDocuments: const <InvestmentDocumentData>[],
            assetDocuments: const <InvestmentDocumentData>[],
            operationDocuments: const <InvestmentDocumentData>[],
            incomeDocuments: <InvestmentDocumentData>[
              InvestmentDocumentData(
                id: 'income-1',
                data: _income(createdAt, expectedAt),
              ),
            ],
            isFromCache: false,
            hasPendingWrites: false,
            now: DateTime.utc(2026, 8, 10, 12),
          );

      expect(result.operations, isEmpty);
      expect(result.incomeEvents, hasLength(1));
      expect(result.incomeEvents.single.id, 'income-1');
      expect(
        result.incomeEvents.single.status,
        InvestmentIncomeStatus.expected,
      );
      expect(result.incomeEvents.single.netAmountCents, 8500);
      expect(result.isFromServer, isTrue);
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

Map<String, dynamic> _income(Timestamp createdAt, Timestamp expectedAt) =>
    <String, dynamic>{
      'ownerId': 'owner',
      'portfolioId': 'portfolio-1',
      'assetId': 'portfolio-1__PETR4',
      'incomeType': 'dividend',
      'status': 'expected',
      'inputMode': 'total',
      'exDate': null,
      'expectedPaymentDate': expectedAt,
      'receivedDate': null,
      'eligibleQuantityScaled': null,
      'unitAmountScaled': null,
      'grossAmountCents': 10000,
      'withholdingTaxCents': 1500,
      'netAmountCents': 8500,
      'notes': '',
      'originType': 'manual',
      'externalId': null,
      'cancelledAt': null,
      'voidedAt': null,
      'mutationId': 'mutation-income-1',
      'createdAt': createdAt,
      'updatedAt': createdAt,
      'schemaVersion': 1,
      'revision': 1,
    };
