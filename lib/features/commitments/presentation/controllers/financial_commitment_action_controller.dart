import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_gestor_financeiro/core/dates/sao_paulo_civil_date.dart';
import 'package:meu_gestor_financeiro/features/commitments/domain/financial_commitment.dart';
import 'package:meu_gestor_financeiro/features/commitments/domain/financial_commitment_failure.dart';
import 'package:meu_gestor_financeiro/features/commitments/domain/financial_commitment_repository.dart';
import 'package:meu_gestor_financeiro/features/commitments/presentation/controllers/financial_commitments_controller.dart';
import 'package:meu_gestor_financeiro/features/commitments/presentation/providers/financial_commitment_providers.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_transaction.dart';
import 'package:meu_gestor_financeiro/features/transactions/presentation/controllers/financial_transactions_controller.dart';

enum FinancialCommitmentActionStatus { idle, loading, success, failure }

final class FinancialCommitmentActionState {
  const FinancialCommitmentActionState({
    required this.status,
    this.message,
    this.commitment,
    this.operationUncertain = false,
  });

  const FinancialCommitmentActionState.idle()
    : this(status: FinancialCommitmentActionStatus.idle);

  const FinancialCommitmentActionState.loading()
    : this(status: FinancialCommitmentActionStatus.loading);

  const FinancialCommitmentActionState.success({
    required String message,
    required FinancialCommitment commitment,
  }) : this(
         status: FinancialCommitmentActionStatus.success,
         message: message,
         commitment: commitment,
       );

  const FinancialCommitmentActionState.failure({
    required String message,
    required bool operationUncertain,
  }) : this(
         status: FinancialCommitmentActionStatus.failure,
         message: message,
         operationUncertain: operationUncertain,
       );

  final FinancialCommitmentActionStatus status;
  final String? message;
  final FinancialCommitment? commitment;
  final bool operationUncertain;

  bool get isLoading => status == FinancialCommitmentActionStatus.loading;
}

final NotifierProvider<
  FinancialCommitmentActionController,
  FinancialCommitmentActionState
>
financialCommitmentActionControllerProvider =
    NotifierProvider.autoDispose<
      FinancialCommitmentActionController,
      FinancialCommitmentActionState
    >(FinancialCommitmentActionController.new);

