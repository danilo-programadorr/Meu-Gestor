import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/investments/data/firebase_investment_asset_directory.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_failure.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/tracked_investment_asset.dart';

void main() {
  test(
    'envia somente a consulta normalizada e aceita o contrato atual',
    () async {
      Map<String, Object>? payload;
      final FirebaseInvestmentAssetDirectory directory =
          FirebaseInvestmentAssetDirectory.withInvoker(
            invoker: (Map<String, Object> value) async {
              payload = value;
              return <String, Object>{
                'schemaVersion': 1,
                'results': <Object>[
                  <String, Object>{
                    'ticker': 'VALE3',
                    'name': 'Vale S.A.',
                    'type': 'stock',
                  },
                ],
              };
            },
          );

      final results = await directory.search('  vale  ');

      expect(payload, <String, Object>{'query': 'VALE'});
      expect(results, hasLength(1));
      expect(results.single.ticker, 'VALE3');
      expect(results.single.name, 'Vale S.A.');
      expect(results.single.type, TrackedInvestmentAssetType.stock);
    },
  );

  test('não chama a callable antes de dois caracteres', () async {
    var calls = 0;
    final FirebaseInvestmentAssetDirectory directory =
        FirebaseInvestmentAssetDirectory.withInvoker(
          invoker: (_) async {
            calls += 1;
            return null;
          },
        );

    expect(await directory.search(' p '), isEmpty);
    expect(calls, 0);
  });

  test('rejeita versão, envelope ou item com campo extra', () async {
    for (final Object response in <Object>[
      <String, Object>{'schemaVersion': 2, 'results': <Object>[]},
      <String, Object>{
        'schemaVersion': 1,
        'results': <Object>[],
        'ownerId': 'proibido',
      },
      <String, Object>{
        'schemaVersion': 1,
        'results': <Object>[
          <String, Object>{
            'ticker': 'VALE3',
            'name': 'Vale S.A.',
            'type': 'stock',
            'price': 1,
          },
        ],
      },
    ]) {
      final FirebaseInvestmentAssetDirectory directory =
          FirebaseInvestmentAssetDirectory.withInvoker(
            invoker: (_) async => response,
          );

      await expectLater(
        directory.search('VALE'),
        throwsA(
          isA<InvestmentFailure>().having(
            (InvestmentFailure failure) => failure.kind,
            'kind',
            InvestmentFailureKind.incompatible,
          ),
        ),
      );
    }
  });

  test('timeout falha fechado com mensagem segura', () async {
    final Completer<Object?> pending = Completer<Object?>();
    final FirebaseInvestmentAssetDirectory directory =
        FirebaseInvestmentAssetDirectory.withInvoker(
          invoker: (_) => pending.future,
          timeout: const Duration(milliseconds: 1),
        );

    await expectLater(
      directory.search('VALE'),
      throwsA(
        isA<InvestmentFailure>()
            .having(
              (InvestmentFailure failure) => failure.kind,
              'kind',
              InvestmentFailureKind.unavailable,
            )
            .having(
              (InvestmentFailure failure) => failure.code,
              'code',
              'investment_asset_directory_unavailable',
            ),
      ),
    );
  });
}
