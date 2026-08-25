import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('matriz CRUD cobre todas as entidades persistentes e efêmeras', () {
    final String matrix = File(
      'docs/architecture/CRUD_ACTION_MATRIX.md',
    ).readAsStringSync();
    const List<String> entityIds = <String>[
      'AUTH',
      'PROFILE',
      'CONSENT',
      'APPEARANCE',
      'ACCOUNT',
      'CATEGORY',
      'TRANSACTION',
      'PAYABLE',
      'RECEIVABLE',
      'INV_PORTFOLIO',
      'INV_ASSET',
      'INV_OPERATION',
      'INV_INCOME',
      'MARKET_QUOTE',
      'CALCULATION',
      'PRIVACY_OPERATION',
      'PRIVACY_LOCK',
      'PRIVACY_RECEIPT',
      'ENTITLEMENT',
      'CLOSED_TEST',
      'OWNER',
    ];
    for (final String entityId in entityIds) {
      expect(matrix, contains('| $entityId |'), reason: entityId);
    }
    for (final String action in <String>[
      'Cadastrar',
      'Visualizar',
      'Editar',
      'Excluir',
      'Arquivar',
      'Cancelar',
      'Anular',
      'Restaurar',
    ]) {
      expect(matrix, contains(action), reason: action);
    }
  });

  test(
    'contratos sensíveis de ativos e ações canônicas permanecem presentes',
    () {
      final String repository = File(
        'lib/features/investments/domain/investment_repository.dart',
      ).readAsStringSync();
      final String asset = File(
        'lib/features/investments/domain/tracked_investment_asset.dart',
      ).readAsStringSync();
      final String actions = File(
        'lib/app/widgets/entity_action_icon_button.dart',
      ).readAsStringSync();
      final String routes = File(
        'lib/app/routing/app_routes.dart',
      ).readAsStringSync();

      expect(repository, contains('updateAsset('));
      expect(repository, contains('setAssetArchived('));
      expect(repository, contains('deleteEmptyAsset('));
      expect(asset, contains('hasHistory'));
      expect(actions, contains('tooltip: label'));
      expect(actions, contains('Icons.edit_outlined'));
      expect(actions, contains('Icons.delete_outline_rounded'));
      expect(routes, contains('editInvestmentAsset'));
    },
  );
}
