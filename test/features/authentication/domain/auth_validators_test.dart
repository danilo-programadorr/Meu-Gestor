import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/authentication/domain/auth_validators.dart';
import 'package:meu_gestor_financeiro/features/authentication/domain/email_masker.dart';

void main() {
  group('AuthValidators', () {
    test('valida email obrigatório e formato', () {
      expect(AuthValidators.email(''), 'Informe seu email.');
      expect(AuthValidators.email('invalido'), 'Informe um email válido.');
      expect(AuthValidators.email('pessoa@exemplo.com'), isNull);
    });

    test('valida requisitos mínimos da senha', () {
      expect(AuthValidators.strongPassword(''), 'Informe sua senha.');
      expect(AuthValidators.strongPassword('abcdefgh'), isNotNull);
      expect(AuthValidators.strongPassword('Abcdefg1'), isNull);
    });

    test('valida confirmação idêntica', () {
      expect(
        AuthValidators.passwordConfirmation('Outra1A', 'Correta1A'),
        'As senhas não são iguais.',
      );
      expect(
        AuthValidators.passwordConfirmation('Correta1A', 'Correta1A'),
        isNull,
      );
    });

    test('limita nome completo', () {
      expect(AuthValidators.name(''), 'Informe seu nome completo.');
      expect(AuthValidators.name('A'), 'Informe um nome válido.');
      expect(AuthValidators.name('Ana Silva'), isNull);
    });
  });

  group('EmailMasker', () {
    test('mascara endereço sem exibir email completo', () {
      expect(EmailMasker.mask('pessoa@exemplo.com'), 'p***@e***.com');
    });

    test('usa descrição segura quando o endereço é inválido', () {
      expect(EmailMasker.mask(null), 'seu endereço de email');
      expect(EmailMasker.mask('invalido'), 'seu endereço de email');
    });
  });
}
