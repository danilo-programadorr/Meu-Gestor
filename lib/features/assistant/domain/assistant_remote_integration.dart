// Responsabilidade: define o contrato mínimo entre Flutter e a borda remota,
// sem permitir identidade, contexto, modelo ou credencial do cliente.
import 'package:meu_gestor_financeiro/core/environment/app_environment.dart';

import 'assistant_context.dart';
import 'assistant_failure.dart';
import 'assistant_grounded_response.dart';
import 'assistant_repository.dart';

/// Contrato mínimo para a futura borda server-side. O cliente nunca envia UID,
/// e-mail, consentimento, contexto financeiro, modelo ou credenciais.
final class AssistantRemoteRequest {
  AssistantRemoteRequest({required String message, this.continuation})
    : message = message.trim() {
    if (message.length < 2 ||
        message.length > 2000 ||
        !AssistantContentSafety.isSafe(message)) {
      throw const AssistantFailure(AssistantFailureKind.invalidRequest);
    }
  }

  static const String contractVersion = 'assist-remote-v1';
  final String message;
  final AssistantRemoteContinuation? continuation;
}

/// Contexto conversacional efêmero e não autoritativo para um único pedido de
/// esclarecimento. Identidade e fatos financeiros continuam server-side.
final class AssistantRemoteContinuation {
  AssistantRemoteContinuation({
    required this.intent,
    required this.clarificationCode,
    required String previousMessage,
  }) : previousMessage = previousMessage.trim() {
    if (!_intents.contains(intent) ||
        !_clarificationQuestions.containsKey(clarificationCode) ||
        this.previousMessage.length < 2 ||
        this.previousMessage.length > 2000 ||
        !AssistantContentSafety.isSafe(this.previousMessage)) {
      throw const AssistantFailure(AssistantFailureKind.invalidRequest);
    }
  }

  final String intent;
  final String clarificationCode;
  final String previousMessage;

  static const Set<String> _intents = <String>{
    'unknown',
    'financial_overview',
    'balance',
    'income',
    'expenses',
    'commitments',
    'investments',
    'comparison',
    'cash_flow',
    'explanation',
  };

  static const Map<String, String> _clarificationQuestions = <String, String>{
    'intent_ambiguous': 'O que você gostaria de consultar nas suas finanças?',
    'period_required': 'Qual período você quer analisar?',
    'scope_required': 'Qual parte das suas finanças você quer incluir?',
    'comparison_basis_required': 'O que você quer comparar e com qual período?',
  };
}

final class AssistantRemoteClarification {
  const AssistantRemoteClarification({
    required this.intent,
    required this.clarificationCode,
    required this.question,
  });

  final String intent;
  final String clarificationCode;
  final String question;
}

abstract interface class AssistantRemoteGateway {
  Future<AssistantRemoteResponse> ask(AssistantRemoteRequest request);
}

/// Resposta estrita da borda remota. A resposta fundamentada leva apenas
/// texto seguro, aliases efêmeros, fonte e período civil já validados.
final class AssistantRemoteResponse {
  const AssistantRemoteResponse._({this.groundedResponse, this.clarification});

  static const String safeUnavailableStatus = 'safe_unavailable';

  static const AssistantRemoteResponse safeUnavailable =
      AssistantRemoteResponse._();

  final AssistantGroundedResponse? groundedResponse;
  final AssistantRemoteClarification? clarification;

  bool get isGrounded => groundedResponse != null;
  bool get requiresClarification => clarification != null;

  static AssistantRemoteResponse fromCallableData(Object? value) {
    try {
      if (value is! Map<Object?, Object?>) _unavailable();
      final Map<Object?, Object?> data = value;
      if (_hasExactKeys(data, const <String>['status', 'contractVersion']) &&
          data['status'] == safeUnavailableStatus &&
          data['contractVersion'] == AssistantRemoteRequest.contractVersion) {
        return safeUnavailable;
      }
      if (_hasExactKeys(data, const <String>[
            'status',
            'contractVersion',
            'intent',
            'clarificationCode',
            'question',
          ]) &&
          data['status'] == 'clarification_required' &&
          data['contractVersion'] == AssistantRemoteRequest.contractVersion) {
        final String intent = _string(data['intent']);
        final String code = _string(data['clarificationCode']);
        final String question = _string(data['question']);
        if (!AssistantRemoteContinuation._intents.contains(intent) ||
            AssistantRemoteContinuation._clarificationQuestions[code] !=
                question) {
          _unavailable();
        }
        return AssistantRemoteResponse._(
          clarification: AssistantRemoteClarification(
            intent: intent,
            clarificationCode: code,
            question: question,
          ),
        );
      }
      if (!_hasExactKeys(data, const <String>[
        'schemaVersion',
        'status',
        'answer',
        'assertions',
        'missingData',
        'disclaimer',
      ])) {
        _unavailable();
      }
      if (data['schemaVersion'] != 1 || data['status'] != 'grounded') {
        _unavailable();
      }
      return AssistantRemoteResponse._(
        groundedResponse: AssistantGroundedResponse(
          status: AssistantGroundedResponseStatus.grounded,
          answer: _string(data['answer']),
          assertions: _assertions(data['assertions']),
          missingData: _missingData(data['missingData']),
          disclaimer: _string(data['disclaimer']),
        ),
      );
    } on AssistantFailure {
      throw const AssistantFailure(AssistantFailureKind.unavailable);
    } on Object {
      throw const AssistantFailure(AssistantFailureKind.unavailable);
    }
  }

