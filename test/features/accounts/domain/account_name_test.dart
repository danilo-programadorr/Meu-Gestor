import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/core/errors/app_exception.dart';
import 'package:meu_gestor_financeiro/features/accounts/domain/account_name.dart';

void main() {
  group('AccountName', () {
    test('normaliza espaços externos e repetidos', () {
      expect(AccountName.normalize('  Conta   principal  '), 'Conta principal');
    });

    for (final String value in <String>[
      'Conta principal',
      'Nubank',
      'Dinheiro da carteira',
      'Poupança',
      'Investimentos',
      'Conta 2',
    ]) {
      test('aceita nome válido: $value', () {
        expect(AccountName.validate(value), isNull);
      });
    }

    test('rejeita vazio, curto e longo', () {
      expect(AccountName.validate(''), isNotNull);
      expect(AccountName.validate('A'), isNotNull);
      expect(
        AccountName.validate(List<String>.filled(61, 'A').join()),
        isNotNull,
      );
    });

    test('rejeita caracteres de controle', () {
      expect(AccountName.validate('Conta\u0007principal'), isNotNull);
      expect(AccountName.validate('Conta\nprincipal'), isNotNull);
      expect(AccountName.validate('Conta\tprincipal'), isNotNull);
    });

    test('requireValid lança erro tipado', () {
      expect(
        () => AccountName.requireValid('A'),
        throwsA(isA<ValidationException>()),
      );
    });
  });
}
