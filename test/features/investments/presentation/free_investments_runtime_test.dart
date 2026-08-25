import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fluxo ativo de investimentos não referencia monetização', () {
    const List<String> activeFiles = <String>[
      'lib/app/routing/app_router.dart',
      'lib/app/routing/app_routes.dart',
      'lib/features/home/presentation/home_dashboard.dart',
      'lib/features/home/presentation/home_page.dart',
      'lib/features/investments/data/investment_providers.dart',
      'lib/features/investments/presentation/controllers/investments_controller.dart',
      'lib/features/investments/presentation/controllers/investment_action_controller.dart',
      'lib/features/investments/presentation/controllers/investment_quotes_controller.dart',
      'lib/features/investments/presentation/pages/investments_page.dart',
      'lib/features/investments/presentation/pages/investment_asset_details_page.dart',
      'lib/features/investments/presentation/pages/investment_tools_page.dart',
      'lib/features/profile/presentation/pages/profile_page.dart',
      'lib/features/privacy/presentation/pages/data_and_privacy_page.dart',
    ];
    const List<String> forbiddenRuntimeReferences = <String>[
      'features/subscriptions/',
      'AppRoutes.premium',
      'activateClosedTestPremium',
      'Premium e assinatura',
      'assinatura Google Play',
      'teste fechado',
    ];

    for (final String path in activeFiles) {
      final String source = File(path).readAsStringSync();
      for (final String forbidden in forbiddenRuntimeReferences) {
        expect(
          source,
          isNot(contains(forbidden)),
          reason: '$path não pode referenciar $forbidden no fluxo ativo.',
        );
      }
    }
  });
}
