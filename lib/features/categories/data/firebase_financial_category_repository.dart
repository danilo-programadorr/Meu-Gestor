import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:meu_gestor_financeiro/features/categories/data/financial_category_diagnostics.dart';
import 'package:meu_gestor_financeiro/features/categories/data/firestore_financial_category_mapper.dart';
import 'package:meu_gestor_financeiro/features/categories/domain/financial_category.dart';
import 'package:meu_gestor_financeiro/features/categories/domain/financial_category_failure.dart';
import 'package:meu_gestor_financeiro/features/categories/domain/financial_category_repository.dart';

final class FirebaseFinancialCategoryRepository
    implements FinancialCategoryRepository {
  FirebaseFinancialCategoryRepository({
    required FirebaseFirestore firestore,
    required FinancialCategoryDiagnostics diagnostics,
  }) : _firestore = firestore,
       _diagnostics = diagnostics;

  final FirebaseFirestore _firestore;
  final FinancialCategoryDiagnostics _diagnostics;

  @override
  String newCategoryId({required String ownerId}) =>
      _categories(ownerId).doc().id;

  @override
  Future<FinancialCategoriesReadResult> readOwnCategories({
    required String ownerId,
    required bool serverOnly,
  }) async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _categories(
        ownerId,
      ).get(serverOnly ? const GetOptions(source: Source.server) : null);
      return decodeQuerySnapshot(
        ownerId: ownerId,
        documents: snapshot.docs
            .map(
              (QueryDocumentSnapshot<Map<String, dynamic>> document) =>
                  CategoryDocumentData(id: document.id, data: document.data()),
            )
            .toList(growable: false),
        isFromCache: snapshot.metadata.isFromCache,
        hasPendingWrites: snapshot.metadata.hasPendingWrites,
      );
    } on Object catch (error) {
      throw _mapAndRecord(
        operation: 'read_categories',
        stage: serverOnly ? 'server_read' : 'default_read',
        error: error,
      );
    }
  }

  @visibleForTesting
  static FinancialCategoriesReadResult decodeQuerySnapshot({
    required String ownerId,
    required List<CategoryDocumentData> documents,
    required bool isFromCache,
    required bool hasPendingWrites,
  }) {
    final List<FinancialCategory> categories =
        documents
            .map(
              (CategoryDocumentData document) =>
                  FirestoreFinancialCategoryMapper.fromMap(
                    data: document.data,
                    documentId: document.id,
                    expectedOwnerId: ownerId,
                  ),
            )
            .toList(growable: false)
          ..sort(
            (FinancialCategory first, FinancialCategory second) =>
                first.name.toLowerCase().compareTo(second.name.toLowerCase()),
          );
    return FinancialCategoriesReadResult(
      categories: List<FinancialCategory>.unmodifiable(categories),
      isFromServer: !isFromCache,
      hasPendingWrites: hasPendingWrites,
    );
  }

  @override
  Future<FinancialCategory> readOwnCategory({
    required String ownerId,
    required String categoryId,
    required bool serverOnly,
  }) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await _document(
        ownerId,
        categoryId,
      ).get(serverOnly ? const GetOptions(source: Source.server) : null);
      final Map<String, dynamic>? data = snapshot.data();
      if (!snapshot.exists || data == null) {
        throw const FinancialCategoryFailure(
          kind: FinancialCategoryFailureKind.notFound,
          safeMessage: 'Esta categoria não foi encontrada.',
          code: 'category_not_found',
        );
      }
      if (serverOnly &&
          (snapshot.metadata.isFromCache ||
              snapshot.metadata.hasPendingWrites)) {
        throw const FinancialCategoryFailure(
          kind: FinancialCategoryFailureKind.failedPrecondition,
          safeMessage:
              'A alteração ainda não foi confirmada. Verifique sua conexão e tente novamente.',
          code: 'category_not_server_confirmed',
        );
      }
      return FirestoreFinancialCategoryMapper.fromMap(
        data: data,
        documentId: categoryId,
        expectedOwnerId: ownerId,
      );
    } on Object catch (error) {
      throw _mapAndRecord(
        operation: 'read_category',
        stage: serverOnly ? 'server_read' : 'default_read',
        error: error,
      );
    }
  }

  @override
  Future<FinancialCategory> create({
    required String ownerId,
    required String categoryId,
    required FinancialCategoryDraft draft,
  }) async {
    final FinancialCategoryDraft normalized = draft.normalized();
    final DocumentReference<Map<String, dynamic>> reference = _document(
      ownerId,
      categoryId,
    );
    try {
      await _firestore.runTransaction<void>((Transaction transaction) async {
        final DocumentSnapshot<Map<String, dynamic>> snapshot =
            await transaction.get(reference);
        if (snapshot.exists) {
          final Map<String, dynamic>? data = snapshot.data();
          if (data == null) {
            throw const FinancialCategoryFailure(
              kind: FinancialCategoryFailureKind.incompatible,
              safeMessage: 'Não foi possível confirmar esta categoria.',
              code: 'existing_category_without_data',
            );
          }
          final FinancialCategory existing =
              FirestoreFinancialCategoryMapper.fromMap(
                data: data,
                documentId: categoryId,
                expectedOwnerId: ownerId,
              );
          if (!FirestoreFinancialCategoryMapper.matchesDraft(
            existing,
            normalized,
          )) {
            throw const FinancialCategoryFailure(
              kind: FinancialCategoryFailureKind.alreadyExists,
              safeMessage:
                  'Esta tentativa já possui uma categoria diferente. Volte e tente novamente.',
              code: 'category_id_conflict',
            );
          }
          return;
        }
        transaction.set(
          reference,
          FirestoreFinancialCategoryMapper.creationMap(
            ownerId: ownerId,
            draft: normalized,
          ),
        );
      });
      return _readConfirmed(ownerId, categoryId);
    } on Object catch (error) {
      if (_isUncertain(error)) {
        final FinancialCategory? confirmed = await _tryConfirmCreated(
          ownerId: ownerId,
          categoryId: categoryId,
          draft: normalized,
        );
        if (confirmed != null) {
          return confirmed;
        }
      }
      throw _mapAndRecord(
        operation: 'create_category',
        stage: 'transaction_or_confirmation',
        error: error,
      );
    }
  }

  @override
  Future<FinancialCategory> update({
    required String ownerId,
    required String categoryId,
    required FinancialCategoryDraft draft,
  }) async {
    final FinancialCategoryDraft normalized = draft.normalized();
    final DocumentReference<Map<String, dynamic>> reference = _document(
      ownerId,
      categoryId,
    );
    try {
      await _firestore.runTransaction<void>((Transaction transaction) async {
        final DocumentSnapshot<Map<String, dynamic>> snapshot =
            await transaction.get(reference);
        final FinancialCategory current = _decodeRequired(
          snapshot: snapshot,
          ownerId: ownerId,
          categoryId: categoryId,
        );
        if (current.isArchived) {
          throw const FinancialCategoryFailure(
            kind: FinancialCategoryFailureKind.archived,
            safeMessage: 'Restaure a categoria antes de editá-la.',
            code: 'category_archived',
          );
        }
        if (normalized.kind != current.kind) {
          throw const FinancialCategoryFailure(
            kind: FinancialCategoryFailureKind.validation,
            safeMessage: 'O tipo da categoria não pode ser alterado.',
            code: 'category_kind_immutable',
          );
        }
        transaction.update(
          reference,
          FirestoreFinancialCategoryMapper.editableMap(normalized),
        );
      });
      return _readConfirmed(ownerId, categoryId);
    } on Object catch (error) {
      throw _mapAndRecord(
        operation: 'update_category',
        stage: 'transaction_or_confirmation',
        error: error,
      );
    }
  }

  @override
  Future<FinancialCategory> setArchived({
    required String ownerId,
    required String categoryId,
    required bool archived,
  }) async {
    final DocumentReference<Map<String, dynamic>> reference = _document(
      ownerId,
      categoryId,
    );
    try {
      await _firestore.runTransaction<void>((Transaction transaction) async {
        final DocumentSnapshot<Map<String, dynamic>> snapshot =
            await transaction.get(reference);
        final FinancialCategory current = _decodeRequired(
          snapshot: snapshot,
          ownerId: ownerId,
          categoryId: categoryId,
        );
        if (current.isArchived == archived) {
          return;
        }
        transaction.update(reference, <String, Object?>{
          'isArchived': archived,
          'archivedAt': archived ? FieldValue.serverTimestamp() : null,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
      return _readConfirmed(ownerId, categoryId);
    } on Object catch (error) {
      throw _mapAndRecord(
        operation: archived ? 'archive_category' : 'restore_category',
        stage: 'transaction_or_confirmation',
        error: error,
      );
    }
  }

  FinancialCategory _decodeRequired({
    required DocumentSnapshot<Map<String, dynamic>> snapshot,
    required String ownerId,
    required String categoryId,
  }) {
    final Map<String, dynamic>? data = snapshot.data();
    if (!snapshot.exists || data == null) {
      throw const FinancialCategoryFailure(
        kind: FinancialCategoryFailureKind.notFound,
        safeMessage: 'Esta categoria não foi encontrada.',
        code: 'category_not_found',
      );
    }
    return FirestoreFinancialCategoryMapper.fromMap(
      data: data,
      documentId: categoryId,
      expectedOwnerId: ownerId,
    );
  }

  Future<FinancialCategory> _readConfirmed(String ownerId, String categoryId) =>
      readOwnCategory(
        ownerId: ownerId,
        categoryId: categoryId,
        serverOnly: true,
      );

  Future<FinancialCategory?> _tryConfirmCreated({
    required String ownerId,
    required String categoryId,
    required FinancialCategoryDraft draft,
  }) async {
    try {
      final FinancialCategory category = await _readConfirmed(
        ownerId,
        categoryId,
      );
      return FirestoreFinancialCategoryMapper.matchesDraft(category, draft)
          ? category
          : null;
    } on Object {
      return null;
    }
  }

  CollectionReference<Map<String, dynamic>> _categories(String ownerId) {
    if (ownerId.isEmpty) {
      throw const FinancialCategoryFailure(
        kind: FinancialCategoryFailureKind.unauthenticated,
        safeMessage: 'Sua sessão não está disponível. Entre novamente.',
        code: 'missing_owner_id',
      );
    }
    return _firestore.collection('users').doc(ownerId).collection('categories');
  }

  DocumentReference<Map<String, dynamic>> _document(
    String ownerId,
    String categoryId,
  ) {
    if (categoryId.isEmpty || categoryId.contains('/')) {
      throw const FinancialCategoryFailure(
        kind: FinancialCategoryFailureKind.validation,
        safeMessage: 'A categoria informada não é válida.',
        code: 'invalid_category_id',
      );
    }
    return _categories(ownerId).doc(categoryId);
  }

  FinancialCategoryFailure _mapAndRecord({
    required String operation,
    required String stage,
    required Object error,
  }) {
    final FinancialCategoryFailure failure = mapFailure(error);
    _diagnostics.record(
      operation: operation,
      stage: stage,
      category: failure.kind.name,
      error: error,
      firestoreCode: error is FirebaseException ? error.code : failure.code,
    );
    return failure;
  }

  @visibleForTesting
  static FinancialCategoryFailure mapFailure(Object error) {
    if (error is FinancialCategoryFailure) {
      return error;
    }
    if (error is FirebaseException) {
      return switch (error.code) {
        'permission-denied' => const FinancialCategoryFailure(
          kind: FinancialCategoryFailureKind.permissionDenied,
          safeMessage:
              'Não foi possível acessar suas categorias com segurança.',
          code: 'permission-denied',
        ),
        'unauthenticated' => const FinancialCategoryFailure(
          kind: FinancialCategoryFailureKind.unauthenticated,
          safeMessage: 'Sua sessão não está disponível. Entre novamente.',
          code: 'unauthenticated',
        ),
        'unavailable' => const FinancialCategoryFailure(
          kind: FinancialCategoryFailureKind.unavailable,
          safeMessage: 'Verifique sua conexão e tente novamente.',
          code: 'unavailable',
        ),
        'deadline-exceeded' => const FinancialCategoryFailure(
          kind: FinancialCategoryFailureKind.timeout,
          safeMessage: 'A operação demorou demais. Tente novamente.',
          code: 'deadline-exceeded',
        ),
        'aborted' => const FinancialCategoryFailure(
          kind: FinancialCategoryFailureKind.aborted,
          safeMessage:
              'A categoria foi alterada em outro lugar. Tente novamente.',
          code: 'aborted',
        ),
        'failed-precondition' => const FinancialCategoryFailure(
          kind: FinancialCategoryFailureKind.failedPrecondition,
          safeMessage: 'Não foi possível confirmar a alteração com segurança.',
          code: 'failed-precondition',
        ),
        'not-found' => const FinancialCategoryFailure(
          kind: FinancialCategoryFailureKind.notFound,
          safeMessage: 'Esta categoria não foi encontrada.',
          code: 'not-found',
        ),
        'already-exists' => const FinancialCategoryFailure(
          kind: FinancialCategoryFailureKind.alreadyExists,
          safeMessage: 'Esta categoria já existe.',
          code: 'already-exists',
        ),
        'data-loss' => const FinancialCategoryFailure(
          kind: FinancialCategoryFailureKind.dataLoss,
          safeMessage: 'Encontramos uma inconsistência nesta categoria.',
          code: 'data-loss',
        ),
        _ => const FinancialCategoryFailure(
          kind: FinancialCategoryFailureKind.unknown,
          safeMessage: 'Não foi possível concluir a operação. Tente novamente.',
          code: 'unknown_firestore_error',
        ),
      };
    }
    return const FinancialCategoryFailure(
      kind: FinancialCategoryFailureKind.unknown,
      safeMessage: 'Não foi possível concluir a operação. Tente novamente.',
      code: 'unknown_category_error',
    );
  }

  static bool _isUncertain(Object error) => switch (mapFailure(error).kind) {
    FinancialCategoryFailureKind.unavailable ||
    FinancialCategoryFailureKind.timeout ||
    FinancialCategoryFailureKind.aborted => true,
    _ => false,
  };
}

final class CategoryDocumentData {
  const CategoryDocumentData({required this.id, required this.data});

  final String id;
  final Map<String, dynamic> data;
}
