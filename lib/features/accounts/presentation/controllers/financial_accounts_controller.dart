import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_gestor_financeiro/core/money/money.dart';
import 'package:meu_gestor_financeiro/core/security/financial_access.dart';
import 'package:meu_gestor_financeiro/features/accounts/data/financial_account_providers.dart';
import 'package:meu_gestor_financeiro/features/accounts/domain/financial_account.dart';
import 'package:meu_gestor_financeiro/features/accounts/domain/financial_account_calculator.dart';
import 'package:meu_gestor_financeiro/features/accounts/domain/financial_account_failure.dart';
import 'package:meu_gestor_financeiro/features/accounts/domain/financial_account_repository.dart';

final AsyncNotifierProvider<FinancialAccountsController, FinancialAccountsState>
financialAccountsControllerProvider =
    AsyncNotifierProvider.autoDispose<
      FinancialAccountsController,
      FinancialAccountsState
    >(FinancialAccountsController.new);

final financialAccountDetailsProvider = FutureProvider.autoDispose
    .family<FinancialAccount, String>((Ref ref, String accountId) async {
      final String ownerId = requireFinancialAccountOwner(ref);
      return ref
          .read(financialAccountRepositoryProvider)
          .readOwnAccount(
            ownerId: ownerId,
            accountId: accountId,
            serverOnly: true,
          );
    });

final class FinancialAccountsState {
  const FinancialAccountsState({
    required this.accounts,
    required this.isServerConfirmed,
  });

  final List<FinancialAccount> accounts;
  final bool isServerConfirmed;

  List<FinancialAccount> get activeAccounts => accounts
      .where((FinancialAccount account) => !account.isArchived)
      .toList(growable: false);

  List<FinancialAccount> get archivedAccounts => accounts
      .where((FinancialAccount account) => account.isArchived)
      .toList(growable: false);

  Money get totalOpeningBalance =>
      FinancialAccountCalculator.totalOpeningBalance(accounts);

  FinancialAccount? findById(String accountId) {
    for (final FinancialAccount account in accounts) {
      if (account.id == accountId) {
        return account;
      }
    }
    return null;
  }
}

final class FinancialAccountsController
    extends AsyncNotifier<FinancialAccountsState> {
  @override
  Future<FinancialAccountsState> build() => _load();

  Future<void> refresh() async {
    state = const AsyncLoading<FinancialAccountsState>();
    state = await AsyncValue.guard<FinancialAccountsState>(_load);
  }

  void acceptConfirmed(FinancialAccount account) {
    final FinancialAccountsState? current = state.value;
    if (current == null) {
      return;
    }
    final List<FinancialAccount> accounts = List<FinancialAccount>.of(
      current.accounts,
    );
    final int index = accounts.indexWhere(
      (FinancialAccount item) => item.id == account.id,
    );
    if (index < 0) {
      accounts.add(account);
    } else {
      accounts[index] = account;
    }
    accounts.sort(
      (FinancialAccount first, FinancialAccount second) =>
          first.name.toLowerCase().compareTo(second.name.toLowerCase()),
    );
    state = AsyncData<FinancialAccountsState>(
      FinancialAccountsState(
        accounts: List<FinancialAccount>.unmodifiable(accounts),
        isServerConfirmed: true,
      ),
    );
  }

  Future<FinancialAccountsState> _load() async {
    final String ownerId = requireFinancialAccountOwner(ref);
    final FinancialAccountsReadResult result = await ref
        .read(financialAccountRepositoryProvider)
        .readOwnAccounts(ownerId: ownerId, serverOnly: true);
    if (!result.isFromServer || result.hasPendingWrites) {
      throw const FinancialAccountFailure(
        kind: FinancialAccountFailureKind.failedPrecondition,
        safeMessage:
            'Não foi possível confirmar suas contas com o servidor. Tente novamente.',
        code: 'accounts_server_confirmation_required',
      );
    }
    return FinancialAccountsState(
      accounts: result.accounts,
      isServerConfirmed: true,
    );
  }
}

String requireFinancialAccountOwner(Ref ref) {
  final String? ownerId = verifiedFinancialOwner(ref);
  if (ownerId == null) {
    throw const FinancialAccountFailure(
      kind: FinancialAccountFailureKind.unauthenticated,
      safeMessage:
          'Confirme seu acesso e seu perfil antes de consultar contas.',
      code: 'account_access_gate_denied',
    );
  }
  return ownerId;
}
