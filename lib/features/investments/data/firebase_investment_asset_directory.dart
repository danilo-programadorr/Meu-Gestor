import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_asset_directory.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_failure.dart';

typedef InvestmentAssetDirectoryInvoker =
    Future<Object?> Function(Map<String, Object> data);

final class FirebaseInvestmentAssetDirectory
    implements InvestmentAssetDirectory {
  FirebaseInvestmentAssetDirectory({required FirebaseFunctions functions})
    : this.withInvoker(
        invoker: (Map<String, Object> data) async {
          final HttpsCallableResult<Object?> response = await functions
              .httpsCallable(callableName)
              .call<Object?>(data);
          return response.data;
        },
      );

  @visibleForTesting
  FirebaseInvestmentAssetDirectory.withInvoker({
    required InvestmentAssetDirectoryInvoker invoker,
    Duration timeout = callableTimeout,
  }) : _invoker = invoker,
       _timeout = timeout;

  static const String callableName = 'searchInvestmentAssets';
  static const String callableRegion = 'southamerica-east1';
  static const Duration callableTimeout = Duration(seconds: 8);

  final InvestmentAssetDirectoryInvoker _invoker;
  final Duration _timeout;

  @override
  Future<List<InvestmentAssetDirectoryEntry>> search(String query) async {
    final String normalized = query.trim().toUpperCase();
    if (normalized.length < 2) return const <InvestmentAssetDirectoryEntry>[];
    try {
      final Object? data = await _invoker(<String, Object>{
        'query': normalized,
      }).timeout(_timeout);
      if (data is! Map<Object?, Object?> ||
          data.keys.toSet().difference(<Object?>{
            'schemaVersion',
            'results',
          }).isNotEmpty ||
          data.length != 2 ||
          data['schemaVersion'] != 1 ||
          data['results'] is! List<Object?>) {
        throw const InvestmentFailure(
          kind: InvestmentFailureKind.incompatible,
          safeMessage: 'O catálogo de ativos retornou uma resposta inválida.',
          code: 'investment_asset_directory_invalid_response',
        );
      }
      return List<InvestmentAssetDirectoryEntry>.unmodifiable(
        (data['results']! as List<Object?>).map((Object? item) {
          if (item is! Map<Object?, Object?>) {
            throw const InvestmentFailure(
              kind: InvestmentFailureKind.incompatible,
              safeMessage: 'O catálogo de ativos retornou dados inválidos.',
              code: 'investment_asset_directory_invalid_result',
            );
          }
          return InvestmentAssetDirectoryEntry.fromMap(item);
        }),
      );
    } on InvestmentFailure {
      rethrow;
    } on FirebaseFunctionsException {
      throw const InvestmentFailure(
        kind: InvestmentFailureKind.unavailable,
        safeMessage:
            'Não foi possível consultar o catálogo agora. Tente novamente.',
        code: 'investment_asset_directory_unavailable',
      );
    } on TimeoutException {
      throw const InvestmentFailure(
        kind: InvestmentFailureKind.unavailable,
        safeMessage:
            'Não foi possível consultar o catálogo agora. Tente novamente.',
        code: 'investment_asset_directory_unavailable',
      );
    } on Object {
      throw const InvestmentFailure(
        kind: InvestmentFailureKind.unavailable,
        safeMessage:
            'Não foi possível consultar o catálogo agora. Tente novamente.',
        code: 'investment_asset_directory_unavailable',
      );
    }
  }
}