final class FinancialCommitmentActionController
    extends Notifier<FinancialCommitmentActionState> {
  String? _pendingPayableId;
  String? _pendingReceivableId;
  final Map<String, String> _pendingSettlementIds = <String, String>{};
  bool _isDisposed = false;

  FinancialCommitmentRepository get _repository =>
      ref.read(financialCommitmentRepositoryProvider);

  @override
  FinancialCommitmentActionState build() {
    _isDisposed = false;
    ref.onDispose(() {
      _isDisposed = true;
      _pendingPayableId = null;
      _pendingReceivableId = null;
      _pendingSettlementIds.clear();
    });
    return const FinancialCommitmentActionState.idle();
  }

  Future<bool> createPayable(FinancialCommitmentDraft draft) async {
    if (state.isLoading) {
      return false;
    }
    final String ownerId;
    try {
      ownerId = requireFinancialCommitmentOwner(ref);
      draft.normalized();
    } on FinancialCommitmentFailure catch (failure) {
      _setValidationFailure(failure);
      return false;
    }
    _pendingPayableId ??= _repository.newPayableId(ownerId: ownerId);
    final String attemptId = _pendingPayableId!;
    return _run(
      ownerId: ownerId,
      successMessage: 'Conta a pagar criada e confirmada pelo servidor.',
      operation: () async => _ActionResult(
        commitment: await _repository.createPayable(
          ownerId: ownerId,
          payableId: attemptId,
          draft: draft,
        ),
      ),
      onSuccess: () => _pendingPayableId = null,
    );
  }

  Future<bool> createReceivable(FinancialCommitmentDraft draft) async {
    if (state.isLoading) {
      return false;
    }
    final String ownerId;
    try {
      ownerId = requireFinancialCommitmentOwner(ref);
      draft.normalized();
    } on FinancialCommitmentFailure catch (failure) {
      _setValidationFailure(failure);
      return false;
    }
    _pendingReceivableId ??= _repository.newReceivableId(ownerId: ownerId);
    final String attemptId = _pendingReceivableId!;
    return _run(
      ownerId: ownerId,
      successMessage: 'Conta a receber criada e confirmada pelo servidor.',
      operation: () async => _ActionResult(
        commitment: await _repository.createReceivable(
          ownerId: ownerId,
          receivableId: attemptId,
          draft: draft,
        ),
      ),
      onSuccess: () => _pendingReceivableId = null,
    );
  }

  Future<bool> updatePending({
    required FinancialCommitment commitment,
    required FinancialCommitmentUpdate update,
  }) => _runForCommitment(
    commitment: commitment,
    successMessage: 'Compromisso atualizado e confirmado pelo servidor.',
    operation: (String ownerId) async => _ActionResult(
      commitment: commitment is Payable
          ? await _repository.updatePendingPayable(
              ownerId: ownerId,
              payableId: commitment.id,
              update: update,
            )
          : await _repository.updatePendingReceivable(
              ownerId: ownerId,
              receivableId: commitment.id,
              update: update,
            ),
    ),
  );

  Future<bool> settle({
    required FinancialCommitment commitment,
    required String accountId,
    required SaoPauloCivilDate movementDate,
  }) async {
    if (state.isLoading) {
      return false;
    }
    final String ownerId = requireFinancialCommitmentOwner(ref);
    final String key = '${commitment.kind.name}:${commitment.id}';
    _pendingSettlementIds[key] ??= _repository.newLinkedTransactionId(
      ownerId: ownerId,
    );
    final FinancialCommitmentSettlementCommand command =
        FinancialCommitmentSettlementCommand(
          transactionId: _pendingSettlementIds[key]!,
          accountId: accountId,
          movementDate: movementDate,
          expectedRevision: commitment.revision,
        );
    return _run(
      ownerId: ownerId,
      successMessage: commitment is Payable
          ? 'Pagamento confirmado. O lançamento já participa do saldo.'
          : 'Recebimento confirmado. O lançamento já participa do saldo.',
      operation: () async {
        if (commitment is Payable) {
          final FinancialCommitmentMutationResult<Payable> result =
              await _repository.pay(
                ownerId: ownerId,
                payableId: commitment.id,
                command: command,
              );
          return _ActionResult(
            commitment: result.commitment,
            linkedTransaction: result.linkedTransaction,
          );
        }
        final FinancialCommitmentMutationResult<Receivable> result =
            await _repository.receive(
              ownerId: ownerId,
              receivableId: commitment.id,
              command: command,
            );
        return _ActionResult(
          commitment: result.commitment,
          linkedTransaction: result.linkedTransaction,
        );
      },
      onSuccess: () => _pendingSettlementIds.remove(key),
    );
  }

  Future<bool> cancelPending(
    FinancialCommitment commitment,
  ) => _runForCommitment(
    commitment: commitment,
    successMessage:
        'Compromisso cancelado. O histórico foi preservado e o saldo não mudou.',
    operation: (String ownerId) async => _ActionResult(
      commitment: commitment is Payable
          ? await _repository.cancelPendingPayable(
              ownerId: ownerId,
              payableId: commitment.id,
              expectedRevision: commitment.revision,
            )
          : await _repository.cancelPendingReceivable(
              ownerId: ownerId,
              receivableId: commitment.id,
              expectedRevision: commitment.revision,
            ),
    ),
  );

  Future<bool> voidSettlement(
    FinancialCommitment commitment,
  ) => _runForCommitment(
    commitment: commitment,
    successMessage:
        'Liquidação anulada. O lançamento vinculado foi invalidado e o saldo recalculado.',
    operation: (String ownerId) async {
      if (commitment is Payable) {
        final FinancialCommitmentMutationResult<Payable> result =
            await _repository.voidPaidPayable(
              ownerId: ownerId,
              payableId: commitment.id,
              expectedRevision: commitment.revision,
            );
        return _ActionResult(
          commitment: result.commitment,
          linkedTransaction: result.linkedTransaction,
        );
      }
      final FinancialCommitmentMutationResult<Receivable> result =
          await _repository.voidReceivedReceivable(
            ownerId: ownerId,
            receivableId: commitment.id,
            expectedRevision: commitment.revision,
          );
      return _ActionResult(
        commitment: result.commitment,
        linkedTransaction: result.linkedTransaction,
      );
    },
  );

  Future<bool> _runForCommitment({
    required FinancialCommitment commitment,
    required String successMessage,
    required Future<_ActionResult> Function(String ownerId) operation,
  }) {
    if (state.isLoading) {
      return Future<bool>.value(false);
    }
    final String ownerId = requireFinancialCommitmentOwner(ref);
    return _run(
      ownerId: ownerId,
      successMessage: successMessage,
      operation: () => operation(ownerId),
    );
  }

  Future<bool> _run({
    required String ownerId,
    required String successMessage,
    required Future<_ActionResult> Function() operation,
    void Function()? onSuccess,
  }) async {
    if (state.isLoading) {
      return false;
    }
    state = const FinancialCommitmentActionState.loading();
    try {
      final _ActionResult result = await operation();
      if (_isDisposed || requireFinancialCommitmentOwner(ref) != ownerId) {
        return false;
      }
      onSuccess?.call();
      state = FinancialCommitmentActionState.success(
        message: successMessage,
        commitment: result.commitment,
      );
      _acceptConfirmed(result);
      return true;
    } on FinancialCommitmentFailure catch (failure) {
      if (_isDisposed) {
        return false;
      }
      final bool uncertain = _isUncertain(failure);
      state = FinancialCommitmentActionState.failure(
        message: uncertain
            ? 'Não foi possível confirmar a operação. Tente novamente; a mesma tentativa será verificada sem duplicar registros.'
            : failure.safeMessage,
        operationUncertain: uncertain,
      );
      return false;
    } on Object {
      if (_isDisposed) {
        return false;
      }
      state = const FinancialCommitmentActionState.failure(
        message: 'Não foi possível concluir a operação. Tente novamente.',
        operationUncertain: true,
      );
      return false;
    }
  }

  void _acceptConfirmed(_ActionResult result) {
    final FinancialCommitment commitment = result.commitment;
    if (commitment is Payable) {
      ref.read(payablesControllerProvider.notifier).acceptConfirmed(commitment);
      ref.invalidate(payableDetailsProvider(commitment.id));
    } else if (commitment is Receivable) {
      ref
          .read(receivablesControllerProvider.notifier)
          .acceptConfirmed(commitment);
      ref.invalidate(receivableDetailsProvider(commitment.id));
    }
    final FinancialTransaction? transaction = result.linkedTransaction;
    if (transaction != null) {
      ref
          .read(financialTransactionsControllerProvider.notifier)
          .acceptConfirmed(transaction);
      ref.invalidate(financialTransactionDetailsProvider(transaction.id));
      ref.invalidate(financialSummaryProvider);
      ref.invalidate(financialWorkspaceProvider);
    }
  }

  void _setValidationFailure(FinancialCommitmentFailure failure) {
    state = FinancialCommitmentActionState.failure(
      message: failure.safeMessage,
      operationUncertain: false,
    );
  }

  static bool _isUncertain(FinancialCommitmentFailure failure) =>
      switch (failure.kind) {
        FinancialCommitmentFailureKind.unavailable ||
        FinancialCommitmentFailureKind.timeout ||
        FinancialCommitmentFailureKind.conflict => true,
        _ => false,
      };
}

final class _ActionResult {
  const _ActionResult({required this.commitment, this.linkedTransaction});

  final FinancialCommitment commitment;
  final FinancialTransaction? linkedTransaction;
}
