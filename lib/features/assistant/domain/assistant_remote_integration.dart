// Responsabilidade: define o contrato mínimo entre Flutter e a borda remota,
// sem permitir identidade, contexto, modelo ou credencial do cliente.
import 'dart:convert';
import 'dart:typed_data';

import 'package:meu_gestor_financeiro/core/environment/app_environment.dart';

import 'assistant_context.dart';
import 'assistant_failure.dart';
import 'assistant_grounded_response.dart';
import 'assistant_repository.dart';

/// Contrato mínimo para a futura borda server-side. O cliente nunca envia UID,
/// e-mail, consentimento, contexto financeiro, modelo ou credenciais.
final class AssistantRemoteRequest {
  AssistantRemoteRequest({
    required String message,
    this.continuation,
    this.responseMode = AssistantRemoteResponseMode.text,
  }) : message = message.trim() {
    if (message.length < 2 ||
        message.length > 2000 ||
        !AssistantContentSafety.isSafe(message)) {
      throw const AssistantFailure(AssistantFailureKind.invalidRequest);
    }
  }

  static const String contractVersion = 'assist-remote-v1';
  final String message;
  final AssistantRemoteContinuation? continuation;
  final AssistantRemoteResponseMode responseMode;
}

enum AssistantRemoteResponseMode { text, voice }

