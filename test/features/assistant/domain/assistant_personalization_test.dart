import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/assistant/domain/assistant_personalization.dart';

void main() {
  group('assistantSessionGreeting', () {
    test('inclui o tratamento local quando configurado', () {
      expect(
        assistantSessionGreeting('Pessoa'),
        'Oi, Pessoa. O que você quer conversar sobre suas finanças?',
      );
    });

    test('preserva a conversa sem tratamento quando a pessoa recusa nome', () {
      expect(
        assistantSessionGreeting(null),
        'Oi. O que você quer conversar sobre suas finanças?',
      );
    });
  });

  test('Luma usa primeiro nome, apelido normalizado ou nenhum tratamento', () {
    expect(AssistantPersonalization.assistantName, 'Luma');
    expect(
      const AssistantPersonalization.profileFirstName().addressName(
        profileDisplayName: '  Pessoa   Teste ',
      ),
      'Pessoa',
    );
    expect(
      AssistantPersonalization(
        mode: AssistantAddressMode.customName,
        customName: '  Dani  ',
      ).addressName(profileDisplayName: 'Pessoa Teste'),
      'Dani',
    );
    expect(
      const AssistantPersonalization.none().addressName(
        profileDisplayName: 'Pessoa Teste',
      ),
      isNull,
    );
  });

  test('apelido inválido falha antes de persistir', () {
    expect(
      () => AssistantPersonalization(
        mode: AssistantAddressMode.customName,
        customName: 'A',
      ),
      throwsFormatException,
    );
    expect(AssistantPersonalization.validateAddressName('Nome válido'), isNull);
  });
}
