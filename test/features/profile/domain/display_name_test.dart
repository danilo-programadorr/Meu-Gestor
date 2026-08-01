import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/core/errors/app_exception.dart';
import 'package:meu_gestor_financeiro/features/profile/domain/display_name.dart';

void main() {
  group('DisplayName', () {
    test('normaliza espaços externos e repetidos', () {
      expect(DisplayName.normalize('  Pessoa   Teste  '), 'Pessoa Teste');
    });

    test('aceita nome válido nos limites', () {
      expect(DisplayName.validate('AB'), isNull);
      expect(DisplayName.validate(List<String>.filled(80, 'A').join()), isNull);
    });

    test('rejeita nome curto, longo e caracteres de controle', () {
      expect(DisplayName.validate('A'), isNotNull);
      expect(
        DisplayName.validate(List<String>.filled(81, 'A').join()),
        isNotNull,
      );
      expect(DisplayName.validate('Pessoa\u0007Teste'), isNotNull);
    });

    test('requireValid retorna valor normalizado', () {
      expect(DisplayName.requireValid('  Pessoa   Teste '), 'Pessoa Teste');
    });

    test('requireValid lança erro tipado para nome inválido', () {
      expect(
        () => DisplayName.requireValid('A'),
        throwsA(isA<ValidationException>()),
      );
    });
  });
}
