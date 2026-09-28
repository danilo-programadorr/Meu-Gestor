// Intenção: selecionar uma voz feminina pt-BR satisfatória sem depender de
// rede, instalação de pacote ou nomenclatura fora do catálogo nativo.
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/assistant/data/assistant_tts_engine.dart';

void main() {
  test('prioriza voz feminina pt-BR local e de maior qualidade', () {
    final Map<String, String>? selected = AssistantTtsVoiceSelector.select(
      <Map<String, String>>[
        <String, String>{
          'name': 'pt-br-x-afs#female_1-network',
          'locale': 'pt-BR',
          'quality': 'very high',
          'network_required': '1',
        },
        <String, String>{
          'name': 'pt-br-x-afs#female_1-local',
          'locale': 'pt_BR',
          'quality': 'high',
          'network_required': '0',
        },
        <String, String>{
          'name': 'pt-br-x-afs#female_2-local',
          'locale': 'pt-BR',
          'quality': 'normal',
          'network_required': '0',
        },
      ],
    );

    expect(selected, <String, String>{
      'name': 'pt-br-x-afs#female_1-local',
      'locale': 'pt-BR',
    });
  });

  test('não confunde voz masculina, outro idioma ou nome sem gênero', () {
    final Map<String, String>? selected = AssistantTtsVoiceSelector.select(
      <Map<String, String>>[
        <String, String>{'name': 'pt-br-x-ptd#male_1-local', 'locale': 'pt-BR'},
        <String, String>{'name': 'pt-br-default-local', 'locale': 'pt-BR'},
        <String, String>{'name': 'en-us-female-local', 'locale': 'en-US'},
      ],
    );

    expect(selected, isNull);
  });

  test('não força voz de rede quando não existe opção feminina local', () {
    final Map<String, String>? selected = AssistantTtsVoiceSelector.select(
      <Map<String, String>>[
        <String, String>{
          'name': 'pt-br-x-afs#female_1-network',
          'locale': 'pt-BR',
          'quality': 'very high',
          'network_required': '1',
        },
      ],
    );

    expect(selected, isNull);
  });

  test('entrada nativa malformada mantém fallback sem exceção', () {
    expect(AssistantTtsVoiceSelector.select(null), isNull);
    expect(
      AssistantTtsVoiceSelector.select(<Object?>[
        null,
        'voz',
        <String, String>{},
      ]),
      isNull,
    );
  });
}
