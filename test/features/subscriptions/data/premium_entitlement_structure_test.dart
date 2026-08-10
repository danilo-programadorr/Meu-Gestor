import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cliente Premium contém somente operações de leitura', () {
    final String source = File(
      'lib/features/subscriptions/data/firebase_premium_entitlement_repository.dart',
    ).readAsStringSync();
    expect(source, contains('Source.server'));
    expect(source, contains('hasPendingWrites'));
    expect(source, isNot(contains('.set(')));
    expect(source, isNot(contains('.update(')));
    expect(source, isNot(contains('.delete(')));
    expect(source, isNot(contains('runTransaction')));
  });

  test(
    'providers Premium não são consumidos pela interface ou investimentos',
    () {
      final List<File> dartFiles = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((File file) => file.path.endsWith('.dart'))
          .toList();
      final List<String> consumers = dartFiles
          .where(
            (File file) =>
                !file.path.endsWith('premium_entitlement_providers.dart') &&
                file.readAsStringSync().contains(
                  'premium_entitlement_providers.dart',
                ),
          )
          .map((File file) => file.path)
          .toList();
      expect(consumers, isEmpty);
    },
  );
}
