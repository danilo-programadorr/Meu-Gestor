import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_gestor_financeiro/core/errors/app_exception.dart';
import 'package:meu_gestor_financeiro/features/categories/data/financial_category_providers.dart';
import 'package:meu_gestor_financeiro/features/categories/domain/financial_category.dart';
import 'package:meu_gestor_financeiro/features/categories/domain/financial_category_failure.dart';
import 'package:meu_gestor_financeiro/features/categories/domain/financial_category_repository.dart';
import 'package:meu_gestor_financeiro/features/categories/presentation/controllers/financial_categories_controller.dart';

enum FinancialCategoryActionStatus { idle, loading, success, failure }

final class FinancialCategoryActionState {
  const FinancialCategoryActionState({
    required this.status,
    this.message,
    this.category,
    this.operationUncertain = false,
  });

  const FinancialCategoryActionState.idle()
    : this(status: FinancialCategoryActionStatus.idle);

  const FinancialCategoryActionState.loading()
    : this(status: FinancialCategoryActionStatus.loading);

  const FinancialCategoryActionState.success({
    required String message,
    required FinancialCategory category,
  }) : this(
         status: FinancialCategoryActionStatus.success,
         message: message,
         category: category,
       );

  const FinancialCategoryActionState.failure({
    required String message,
    bool operationUncertain = false,
  }) : this(
         status: FinancialCategoryActionStatus.failure,
         message: message,
         operationUncertain: operationUncertain,
       );

  final FinancialCategoryActionStatus status;
  final String? message;
  final FinancialCategory? category;
  final bool operationUncertain;

  bool get isLoading => status == FinancialCategoryActionStatus.loading;
}

final NotifierProvider<
  FinancialCategoryActionController,
  FinancialCategoryActionState
>
financialCategoryActionControllerProvider =
    NotifierProvider.autoDispose<
      FinancialCategoryActionController,
      FinancialCategoryActionState
    >(FinancialCategoryActionController.new);

final class FinancialCategoryActionController
    extends Notifier<FinancialCategoryActionState> {
  String? _pendingCreationId;
  bool _isDisposed = false;

  FinancialCategoryRepository get _repository =>
      ref.read(financialCategoryRepositoryProvider);

  @override
  FinancialCategoryActionState build() {
    _isDisposed = false;
    ref.onDispose(() {
      _pendingCreationId = null;
      _isDisposed = true;
    });
    return const FinancialCategoryActionState.idle();
  }

  Future<void> create(FinancialCategoryDraft draft) async {
    if (state.isLoading) {
      return;
    }
    final String ownerId;
    final FinancialCategoryDraft normalized;
    try {
      ownerId = requireFinancialCategoryOwner(ref);
      normalized = draft.normalized();
    } on ValidationException catch (error) {
      state = FinancialCategoryActionState.failure(message: error.message);
      return;
    } on FinancialCategoryFailure catch (failure) {
      state = FinancialCategoryActionState.failure(
        message: failure.safeMessage,
      );
      return;
    }
    _pendingCreationId ??= _repository.newCategoryId(ownerId: ownerId);
    state = const FinancialCategoryActionState.loading();
    try {
      final FinancialCategory category = await _repository.create(
        ownerId: ownerId,
        categoryId: _pendingCreationId!,
        draft: normalized,
      );
      if (_isDisposed || requireFinancialCategoryOwner(ref) != ownerId) {
        return;
      }
      _pendingCreationId = null;
      state = FinancialCategoryActionState.success(
        message: 'Categoria criada e confirmada pelo servidor.',
        category: category,
      );
      ref
          .read(financialCategoriesControllerProvider.notifier)
          .acceptConfirmed(category);
    } on FinancialCategoryFailure catch (failure) {
      state = FinancialCategoryActionState.failure(
        message: failure.isUncertain
            ? 'Não foi possível confirmar a criação. Tente novamente; a mesma tentativa será verificada sem duplicar a categoria.'
            : failure.safeMessage,
        operationUncertain: failure.isUncertain,
      );
    } on Object {
      state = const FinancialCategoryActionState.failure(
        message: 'Não foi possível criar a categoria. Tente novamente.',
        operationUncertain: true,
      );
    }
  }

  Future<void> updateCategory({
    required String categoryId,
    required FinancialCategoryDraft draft,
  }) => _mutate(
    successMessage: 'Categoria atualizada e confirmada pelo servidor.',
    operation: (String ownerId) => _repository.update(
      ownerId: ownerId,
      categoryId: categoryId,
      draft: draft.normalized(),
    ),
  );

  Future<void> setArchived({
    required String categoryId,
    required bool archived,
  }) => _mutate(
    successMessage: archived
        ? 'Categoria arquivada e confirmada pelo servidor.'
        : 'Categoria restaurada e confirmada pelo servidor.',
    operation: (String ownerId) => _repository.setArchived(
      ownerId: ownerId,
      categoryId: categoryId,
      archived: archived,
    ),
  );

  Future<void> _mutate({
    required String successMessage,
    required Future<FinancialCategory> Function(String ownerId) operation,
  }) async {
    if (state.isLoading) {
      return;
    }
    state = const FinancialCategoryActionState.loading();
    try {
      final String ownerId = requireFinancialCategoryOwner(ref);
      final FinancialCategory category = await operation(ownerId);
      if (_isDisposed || requireFinancialCategoryOwner(ref) != ownerId) {
        return;
      }
      state = FinancialCategoryActionState.success(
        message: successMessage,
        category: category,
      );
      ref
          .read(financialCategoriesControllerProvider.notifier)
          .acceptConfirmed(category);
    } on ValidationException catch (error) {
      state = FinancialCategoryActionState.failure(message: error.message);
    } on FinancialCategoryFailure catch (failure) {
      state = FinancialCategoryActionState.failure(
        message: failure.safeMessage,
        operationUncertain: failure.isUncertain,
      );
    } on Object {
      state = const FinancialCategoryActionState.failure(
        message: 'Não foi possível concluir a operação. Tente novamente.',
      );
    }
  }
}
