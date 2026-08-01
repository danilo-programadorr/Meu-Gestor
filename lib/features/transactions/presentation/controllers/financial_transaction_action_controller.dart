import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_gestor_financeiro/features/transactions/data/financial_transaction_providers.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_transaction.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_transaction_failure.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_transaction_repository.dart';
import 'package:meu_gestor_financeiro/features/transactions/presentation/controllers/financial_transactions_controller.dart';

enum FinancialTransactionActionStatus { idle, loading, success, failure }

final class FinancialTransactionActionState {
  const FinancialTransactionActionState({
    required this.status,
    this.message,
    this.transaction,
    this.operationUncertain = false,
  });

  const FinancialTransactionActionState.idle()
    : this(status: FinancialTransactionActionStatus.idle);

  const FinancialTransactionActionState.loading()
    : this(status: FinancialTransactionActionStatus.loading);

  const FinancialTransactionActionState.success({
    required String message,
    required FinancialTransaction transaction,
  }) : this(
         status: FinancialTransactionActionStatus.success,
         message: message,
         transaction: transaction,
       );

  const FinancialTransactionActionState.failure({
    required String message,
    bool operationUncertain = false,
  }) : this(
         status: FinancialTransactionActionStatus.failure,
         message: message,
         operationUncertain: operationUncertain,
       );

  final FinancialTransactionActionStatus status;
  final String? message;
  final FinancialTransaction? transaction;
  final bool operationUncertain;

  bool get isLoading => status == FinancialTransactionActionStatus.loading;
}

final NotifierProvider<
  FinancialTransactionActionController,
  FinancialTransactionActionState
>
financialTransactionActionControllerProvider =
    NotifierProvider.autoDispose<
      FinancialTransactionActionController,
      FinancialTransactionActionState
    >(FinancialTransactionActionController.new);

final class FinancialTransactionActionController
    extends Notifier<FinancialTransactionActionState> {
  String? _pendingCreationId;
  bool _isDisposed = false;

  FinancialTransactionRepository get _repository =>
      ref.read(financialTransactionRepositoryProvider);

  @override
  FinancialTransactionActionState build() {
    _isDisposed = false;
    ref.onDispose(() {
      _pendingCreationId = null;
      _isDisposed = true;
    });
    return const FinancialTransactionActionState.idle();
  }

  Future<void> create(FinancialTransactionDraft draft) async {
    if (state.isLoading) {
      return;
    }
    final String ownerId;
    final FinancialTransactionDraft normalized;
    try {
      ownerId = requireFinancialTransactionOwner(ref);
      normalized = draft.normalized(now: ref.read(financialClockProvider)());
    } on FinancialTransactionFailure catch (failure) {
      state = FinancialTransactionActionState.failure(
        message: failure.safeMessage,
      );
      return;
    }
    _pendingCreationId ??= _repository.newTransactionId(ownerId: ownerId);
    state = const FinancialTransactionActionState.loading();
    try {
      final FinancialTransaction transaction = await _repository.create(
        ownerId: ownerId,
        transactionId: _pendingCreationId!,
        draft: normalized,
      );
      if (_isDisposed || requireFinancialTransactionOwner(ref) != ownerId) {
        return;
      }
      _pendingCreationId = null;
      state = FinancialTransactionActionState.success(
        message: 'Lançamento registrado e confirmado pelo servidor.',
        transaction: transaction,
      );
      ref
          .read(financialTransactionsControllerProvider.notifier)
          .acceptConfirmed(transaction);
      ref.invalidate(financialTransactionDetailsProvider(transaction.id));
    } on FinancialTransactionFailure catch (failure) {
      state = FinancialTransactionActionState.failure(
        message: failure.isUncertain
            ? 'Não foi possível confirmar o lançamento. Tente novamente; a mesma tentativa será verificada sem duplicar o registro.'
            : failure.safeMessage,
        operationUncertain: failure.isUncertain,
      );
    } on Object {
      state = const FinancialTransactionActionState.failure(
        message: 'Não foi possível registrar o lançamento. Tente novamente.',
        operationUncertain: true,
      );
    }
  }

  Future<void> updateTransaction({
    required String transactionId,
    required FinancialTransactionEdit edit,
  }) => _mutate(
    successMessage: 'Lançamento atualizado e confirmado pelo servidor.',
    operation: (String ownerId) => _repository.updateDescription(
      ownerId: ownerId,
      transactionId: transactionId,
      edit: edit.normalized(now: ref.read(financialClockProvider)()),
    ),
  );

  Future<void> voidTransaction({required String transactionId}) => _mutate(
    successMessage: 'Lançamento cancelado. Ele não participa mais do saldo.',
    operation: (String ownerId) => _repository.voidTransaction(
      ownerId: ownerId,
      transactionId: transactionId,
    ),
  );

  Future<void> _mutate({
    required String successMessage,
    required Future<FinancialTransaction> Function(String ownerId) operation,
  }) async {
    if (state.isLoading) {
      return;
    }
    state = const FinancialTransactionActionState.loading();
    try {
      final String ownerId = requireFinancialTransactionOwner(ref);
      final FinancialTransaction transaction = await operation(ownerId);
      if (_isDisposed || requireFinancialTransactionOwner(ref) != ownerId) {
        return;
      }
      state = FinancialTransactionActionState.success(
        message: successMessage,
        transaction: transaction,
      );
      ref
          .read(financialTransactionsControllerProvider.notifier)
          .acceptConfirmed(transaction);
      ref.invalidate(financialTransactionDetailsProvider(transaction.id));
    } on FinancialTransactionFailure catch (failure) {
      state = FinancialTransactionActionState.failure(
        message: failure.safeMessage,
        operationUncertain: failure.isUncertain,
      );
    } on Object {
      state = const FinancialTransactionActionState.failure(
        message: 'Não foi possível concluir a operação. Tente novamente.',
      );
    }
  }
}
