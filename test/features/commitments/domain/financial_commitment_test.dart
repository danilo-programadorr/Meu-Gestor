import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/core/dates/sao_paulo_civil_date.dart';
import 'package:meu_gestor_financeiro/features/commitments/domain/financial_commitment.dart';
import 'package:meu_gestor_financeiro/features/commitments/domain/financial_commitment_failure.dart';

void main() {
  final SaoPauloCivilDate today = SaoPauloCivilDate(
    year: 2026,
    month: 8,
    day: 2,
  );

  group('rascunho e comandos', () {
    test('normaliza texto e preserva centavos e vencimento', () {
      final FinancialCommitmentDraft draft = FinancialCommitmentDraft(
        description: '  Conta   de luz ',
        categoryId: 'category-1',
        amountCents: 12345,
        dueDate: today,
        notes: ' observação ',
      ).normalized();

      expect(draft.description, 'Conta de luz');
      expect(draft.amountCents, 12345);
      expect(draft.dueDate, today);
      expect(draft.notes, 'observação');
    });

    test('rejeita valor, referência e texto inválidos', () {
      for (final int amount in <int>[0, -1, 10000000000]) {
        expect(
          () => FinancialCommitmentDraft(
            description: 'Conta válida',
            categoryId: 'category-1',
            amountCents: amount,
            dueDate: today,
            notes: '',
          ).normalized(),
          throwsA(isA<FinancialCommitmentFailure>()),
        );
      }
      expect(
        () => FinancialCommitmentDraft(
          description: 'A',
          categoryId: 'category/invalid',
          amountCents: 1,
          dueDate: today,
          notes: '',
        ).normalized(),
        throwsA(isA<FinancialCommitmentFailure>()),
      );
    });

    test('liquidação exige revisão, IDs e data não futura', () {
      expect(
        FinancialCommitmentSettlementCommand(
          transactionId: 'transaction-1',
          accountId: 'account-1',
          movementDate: today,
          expectedRevision: 1,
        ).normalized(today: today).movementDate,
        today,
      );
      expect(
        () => FinancialCommitmentSettlementCommand(
          transactionId: 'transaction-1',
          accountId: 'account-1',
          movementDate: SaoPauloCivilDate(year: 2026, month: 8, day: 3),
          expectedRevision: 1,
        ).normalized(today: today),
        throwsA(isA<FinancialCommitmentFailure>()),
      );
      expect(
        () => FinancialCommitmentSettlementCommand(
          transactionId: 'transaction-1',
          accountId: 'account-1',
          movementDate: today,
          expectedRevision: 0,
        ).normalized(today: today),
        throwsA(isA<FinancialCommitmentFailure>()),
      );
    });
  });

  group('Payable', () {
    test('atraso é derivado apenas para pendência anterior a hoje', () {
      final Payable overdue = _payable(
        dueDate: SaoPauloCivilDate(year: 2026, month: 8, day: 1),
      );
      final Payable dueToday = _payable(dueDate: today);

      Payable.validate(overdue, today: today);
      expect(overdue.isOverdue(today), isTrue);
      expect(dueToday.isOverdue(today), isFalse);
      expect(overdue.contributesToRealBalance, isFalse);
    });

    test('pago exige movimento e lançamento vinculados', () {
      final Payable paid = _payable(
        status: PayableStatus.paid,
        paidDate: today,
        linkedTransactionId: 'transaction-1',
      );

      expect(() => Payable.validate(paid, today: today), returnsNormally);
      expect(
        () => Payable.validate(
          _payable(status: PayableStatus.paid, paidDate: today),
          today: today,
        ),
        throwsA(isA<FinancialCommitmentFailure>()),
      );
    });

    test('cancelled preserva auditoria sem lançamento', () {
      final DateTime cancelledAt = DateTime.utc(2026, 8, 2, 12);
      final Payable cancelled = _payable(
        status: PayableStatus.cancelled,
        cancelledAt: cancelledAt,
        updatedAt: cancelledAt,
      );

      expect(() => Payable.validate(cancelled, today: today), returnsNormally);
      expect(cancelled.isOverdue(today), isFalse);
    });

    test('voided preserva liquidação e exige auditoria de anulação', () {
      final DateTime voidedAt = DateTime.utc(2026, 8, 2, 12);
      final Payable voided = _payable(
        status: PayableStatus.voided,
        paidDate: today,
        linkedTransactionId: 'transaction-1',
        voidedAt: voidedAt,
        updatedAt: voidedAt,
      );

      expect(() => Payable.validate(voided, today: today), returnsNormally);
      expect(voided.isVoided, isTrue);
      expect(voided.isCancelled, isFalse);
    });
  });

  group('Receivable', () {
    test('recebido exige movimento e lançamento vinculados', () {
      final Receivable received = _receivable(
        status: ReceivableStatus.received,
        receivedDate: today,
        linkedTransactionId: 'transaction-2',
      );

      expect(
        () => Receivable.validate(received, today: today),
        returnsNormally,
      );
      expect(received.isSettled, isTrue);
      expect(received.contributesToRealBalance, isFalse);
    });

    test('cancelled e voided mantêm históricos distintos', () {
      final DateTime auditAt = DateTime.utc(2026, 8, 2, 12);
      final Receivable cancelled = _receivable(
        status: ReceivableStatus.cancelled,
        cancelledAt: auditAt,
        updatedAt: auditAt,
      );
      final Receivable voided = _receivable(
        status: ReceivableStatus.voided,
        receivedDate: today,
        linkedTransactionId: 'transaction-2',
        voidedAt: auditAt,
        updatedAt: auditAt,
      );

      expect(
        () => Receivable.validate(cancelled, today: today),
        returnsNormally,
      );
      expect(() => Receivable.validate(voided, today: today), returnsNormally);
      expect(cancelled.linkedTransactionId, isNull);
      expect(voided.linkedTransactionId, 'transaction-2');
    });

    test('rejeita movimento futuro e combinação voided incompleta', () {
      expect(
        () => Receivable.validate(
          _receivable(
            status: ReceivableStatus.received,
            receivedDate: SaoPauloCivilDate(year: 2026, month: 8, day: 3),
            linkedTransactionId: 'transaction-2',
          ),
          today: today,
        ),
        throwsA(isA<FinancialCommitmentFailure>()),
      );
      expect(
        () => Receivable.validate(
          _receivable(
            status: ReceivableStatus.voided,
            receivedDate: today,
            linkedTransactionId: 'transaction-2',
          ),
          today: today,
        ),
        throwsA(isA<FinancialCommitmentFailure>()),
      );
    });
  });
}

