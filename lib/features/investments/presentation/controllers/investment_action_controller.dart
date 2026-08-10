import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_gestor_financeiro/features/investments/data/investment_providers.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_failure.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_income_event.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_operation.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_portfolio.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_repository.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/tracked_investment_asset.dart';
import 'package:meu_gestor_financeiro/features/investments/presentation/controllers/investments_controller.dart';

enum InvestmentActionStatus { idle, loading, success, failure }

final class InvestmentActionState {
  const InvestmentActionState({
    required this.status,
    this.message,
    this.operationUncertain = false,
  });

  const InvestmentActionState.idle()
    : this(status: InvestmentActionStatus.idle);

  const InvestmentActionState.loading()
    : this(status: InvestmentActionStatus.loading);

  const InvestmentActionState.success(String message)
    : this(status: InvestmentActionStatus.success, message: message);

  const InvestmentActionState.failure(
    String message, {
    bool operationUncertain = false,
  }) : this(
         status: InvestmentActionStatus.failure,
         message: message,
         operationUncertain: operationUncertain,
       );

  final InvestmentActionStatus status;
  final String? message;
  final bool operationUncertain;

  bool get isLoading => status == InvestmentActionStatus.loading;
}

final NotifierProvider<InvestmentActionController, InvestmentActionState>
investmentActionControllerProvider =
    NotifierProvider.autoDispose<
      InvestmentActionController,
      InvestmentActionState
    >(InvestmentActionController.new);

final class InvestmentActionController extends Notifier<InvestmentActionState> {
  String? _pendingPortfolioId;
  String? _pendingOperationId;
  String? _pendingVoidMutationId;
  String? _pendingIncomeEventId;
  String? _pendingIncomeMutationId;
  String? _pendingIncomeActionKey;
  bool _disposed = false;

  InvestmentRepository get _repository =>
      ref.read(investmentRepositoryProvider);

