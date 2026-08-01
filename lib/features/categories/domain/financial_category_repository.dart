import 'package:meu_gestor_financeiro/features/categories/domain/financial_category.dart';

final class FinancialCategoriesReadResult {
  const FinancialCategoriesReadResult({
    required this.categories,
    required this.isFromServer,
    required this.hasPendingWrites,
  });

  final List<FinancialCategory> categories;
  final bool isFromServer;
  final bool hasPendingWrites;
}

abstract interface class FinancialCategoryRepository {
  String newCategoryId({required String ownerId});

  Future<FinancialCategoriesReadResult> readOwnCategories({
    required String ownerId,
    required bool serverOnly,
  });

  Future<FinancialCategory> readOwnCategory({
    required String ownerId,
    required String categoryId,
    required bool serverOnly,
  });

  Future<FinancialCategory> create({
    required String ownerId,
    required String categoryId,
    required FinancialCategoryDraft draft,
  });

  Future<FinancialCategory> update({
    required String ownerId,
    required String categoryId,
    required FinancialCategoryDraft draft,
  });

  Future<FinancialCategory> setArchived({
    required String ownerId,
    required String categoryId,
    required bool archived,
  });
}
