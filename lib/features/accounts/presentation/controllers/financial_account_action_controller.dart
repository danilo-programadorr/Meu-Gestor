import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_gestor_financeiro/core/errors/app_exception.dart';
import 'package:meu_gestor_financeiro/features/accounts/data/financial_account_providers.dart';
import 'package:meu_gestor_financeiro/features/accounts/domain/financial_account.dart';
import 'package:meu_gestor_financeiro/features/accounts/domain/financial_account_failure.dart';
import 'package:meu_gestor_financeiro/features/accounts/domain/financial_account_repository.dart';
import 'package:meu_gestor_financeiro/features/accounts/presentation/controllers/financial_accounts_controller.dart';

enum FinancialAccountActionStatus { idle, loading, success, failure }

final class FinancialAccountActionState {
  const FinancialAccountActionState({
    required this.status,
    this.message,
    this.account,
    this.operationUncertain = false,
  });

  const FinancialAccountActionState.idle()
    : this(status: FinancialAccountActionStatus.idle);

  const FinancialAccountActionState.loading()
    : this(status: FinancialAccountActionStatus.loading);

  const FinancialAccountActionState.success({
    required String message,
    required FinancialAccount account,
  }) : this(
         status: FinancialAccountActionStatus.success,
         message: message,
         account: account,
       );

  const FinancialAccountActionState.failure({
    required String message,
    bool operationUncertain = false,
  }) : this(
         status: FinancialAccountActionStatus.failure,
         message: message,
         operationUncertain: operationUncertain,
       );

  final FinancialAccountActionStatus status;
  final String? message;
  final FinancialAccount? account;
  final bool operationUncertain;

  bool get isLoading => status == FinancialAccountActionStatus.loading;
}

final NotifierProvider<
  FinancialAccountActionController,
  FinancialAccountActionState
>
financialAccountActionControllerProvider =
    NotifierProvider.autoDispose<
      FinancialAccountActionController,
      FinancialAccountActionState
    >(FinancialAccountActionController.new);

final class FinancialAccountActionController
    extends Notifier<FinancialAccountActionState> {
  String? _pendingCreationId;
  bool _isDisposed = false;

  FinancialAccountRepository get _repository =>
      ref.read(financialAccountRepositoryProvider);

  @override
  FinancialAccountActionState build() {
    _isDisposed = false;
    ref.onDispose(() {
      _pendingCreationId = null;
      _isDisposed = true;
    });
    return const FinancialAccountActionState.idle();
  }

  void clearMessage() {
    if (!state.isLoading) {
      state = const FinancialAccountActionState.idle();
    }
  }

  Future<void> create(FinancialAccountDraft draft) async {
    if (state.isLoading) {
      return;
    }
    final String ownerId;
    final FinancialAccountDraft normalized;
    try {
      ownerId = requireFinancialAccountOwner(ref);
      normalized = draft.normalized();
    } on ValidationException catch (error) {
      state = FinancialAccountActionState.failure(message: error.message);
      return;
    } on FormatException {
      state = const FinancialAccountActionState.failure(
        message: 'O saldo inicial está fora do limite permitido.',
      );
      return;
    } on FinancialAccountFailure catch (failure) {
      state = FinancialAccountActionState.failure(message: failure.safeMessage);
      return;
    }

    _pendingCreationId ??= _repository.newAccountId(ownerId: ownerId);
    state = const FinancialAccountActionState.loading();
    try {
      final FinancialAccount account = await _repository.create(
        ownerId: ownerId,
        accountId: _pendingCreationId!,
        draft: normalized,
      );
      if (_isDisposed || requireFinancialAccountOwner(ref) != ownerId) {
        return;
      }
      _pendingCreationId = null;
      state = FinancialAccountActionState.success(
        message: 'Conta criada e confirmada pelo servidor.',
        account: account,
      );
      ref
          .read(financialAccountsControllerProvider.notifier)
          .acceptConfirmed(account);
    } on FinancialAccountFailure catch (failure) {
      state = FinancialAccountActionState.failure(
        message: failure.isUncertain
            ? 'Não foi possível confirmar a criação. Tente novamente; a mesma tentativa será verificada sem duplicar a conta.'
            : failure.safeMessage,
        operationUncertain: failure.isUncertain,
      );
    } on Object {
      state = const FinancialAccountActionState.failure(
        message: 'Não foi possível criar a conta. Tente novamente.',
        operationUncertain: true,
      );
    }
  }

  Future<void> updateAccount({
    required String accountId,
    required FinancialAccountDraft draft,
  }) => _mutate(
    successMessage: 'Conta atualizada e confirmada pelo servidor.',
    operation: (String ownerId) => _repository.update(
      ownerId: ownerId,
      accountId: accountId,
      draft: draft.normalized(),
    ),
  );

  Future<void> setArchived({
    required String accountId,
    required bool archived,
  }) => _mutate(
    successMessage: archived
        ? 'Conta arquivada e confirmada pelo servidor.'
        : 'Conta restaurada e confirmada pelo servidor.',
    operation: (String ownerId) => _repository.setArchived(
      ownerId: ownerId,
      accountId: accountId,
      archived: archived,
    ),
  );

  Future<void> _mutate({
    required String successMessage,
    required Future<FinancialAccount> Function(String ownerId) operation,
  }) async {
    if (state.isLoading) {
      return;
    }
    state = const FinancialAccountActionState.loading();
    try {
      final String ownerId = requireFinancialAccountOwner(ref);
      final FinancialAccount account = await operation(ownerId);
      if (_isDisposed || requireFinancialAccountOwner(ref) != ownerId) {
        return;
      }
      state = FinancialAccountActionState.success(
        message: successMessage,
        account: account,
      );
      ref
          .read(financialAccountsControllerProvider.notifier)
          .acceptConfirmed(account);
    } on ValidationException catch (error) {
      state = FinancialAccountActionState.failure(message: error.message);
    } on FormatException {
      state = const FinancialAccountActionState.failure(
        message: 'O saldo inicial está fora do limite permitido.',
      );
    } on FinancialAccountFailure catch (failure) {
      state = FinancialAccountActionState.failure(
        message: failure.safeMessage,
        operationUncertain: failure.isUncertain,
      );
    } on Object {
      state = const FinancialAccountActionState.failure(
        message: 'Não foi possível concluir a operação. Tente novamente.',
      );
    }
  }
}
