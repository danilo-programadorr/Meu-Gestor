// Responsabilidade: define o contrato mínimo entre Flutter e a borda remota,
// sem permitir identidade, contexto, modelo ou credencial do cliente.
import 'assistant_context.dart';
import 'assistant_failure.dart';
import 'assistant_grounded_response.dart';
import 'assistant_repository.dart';

/// Contrato mínimo para a futura borda server-side. O cliente nunca envia UID,
/// e-mail, consentimento, contexto financeiro, modelo ou credenciais.
final class AssistantRemoteRequest {
  AssistantRemoteRequest({required String message}) : message = message.trim() {
    if (message.length < 2 ||
        message.length > 2000 ||
        !AssistantContentSafety.isSafe(message)) {
      throw const AssistantFailure(AssistantFailureKind.invalidRequest);
    }
  }

  static const String contractVersion = 'assist-remote-v1';
  final String message;
}

abstract interface class AssistantRemoteGateway {
  Future<AssistantRemoteResponse> ask(AssistantRemoteRequest request);
}

/// Resposta estrita da borda remota. A resposta fundamentada leva apenas
/// texto seguro, aliases efêmeros, fonte e período civil já validados.
final class AssistantRemoteResponse {
  const AssistantRemoteResponse._({this.groundedResponse});

  static const String safeUnavailableStatus = 'safe_unavailable';

  static const AssistantRemoteResponse safeUnavailable =
      AssistantRemoteResponse._();

  final AssistantGroundedResponse? groundedResponse;

  bool get isGrounded => groundedResponse != null;

  static AssistantRemoteResponse fromCallableData(Object? value) {
    try {
      if (value is! Map<Object?, Object?>) _unavailable();
      final Map<Object?, Object?> data = value;
      if (_hasExactKeys(data, const <String>['status', 'contractVersion']) &&
          data['status'] == safeUnavailableStatus &&
          data['contractVersion'] == AssistantRemoteRequest.contractVersion) {
        return safeUnavailable;
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

/// This remains false in every Flutter build until a separate server-side
/// activation is approved. It is not a remotely configurable client switch.
/// Mantém a chamada remota impossível em qualquer build até nova ativação.
abstract final class AssistantRemoteIntegrationPolicy {
  static const bool realCallsEnabled = false;
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
