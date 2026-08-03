import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_gestor_financeiro/core/dates/sao_paulo_civil_date.dart';
import 'package:meu_gestor_financeiro/core/security/financial_access.dart';
import 'package:meu_gestor_financeiro/features/commitments/domain/financial_commitment.dart';
import 'package:meu_gestor_financeiro/features/commitments/domain/financial_commitment_failure.dart';
import 'package:meu_gestor_financeiro/features/commitments/domain/financial_commitment_repository.dart';
import 'package:meu_gestor_financeiro/features/commitments/presentation/providers/financial_commitment_providers.dart';

enum FinancialCommitmentListFilter {
  all('Todos'),
  pending('Pendentes'),
  overdue('Atrasados'),
  settled('Pagos/recebidos'),
  cancelled('Cancelados'),
  voided('Anulados');

  const FinancialCommitmentListFilter(this.label);

  final String label;
}

final AsyncNotifierProvider<
  PayablesController,
  FinancialCommitmentsState<Payable>
>
payablesControllerProvider =
    AsyncNotifierProvider.autoDispose<
      PayablesController,
      FinancialCommitmentsState<Payable>
    >(PayablesController.new);

final AsyncNotifierProvider<
  ReceivablesController,
  FinancialCommitmentsState<Receivable>
>
receivablesControllerProvider =
    AsyncNotifierProvider.autoDispose<
      ReceivablesController,
      FinancialCommitmentsState<Receivable>
    >(ReceivablesController.new);

final payableDetailsProvider = FutureProvider.autoDispose
    .family<Payable, String>(
      (Ref ref, String payableId) => ref
          .read(financialCommitmentRepositoryProvider)
          .readOwnPayable(
            ownerId: requireFinancialCommitmentOwner(ref),
            payableId: payableId,
            serverOnly: true,
          ),
    );

final receivableDetailsProvider = FutureProvider.autoDispose
    .family<Receivable, String>(
      (Ref ref, String receivableId) => ref
          .read(financialCommitmentRepositoryProvider)
          .readOwnReceivable(
            ownerId: requireFinancialCommitmentOwner(ref),
            receivableId: receivableId,
            serverOnly: true,
          ),
    );

final class FinancialCommitmentsState<T extends FinancialCommitment> {
  const FinancialCommitmentsState({
    required this.commitments,
    required this.isServerConfirmed,
  });

  final List<T> commitments;
  final bool isServerConfirmed;

  T? findById(String id) {
    for (final T commitment in commitments) {
      if (commitment.id == id) {
        return commitment;
      }
    }
    return null;
  }

  List<T> filtered({
    required FinancialCommitmentListFilter filter,
    required SaoPauloCivilDate today,
  }) => commitments
      .where((T commitment) {
        return switch (filter) {
          FinancialCommitmentListFilter.all => true,
          FinancialCommitmentListFilter.pending => commitment.isPending,
          FinancialCommitmentListFilter.overdue => commitment.isOverdue(today),
          FinancialCommitmentListFilter.settled => commitment.isSettled,
          FinancialCommitmentListFilter.cancelled => commitment.isCancelled,
          FinancialCommitmentListFilter.voided => commitment.isVoided,
        };
      })
      .toList(growable: false);
}

abstract base class _FinancialCommitmentsController<
  T extends FinancialCommitment
>
    extends AsyncNotifier<FinancialCommitmentsState<T>> {
  Future<FinancialCommitmentsReadResult<T>> read(
    FinancialCommitmentRepository repository,
    String ownerId,
  );

  @override
  Future<FinancialCommitmentsState<T>> build() => _load();

  Future<void> refresh() async {
    state = AsyncLoading<FinancialCommitmentsState<T>>();
    state = await AsyncValue.guard<FinancialCommitmentsState<T>>(_load);
  }

  void acceptConfirmed(T commitment) {
    final FinancialCommitmentsState<T>? current = state.value;
    if (current == null) {
      return;
    }
    final List<T> updated = List<T>.of(current.commitments);
    final int index = updated.indexWhere((T item) => item.id == commitment.id);
    if (index < 0) {
      updated.add(commitment);
    } else {
      updated[index] = commitment;
    }
    updated.sort(_compareCommitments);
    state = AsyncData<FinancialCommitmentsState<T>>(
      FinancialCommitmentsState<T>(
        commitments: List<T>.unmodifiable(updated),
        isServerConfirmed: true,
      ),
    );
  }

  Future<FinancialCommitmentsState<T>> _load() async {
    final String ownerId = requireFinancialCommitmentOwner(ref);
    final FinancialCommitmentsReadResult<T> result = await read(
      ref.read(financialCommitmentRepositoryProvider),
      ownerId,
    );
    if (!result.isFromServer || result.hasPendingWrites) {
      throw const FinancialCommitmentFailure(
        kind: FinancialCommitmentFailureKind.failedPrecondition,
        safeMessage:
            'Não foi possível confirmar os compromissos com o servidor. Tente novamente.',
        code: 'commitments_server_confirmation_required',
      );
    }
    final List<T> sorted = List<T>.of(result.commitments)
      ..sort(_compareCommitments);
    return FinancialCommitmentsState<T>(
      commitments: List<T>.unmodifiable(sorted),
      isServerConfirmed: true,
    );
  }

  static int _compareCommitments(
    FinancialCommitment first,
    FinancialCommitment second,
  ) {
    final int byDueDate = first.dueDate.compareTo(second.dueDate);
    if (byDueDate != 0) {
      return byDueDate;
    }
    return first.description.toLowerCase().compareTo(
      second.description.toLowerCase(),
    );
  }
}

final class PayablesController
    extends _FinancialCommitmentsController<Payable> {
  @override
  Future<FinancialCommitmentsReadResult<Payable>> read(
    FinancialCommitmentRepository repository,
    String ownerId,
  ) => repository.readOwnPayables(ownerId: ownerId, serverOnly: true);
}

final class ReceivablesController
    extends _FinancialCommitmentsController<Receivable> {
  @override
  Future<FinancialCommitmentsReadResult<Receivable>> read(
    FinancialCommitmentRepository repository,
    String ownerId,
  ) => repository.readOwnReceivables(ownerId: ownerId, serverOnly: true);
}

String requireFinancialCommitmentOwner(Ref ref) {
  final String? ownerId = verifiedFinancialOwner(ref);
  if (ownerId == null) {
    throw const FinancialCommitmentFailure(
      kind: FinancialCommitmentFailureKind.unauthenticated,
      safeMessage:
          'Confirme seu acesso e seu perfil antes de consultar compromissos.',
      code: 'commitment_access_gate_denied',
    );
  }
  return ownerId;
}

String safeFinancialCommitmentErrorMessage(Object error) =>
    error is FinancialCommitmentFailure
    ? error.safeMessage
    : 'Não foi possível carregar os compromissos. Tente novamente.';
