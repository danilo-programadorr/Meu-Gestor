import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_gestor_financeiro/core/security/financial_access.dart';
import 'package:meu_gestor_financeiro/features/categories/data/financial_category_providers.dart';
import 'package:meu_gestor_financeiro/features/categories/domain/financial_category.dart';
import 'package:meu_gestor_financeiro/features/categories/domain/financial_category_failure.dart';
import 'package:meu_gestor_financeiro/features/categories/domain/financial_category_repository.dart';

final AsyncNotifierProvider<
  FinancialCategoriesController,
  FinancialCategoriesState
>
financialCategoriesControllerProvider =
    AsyncNotifierProvider.autoDispose<
      FinancialCategoriesController,
      FinancialCategoriesState
    >(FinancialCategoriesController.new);

final financialCategoryDetailsProvider = FutureProvider.autoDispose
    .family<FinancialCategory, String>((Ref ref, String categoryId) async {
      final String ownerId = requireFinancialCategoryOwner(ref);
      return ref
          .read(financialCategoryRepositoryProvider)
          .readOwnCategory(
            ownerId: ownerId,
            categoryId: categoryId,
            serverOnly: true,
          );
    });

final class FinancialCategoriesState {
  const FinancialCategoriesState({
    required this.categories,
    required this.isServerConfirmed,
  });

  final List<FinancialCategory> categories;
  final bool isServerConfirmed;

  List<FinancialCategory> get activeCategories => categories
      .where((FinancialCategory category) => !category.isArchived)
      .toList(growable: false);

  List<FinancialCategory> get archivedCategories => categories
      .where((FinancialCategory category) => category.isArchived)
      .toList(growable: false);

  List<FinancialCategory> activeByKind(FinancialCategoryKind kind) =>
      activeCategories
          .where((FinancialCategory category) => category.kind == kind)
          .toList(growable: false);

  FinancialCategory? findById(String categoryId) {
    for (final FinancialCategory category in categories) {
      if (category.id == categoryId) {
        return category;
      }
    }
    return null;
  }
}

final class FinancialCategoriesController
    extends AsyncNotifier<FinancialCategoriesState> {
  @override
  Future<FinancialCategoriesState> build() => _load();

  Future<void> refresh() async {
    state = const AsyncLoading<FinancialCategoriesState>();
    state = await AsyncValue.guard<FinancialCategoriesState>(_load);
  }

  void acceptConfirmed(FinancialCategory category) {
    final FinancialCategoriesState? current = state.value;
    if (current == null) {
      return;
    }
    final List<FinancialCategory> categories = List<FinancialCategory>.of(
      current.categories,
    );
    final int index = categories.indexWhere(
      (FinancialCategory item) => item.id == category.id,
    );
    if (index < 0) {
      categories.add(category);
    } else {
      categories[index] = category;
    }
    categories.sort(
      (FinancialCategory first, FinancialCategory second) =>
          first.name.toLowerCase().compareTo(second.name.toLowerCase()),
    );
    state = AsyncData<FinancialCategoriesState>(
      FinancialCategoriesState(
        categories: List<FinancialCategory>.unmodifiable(categories),
        isServerConfirmed: true,
      ),
    );
  }

  Future<FinancialCategoriesState> _load() async {
    final String ownerId = requireFinancialCategoryOwner(ref);
    final FinancialCategoriesReadResult result = await ref
        .read(financialCategoryRepositoryProvider)
        .readOwnCategories(ownerId: ownerId, serverOnly: true);
    if (!result.isFromServer || result.hasPendingWrites) {
      throw const FinancialCategoryFailure(
        kind: FinancialCategoryFailureKind.failedPrecondition,
        safeMessage:
            'Não foi possível confirmar suas categorias com o servidor. Tente novamente.',
        code: 'categories_server_confirmation_required',
      );
    }
    return FinancialCategoriesState(
      categories: result.categories,
      isServerConfirmed: true,
    );
  }
}

String requireFinancialCategoryOwner(Ref ref) {
  final String? ownerId = verifiedFinancialOwner(ref);
  if (ownerId == null) {
    throw const FinancialCategoryFailure(
      kind: FinancialCategoryFailureKind.unauthenticated,
      safeMessage:
          'Confirme seu acesso e seu perfil antes de consultar categorias.',
      code: 'category_access_gate_denied',
    );
  }
  return ownerId;
}