  static bool _hasExactKeys(Map<Object?, Object?> data, List<String> keys) =>
      data.length == keys.length && data.keys.every(keys.contains);

  static Never _unavailable() =>
      throw const AssistantFailure(AssistantFailureKind.unavailable);

  static String _string(Object? value) {
    if (value is! String) _unavailable();
    return value;
  }

  static List<String> _missingData(Object? value) {
    if (value is! List<Object?> ||
        value.any((Object? item) => item is! String)) {
      _unavailable();
    }
    return List<String>.unmodifiable(value.cast<String>());
  }

  static List<AssistantGroundedAssertion> _assertions(Object? value) {
    if (value is! List<Object?> || value.isEmpty) _unavailable();
    return List<AssistantGroundedAssertion>.unmodifiable(value.map(_assertion));
  }

  static AssistantGroundedAssertion _assertion(Object? value) {
    if (value is! Map<Object?, Object?> ||
        !_hasExactKeys(value, const <String>['statement', 'evidence'])) {
      _unavailable();
    }
    final Object? rawEvidence = value['evidence'];
    if (rawEvidence is! Map<Object?, Object?> ||
        !_hasExactKeys(rawEvidence, const <String>[
          'alias',
          'source',
          'period',
        ])) {
      _unavailable();
    }
    final Object? rawPeriod = rawEvidence['period'];
    if (rawPeriod is! Map<Object?, Object?> ||
        !_hasExactKeys(rawPeriod, const <String>[
          'timeZone',
          'startDate',
          'endDateExclusive',
        ])) {
      _unavailable();
    }
    final Object? rawSource = rawEvidence['source'];
    final AssistantContextSource? source = rawSource is String
        ? AssistantContextSource.values
              .where((AssistantContextSource item) => item.name == rawSource)
              .firstOrNull
        : null;
    if (source == null) _unavailable();
    return AssistantGroundedAssertion(
      statement: _string(value['statement']),
      evidence: AssistantResponseEvidenceReference(
        alias: _string(rawEvidence['alias']),
        source: source,
        period: AssistantCivilPeriod(
          timeZone: _string(rawPeriod['timeZone']),
          startDate: _string(rawPeriod['startDate']),
          endDateExclusive: _string(rawPeriod['endDateExclusive']),
        ),
      ),
    );
  }

  String get safeMessage =>
      'O Assistente Financeiro está indisponível no momento. '
      'Nenhuma pergunta foi respondida por um provedor externo.';
}

/// Mantém a chamada remota impossível por padrão. Somente um APK development
/// explicitamente compilado com a flag local pode ativar a borda Flutter;
/// production continua fechada mesmo se a flag for informada por engano.
abstract final class AssistantRemoteIntegrationPolicy {
  static const bool _developmentBuild =
      String.fromEnvironment(
        'APP_ENV',
        defaultValue: AppEnvironment.developmentValue,
      ) ==
      AppEnvironment.developmentValue;

  static const bool realCallsEnabled =
      _developmentBuild &&
      bool.fromEnvironment('ASSISTANT_REMOTE_ENABLED', defaultValue: false);
}

/// Fail-closed implementation used by the app while no protected backend edge
/// exists. It deliberately has no gateway dependency, so it cannot send data.
final class DisabledAssistantRemoteRepository implements AssistantRepository {
  const DisabledAssistantRemoteRepository();

  @override
  Future<AssistantAnswer> ask({required String message}) async {
    AssistantRemoteRequest(message: message);
    throw const AssistantFailure(AssistantFailureKind.unavailable);
  }
}