/// Contexto conversacional efêmero e não autoritativo para até três turnos da
/// pessoa. Identidade, respostas e fatos financeiros continuam exclusivamente
/// no servidor e nunca são reenviados pelo cliente.
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
    'calendar_event',
    'calendar_query',
    'financial_overview',
    'balance',
    'income',
    'expenses',
    'commitments',
    'investments',
    'investment_assets',
    'comparison',
    'cash_flow',
    'explanation',
  };

  static const Map<String, String> _clarificationQuestions = <String, String>{
    'social_conversation':
        'Eu sou a Luma, sua assistente financeira. Posso consultar e explicar seus dados autorizados, comparar períodos e mostrar compromissos e investimentos. O que você quer saber?',
    'intent_ambiguous': 'Me conta: o que você quer ver nas suas finanças?',
    'calendar_title_required': 'Qual é o nome do compromisso?',
    'calendar_time_required':
        'Para qual dia e horário devo preparar o compromisso?',
    'period_required': 'Qual período você quer olhar?',
    'scope_required': 'Que parte das suas finanças você quer consultar?',
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

/// Proposta efêmera criada pelo backend. Ela não contém calendário escolhido
/// e nunca autoriza escrita sem a confirmação fresca feita no aparelho.
final class AssistantCalendarEventProposal {
  AssistantCalendarEventProposal({
    required this.proposalId,
    required this.previewDigest,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    required this.expiresAt,
  }) {
    if (proposalId.trim().length < 16 ||
        previewDigest.trim().length < 16 ||
        title != title.trim() ||
        title.length < 2 ||
        title.length > 120 ||
        !startsAt.isUtc ||
        !endsAt.isUtc ||
        !expiresAt.isUtc ||
        !startsAt.isBefore(endsAt) ||
        endsAt.difference(startsAt) < const Duration(minutes: 5) ||
        endsAt.difference(startsAt) > const Duration(hours: 24)) {
      AssistantRemoteResponse._unavailable();
    }
  }

  final String proposalId;
  final String previewDigest;
  final String title;
  final DateTime startsAt;
  final DateTime endsAt;
  final DateTime expiresAt;
}

/// Solicitação opaca para leitura local. Somente o intervalo atravessa a
/// callable; eventos e títulos permanecem no aparelho.
final class AssistantCalendarQueryRequest {
  AssistantCalendarQueryRequest({
    required this.queryId,
    required this.startsAt,
    required this.endsAt,
    required this.expiresAt,
  }) {
    if (queryId.trim().length < 16 ||
        !startsAt.isUtc ||
        !endsAt.isUtc ||
        !expiresAt.isUtc ||
        !startsAt.isBefore(endsAt) ||
        endsAt.difference(startsAt) > const Duration(days: 31)) {
      AssistantRemoteResponse._unavailable();
    }
  }

  final String queryId;
  final DateTime startsAt;
  final DateTime endsAt;
  final DateTime expiresAt;
}

/// Áudio efêmero já validado e sintetizado pelo backend. O cliente aceita
/// somente WAV pequeno e não persiste o conteúdo fora do cache nativo.
final class AssistantRemoteAudio {
  const AssistantRemoteAudio._({required this.bytes});

  final Uint8List bytes;

  static AssistantRemoteAudio fromCallableData(Object? value) {
    if (value is! Map<Object?, Object?> ||
        !AssistantRemoteResponse._hasExactKeys(value, const <String>[
          'mimeType',
          'dataBase64',
        ]) ||
        value['mimeType'] != 'audio/wav' ||
        value['dataBase64'] is! String) {
      AssistantRemoteResponse._unavailable();
    }
    final Uint8List bytes;
    try {
      bytes = base64Decode(value['dataBase64']! as String);
    } on FormatException {
      AssistantRemoteResponse._unavailable();
    }
    if (bytes.length < 524 ||
        bytes.length > 4000044 ||
        ascii.decode(bytes.sublist(0, 4), allowInvalid: true) != 'RIFF' ||
        ascii.decode(bytes.sublist(8, 12), allowInvalid: true) != 'WAVE') {
      AssistantRemoteResponse._unavailable();
    }
    return AssistantRemoteAudio._(bytes: bytes);
  }
}

abstract interface class AssistantRemoteGateway {
  Future<AssistantRemoteResponse> ask(AssistantRemoteRequest request);
}

/// Resposta estrita da borda remota. A resposta fundamentada leva apenas
/// texto seguro, aliases efêmeros, fonte e período civil já validados.
final class AssistantRemoteResponse {
  const AssistantRemoteResponse._({
    this.groundedResponse,
    this.clarification,
    this.calendarEventProposal,
    this.calendarQueryRequest,
    this.audio,
  });

  static const String safeUnavailableStatus = 'safe_unavailable';

  static const AssistantRemoteResponse safeUnavailable =
      AssistantRemoteResponse._();

  final AssistantGroundedResponse? groundedResponse;
  final AssistantRemoteClarification? clarification;
  final AssistantCalendarEventProposal? calendarEventProposal;
  final AssistantCalendarQueryRequest? calendarQueryRequest;
  final AssistantRemoteAudio? audio;

  bool get isGrounded => groundedResponse != null;
  bool get requiresClarification => clarification != null;
  bool get proposesCalendarEvent => calendarEventProposal != null;
  bool get requestsCalendarQuery => calendarQueryRequest != null;

  static AssistantRemoteResponse fromCallableData(Object? value) {
    try {
      if (value is! Map<Object?, Object?>) _unavailable();
      final Map<Object?, Object?> data = value;
      final bool hasAudio = data.containsKey('audio');
      if (_hasExactKeys(data, <String>[
            'status',
            'contractVersion',
            if (hasAudio) 'audio',
          ]) &&
          data['status'] == safeUnavailableStatus &&
          data['contractVersion'] == AssistantRemoteRequest.contractVersion) {
        return hasAudio
            ? AssistantRemoteResponse._(
                audio: AssistantRemoteAudio.fromCallableData(data['audio']),
              )
            : safeUnavailable;
      }
      if (_hasExactKeys(data, <String>[
            'status',
            'contractVersion',
            'intent',
            'clarificationCode',
            'question',
            if (hasAudio) 'audio',
          ]) &&
          data['status'] == 'clarification_required' &&
          data['contractVersion'] == AssistantRemoteRequest.contractVersion) {
        final String intent = _string(data['intent']);
        final String code = _string(data['clarificationCode']);
        final String question = _string(data['question']);
        if (!AssistantRemoteContinuation._intents.contains(intent) ||
            !AssistantRemoteContinuation._clarificationQuestions.containsKey(
              code,
            ) ||
            !_isSafeClarificationQuestion(question)) {
          _unavailable();
        }
        return AssistantRemoteResponse._(
          clarification: AssistantRemoteClarification(
            intent: intent,
            clarificationCode: code,
            question: question,
          ),
          audio: hasAudio
              ? AssistantRemoteAudio.fromCallableData(data['audio'])
              : null,
        );
      }
      if (_hasExactKeys(data, <String>[
            'status',
            'contractVersion',
            'action',
            'proposalId',
            'previewDigest',
            'title',
            'startsAt',
            'endsAt',
            'expiresAt',
            if (hasAudio) 'audio',
          ]) &&
          data['status'] == 'action_proposal' &&
          data['contractVersion'] == AssistantRemoteRequest.contractVersion &&
          data['action'] == 'create_calendar_event') {
        final DateTime startsAt = _utcDate(data['startsAt']);
        final DateTime endsAt = _utcDate(data['endsAt']);
        final DateTime expiresAt = _utcDate(data['expiresAt']);
        return AssistantRemoteResponse._(
          calendarEventProposal: AssistantCalendarEventProposal(
            proposalId: _string(data['proposalId']),
            previewDigest: _string(data['previewDigest']),
            title: _string(data['title']),
            startsAt: startsAt,
            endsAt: endsAt,
            expiresAt: expiresAt,
          ),
          audio: hasAudio
              ? AssistantRemoteAudio.fromCallableData(data['audio'])
              : null,
        );
      }
      if (_hasExactKeys(data, const <String>[
            'status',
            'contractVersion',
            'action',
            'queryId',
            'startsAt',
            'endsAt',
            'expiresAt',
          ]) &&
          data['status'] == 'local_action' &&
          data['contractVersion'] == AssistantRemoteRequest.contractVersion &&
          data['action'] == 'read_calendar_events') {
        return AssistantRemoteResponse._(
          calendarQueryRequest: AssistantCalendarQueryRequest(
            queryId: _string(data['queryId']),
            startsAt: _utcDate(data['startsAt']),
            endsAt: _utcDate(data['endsAt']),
            expiresAt: _utcDate(data['expiresAt']),
          ),
        );
      }
      if (!_hasExactKeys(data, <String>[
        'schemaVersion',
        'status',
        'answer',
        'assertions',
        'missingData',
        'disclaimer',
        if (hasAudio) 'audio',
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
        audio: hasAudio
            ? AssistantRemoteAudio.fromCallableData(data['audio'])
            : null,
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

  static DateTime _utcDate(Object? value) {
    if (value is! String) _unavailable();
    final DateTime? parsed = DateTime.tryParse(value);
    if (parsed == null || !parsed.isUtc) _unavailable();
    return parsed;
  }

  static bool _isSafeClarificationQuestion(String value) {
    final String trimmed = value.trim();
    return value == trimmed &&
        value.length >= 8 &&
        value.length <= 240 &&
        value.endsWith('?') &&
        !RegExp(r'[\d$]').hasMatch(value) &&
        AssistantContentSafety.isSafe(value);
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