Payable _payable({
  SaoPauloCivilDate? dueDate,
  PayableStatus status = PayableStatus.pending,
  SaoPauloCivilDate? paidDate,
  String? linkedTransactionId,
  DateTime? cancelledAt,
  DateTime? voidedAt,
  DateTime? updatedAt,
}) {
  final DateTime createdAt = DateTime.utc(2026, 8, 1, 12);
  return Payable(
    id: 'payable-1',
    ownerId: 'owner-1',
    description: 'Conta de luz',
    categoryId: 'category-1',
    amountCents: 12345,
    dueDate: dueDate ?? SaoPauloCivilDate(year: 2026, month: 8, day: 2),
    notes: '',
    status: status,
    paidDate: paidDate,
    settlementAccountId: linkedTransactionId == null ? null : 'account-1',
    linkedTransactionId: linkedTransactionId,
    cancelledAt: cancelledAt,
    voidedAt: voidedAt,
    revision: 1,
    createdAt: createdAt,
    updatedAt: updatedAt ?? createdAt,
    schemaVersion: FinancialCommitment.currentSchemaVersion,
  );
}

Receivable _receivable({
  ReceivableStatus status = ReceivableStatus.pending,
  SaoPauloCivilDate? receivedDate,
  String? linkedTransactionId,
  DateTime? cancelledAt,
  DateTime? voidedAt,
  DateTime? updatedAt,
}) {
  final DateTime createdAt = DateTime.utc(2026, 8, 1, 12);
  return Receivable(
    id: 'receivable-1',
    ownerId: 'owner-1',
    description: 'Serviço prestado',
    categoryId: 'category-2',
    amountCents: 50000,
    dueDate: SaoPauloCivilDate(year: 2026, month: 8, day: 2),
    notes: '',
    status: status,
    receivedDate: receivedDate,
    settlementAccountId: linkedTransactionId == null ? null : 'account-1',
    linkedTransactionId: linkedTransactionId,
    cancelledAt: cancelledAt,
    voidedAt: voidedAt,
    revision: 1,
    createdAt: createdAt,
    updatedAt: updatedAt ?? createdAt,
    schemaVersion: FinancialCommitment.currentSchemaVersion,
  );
}
