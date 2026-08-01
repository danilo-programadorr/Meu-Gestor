import 'dart:async';

import 'package:meu_gestor_financeiro/features/categories/domain/financial_category.dart';
import 'package:meu_gestor_financeiro/features/categories/domain/financial_category_failure.dart';
import 'package:meu_gestor_financeiro/features/categories/domain/financial_category_repository.dart';

final class FakeFinancialCategoryRepository
    implements FinancialCategoryRepository {
  FakeFinancialCategoryRepository({List<FinancialCategory>? initialCategories})
    : categories = List<FinancialCategory>.of(
        initialCategories ?? <FinancialCategory>[],
      );

  final List<FinancialCategory> categories;
  FinancialCategoryFailure? nextFailure;
  Completer<void>? mutationBarrier;
  bool serverConfirmed = true;
  bool pendingWrites = false;
  int readCalls = 0;
  int createCalls = 0;
  int generatedIdCalls = 0;

  @override
  String newCategoryId({required String ownerId}) {
    generatedIdCalls += 1;
    return 'generated-$generatedIdCalls';
  }

  @override
  Future<FinancialCategory> create({
    required String ownerId,
    required String categoryId,
    required FinancialCategoryDraft draft,
  }) async {
    createCalls += 1;
    await _waitMutation();
    _throwIfNeeded();
    final FinancialCategoryDraft normalized = draft.normalized();
    final FinancialCategory? existing = _find(ownerId, categoryId);
    if (existing != null) {
      if (existing.name == normalized.name &&
          existing.kind == normalized.kind &&
          existing.icon == normalized.icon &&
          existing.color == normalized.color) {
        return existing;
      }
      throw const FinancialCategoryFailure(
        kind: FinancialCategoryFailureKind.alreadyExists,
        safeMessage: 'Esta categoria já existe.',
      );
    }
    final DateTime timestamp = DateTime.utc(2026, 8, 1, 12);
    final FinancialCategory category = FinancialCategory(
      id: categoryId,
      ownerId: ownerId,
      name: normalized.name,
      kind: normalized.kind,
      icon: normalized.icon,
      color: normalized.color,
      isArchived: false,
      archivedAt: null,
      createdAt: timestamp,
      updatedAt: timestamp,
      schemaVersion: FinancialCategory.currentSchemaVersion,
    );
    categories.add(category);
    return category;
  }

  @override
  Future<FinancialCategoriesReadResult> readOwnCategories({
    required String ownerId,
    required bool serverOnly,
  }) async {
    readCalls += 1;
    _throwIfNeeded();
    return FinancialCategoriesReadResult(
      categories: categories
          .where((item) => item.ownerId == ownerId)
          .toList(growable: false),
      isFromServer: serverConfirmed,
      hasPendingWrites: pendingWrites,
    );
  }

  @override
  Future<FinancialCategory> readOwnCategory({
    required String ownerId,
    required String categoryId,
    required bool serverOnly,
  }) async =>
      _find(ownerId, categoryId) ??
      (throw const FinancialCategoryFailure(
        kind: FinancialCategoryFailureKind.notFound,
        safeMessage: 'Categoria não encontrada.',
      ));

  @override
  Future<FinancialCategory> setArchived({
    required String ownerId,
    required String categoryId,
    required bool archived,
  }) async {
    await _waitMutation();
    _throwIfNeeded();
    final int index = _index(ownerId, categoryId);
    final FinancialCategory current = categories[index];
    final DateTime timestamp = current.updatedAt.add(
      const Duration(seconds: 1),
    );
    categories[index] = current.copyWith(
      isArchived: archived,
      archivedAt: archived ? timestamp : null,
      clearArchivedAt: !archived,
      updatedAt: timestamp,
    );
    return categories[index];
  }

  @override
  Future<FinancialCategory> update({
    required String ownerId,
    required String categoryId,
    required FinancialCategoryDraft draft,
  }) async {
    await _waitMutation();
    _throwIfNeeded();
    final int index = _index(ownerId, categoryId);
    final FinancialCategory current = categories[index];
    final FinancialCategoryDraft normalized = draft.normalized();
    if (current.kind != normalized.kind || current.isArchived) {
      throw const FinancialCategoryFailure(
        kind: FinancialCategoryFailureKind.validation,
        safeMessage: 'Categoria não pode ser alterada.',
      );
    }
    categories[index] = current.copyWith(
      name: normalized.name,
      icon: normalized.icon,
      color: normalized.color,
      updatedAt: current.updatedAt.add(const Duration(seconds: 1)),
    );
    return categories[index];
  }

  FinancialCategory? _find(String ownerId, String categoryId) {
    for (final FinancialCategory category in categories) {
      if (category.ownerId == ownerId && category.id == categoryId) {
        return category;
      }
    }
    return null;
  }

  int _index(String ownerId, String categoryId) {
    final int index = categories.indexWhere(
      (item) => item.ownerId == ownerId && item.id == categoryId,
    );
    if (index < 0) {
      throw const FinancialCategoryFailure(
        kind: FinancialCategoryFailureKind.notFound,
        safeMessage: 'Categoria não encontrada.',
      );
    }
    return index;
  }

  Future<void> _waitMutation() async {
    final Completer<void>? barrier = mutationBarrier;
    if (barrier != null) {
      await barrier.future;
    }
  }

  void _throwIfNeeded() {
    final FinancialCategoryFailure? failure = nextFailure;
    nextFailure = null;
    if (failure != null) {
      throw failure;
    }
  }
}