  @override
  InvestmentActionState build() {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _pendingPortfolioId = null;
      _pendingOperationId = null;
      _pendingVoidMutationId = null;
      _pendingIncomeEventId = null;
      _pendingIncomeMutationId = null;
      _pendingIncomeActionKey = null;
    });
    return const InvestmentActionState.idle();
  }

  Future<bool> createPortfolio(InvestmentPortfolioDraft draft) async {
    if (state.isLoading) {
      return false;
    }
    final String ownerId = requireInvestmentOwner(ref);
    _pendingPortfolioId ??= _repository.newPortfolioId(ownerId: ownerId);
    return _run(
      ownerId: ownerId,
      successMessage: 'Carteira criada e confirmada pelo servidor.',
      operation: () => _repository.createPortfolio(
        ownerId: ownerId,
        portfolioId: _pendingPortfolioId!,
        draft: draft.normalized(),
      ),
      onSuccess: () => _pendingPortfolioId = null,
      onDefiniteFailure: () => _pendingPortfolioId = null,
    );
  }

  Future<bool> updatePortfolio({
    required InvestmentPortfolio portfolio,
    required InvestmentPortfolioDraft draft,
  }) => _runForCurrentOwner(
    successMessage: 'Carteira atualizada e confirmada pelo servidor.',
    operation: (String ownerId) => _repository.updatePortfolio(
      ownerId: ownerId,
      portfolioId: portfolio.id,
      expectedRevision: portfolio.revision,
      draft: draft.normalized(),
    ),
  );

  Future<bool> setPortfolioArchived({
    required InvestmentPortfolio portfolio,
    required bool archived,
  }) => _runForCurrentOwner(
    successMessage: archived
        ? 'Carteira arquivada. Nenhum histórico foi apagado.'
        : 'Carteira restaurada e confirmada pelo servidor.',
    operation: (String ownerId) => _repository.setPortfolioArchived(
      ownerId: ownerId,
      portfolioId: portfolio.id,
      expectedRevision: portfolio.revision,
      archived: archived,
    ),
  );

  Future<bool> createAsset(TrackedInvestmentAssetDraft draft) =>
      _runForCurrentOwner(
        successMessage: 'Ativo adicionado à carteira.',
        operation: (String ownerId) => _repository.createAsset(
          ownerId: ownerId,
          draft: draft.normalized(),
        ),
      );

  Future<bool> createOperation(InvestmentOperationDraft draft) async {
    if (state.isLoading) {
      return false;
    }
    final String ownerId = requireInvestmentOwner(ref);
    _pendingOperationId ??= _repository.newOperationId(ownerId: ownerId);
    return _run(
      ownerId: ownerId,
      successMessage:
          '${draft.kind.label} registrada e confirmada pelo servidor.',
      operation: () => _repository.createOperation(
        ownerId: ownerId,
        operationId: _pendingOperationId!,
        draft: draft,
      ),
      onSuccess: () => _pendingOperationId = null,
      onDefiniteFailure: () => _pendingOperationId = null,
    );
  }

  Future<bool> voidOperation(InvestmentOperation operation) async {
    if (state.isLoading) {
      return false;
    }
    final String ownerId = requireInvestmentOwner(ref);
    _pendingVoidMutationId ??= _repository.newMutationId(ownerId: ownerId);
    return _run(
      ownerId: ownerId,
      successMessage: 'Operação anulada. O histórico foi preservado.',
      operation: () => _repository.voidOperation(
        ownerId: ownerId,
        operationId: operation.id,
        expectedRevision: operation.revision,
        mutationId: _pendingVoidMutationId!,
      ),
      onSuccess: () => _pendingVoidMutationId = null,
      onDefiniteFailure: () => _pendingVoidMutationId = null,
    );
  }

  Future<bool> createIncomeEvent(InvestmentIncomeDraft draft) async {
    if (state.isLoading) {
      return false;
    }
    final String ownerId = requireInvestmentOwner(ref);
    _pendingIncomeEventId ??= _repository.newIncomeEventId(ownerId: ownerId);
    return _run(
      ownerId: ownerId,
      successMessage: 'Provento previsto e confirmado pelo servidor.',
      operation: () => _repository.createIncomeEvent(
        ownerId: ownerId,
        eventId: _pendingIncomeEventId!,
        draft: draft,
      ),
      onSuccess: () => _pendingIncomeEventId = null,
      onDefiniteFailure: () => _pendingIncomeEventId = null,
    );
  }

  Future<bool> updateExpectedIncomeEvent({
    required InvestmentIncomeEvent event,
    required InvestmentIncomeDraft draft,
  }) async {
    final String ownerId = requireInvestmentOwner(ref);
    final String mutationId = _incomeMutationId(
      ownerId: ownerId,
      actionKey: 'edit:${event.id}:${event.revision}',
    );
    return _run(
      ownerId: ownerId,
      successMessage: 'Previsão atualizada e confirmada pelo servidor.',
      operation: () => _repository.updateExpectedIncomeEvent(
        ownerId: ownerId,
        eventId: event.id,
        expectedRevision: event.revision,
        mutationId: mutationId,
        draft: draft,
      ),
      onSuccess: _clearIncomeMutation,
      onDefiniteFailure: _clearIncomeMutation,
    );
  }

  Future<bool> receiveIncomeEvent({
    required InvestmentIncomeEvent event,
    required DateTime receivedDate,
  }) async {
    final String ownerId = requireInvestmentOwner(ref);
    final String mutationId = _incomeMutationId(
      ownerId: ownerId,
      actionKey: 'receive:${event.id}:${event.revision}',
    );
    return _run(
      ownerId: ownerId,
      successMessage: 'Recebimento confirmado. Nenhum saldo foi alterado.',
      operation: () => _repository.receiveIncomeEvent(
        ownerId: ownerId,
        eventId: event.id,
        expectedRevision: event.revision,
        mutationId: mutationId,
        receivedDate: receivedDate,
      ),
      onSuccess: _clearIncomeMutation,
      onDefiniteFailure: _clearIncomeMutation,
    );
  }

  Future<bool> cancelIncomeEvent(InvestmentIncomeEvent event) =>
      _runIncomeTerminal(
        event: event,
        action: 'cancel',
        successMessage: 'Previsão cancelada. O histórico foi preservado.',
        operation: (String ownerId, String mutationId) =>
            _repository.cancelIncomeEvent(
              ownerId: ownerId,
              eventId: event.id,
              expectedRevision: event.revision,
              mutationId: mutationId,
            ),
      );

  Future<bool> voidIncomeEvent(
    InvestmentIncomeEvent event,
  ) => _runIncomeTerminal(
    event: event,
    action: 'void',
    successMessage:
        'Recebimento anulado. O histórico foi preservado e nenhum saldo foi alterado.',
    operation: (String ownerId, String mutationId) =>
        _repository.voidIncomeEvent(
          ownerId: ownerId,
          eventId: event.id,
          expectedRevision: event.revision,
          mutationId: mutationId,
        ),
  );

  Future<bool> _runIncomeTerminal({
    required InvestmentIncomeEvent event,
    required String action,
    required String successMessage,
    required Future<Object> Function(String ownerId, String mutationId)
    operation,
  }) {
    final String ownerId = requireInvestmentOwner(ref);
    final String mutationId = _incomeMutationId(
      ownerId: ownerId,
      actionKey: '$action:${event.id}:${event.revision}',
    );
    return _run(
      ownerId: ownerId,
      successMessage: successMessage,
      operation: () => operation(ownerId, mutationId),
      onSuccess: _clearIncomeMutation,
      onDefiniteFailure: _clearIncomeMutation,
    );
  }

  String _incomeMutationId({
    required String ownerId,
    required String actionKey,
  }) {
    if (_pendingIncomeActionKey != actionKey) {
      _pendingIncomeActionKey = actionKey;
      _pendingIncomeMutationId = _repository.newMutationId(ownerId: ownerId);
    }
    return _pendingIncomeMutationId!;
  }

  void _clearIncomeMutation() {
    _pendingIncomeActionKey = null;
    _pendingIncomeMutationId = null;
  }

  Future<bool> _runForCurrentOwner({
    required String successMessage,
    required Future<Object> Function(String ownerId) operation,
  }) {
    final String ownerId = requireInvestmentOwner(ref);
    return _run(
      ownerId: ownerId,
      successMessage: successMessage,
      operation: () => operation(ownerId),
    );
  }

  Future<bool> _run({
    required String ownerId,
    required String successMessage,
    required Future<Object> Function() operation,
    void Function()? onSuccess,
    void Function()? onDefiniteFailure,
  }) async {
    if (state.isLoading) {
      return false;
    }
    state = const InvestmentActionState.loading();
    try {
      await operation();
      if (_disposed || requireInvestmentOwner(ref) != ownerId) {
        return false;
      }
      await ref.read(investmentsControllerProvider.notifier).refresh();
      if (_disposed || requireInvestmentOwner(ref) != ownerId) {
        return false;
      }
      final AsyncValue<InvestmentsState> refreshed = ref.read(
        investmentsControllerProvider,
      );
      if (refreshed.hasError) {
        throw refreshed.error!;
      }
      onSuccess?.call();
      state = InvestmentActionState.success(successMessage);
      return true;
    } on InvestmentFailure catch (failure) {
      if (!failure.isUncertain) {
        onDefiniteFailure?.call();
      }
      if (!_disposed) {
        state = InvestmentActionState.failure(
          failure.isUncertain
              ? 'Não foi possível confirmar a operação. Tente novamente; a mesma tentativa será reconciliada sem duplicação.'
              : failure.safeMessage,
          operationUncertain: failure.isUncertain,
        );
      }
      return false;
    } on Object {
      if (!_disposed) {
        state = const InvestmentActionState.failure(
          'Não foi possível concluir a operação. Tente novamente.',
          operationUncertain: true,
        );
      }
      return false;
    }
  }
}
