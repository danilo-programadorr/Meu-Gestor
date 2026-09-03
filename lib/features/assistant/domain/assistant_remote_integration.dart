import 'assistant_context.dart';
import 'assistant_failure.dart';
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

/// Resposta mínima da borda remota. Ela não transporta texto, contexto ou
/// identificadores: enquanto o provedor estiver desligado, só pode informar a
/// indisponibilidade segura prevista no contrato.
final class AssistantRemoteResponse {
  const AssistantRemoteResponse._();

  static const String safeUnavailableStatus = 'safe_unavailable';

  static const AssistantRemoteResponse safeUnavailable =
      AssistantRemoteResponse._();

  static AssistantRemoteResponse fromCallableData(Object? value) {
    if (value is! Map<Object?, Object?>) {
      throw const AssistantFailure(AssistantFailureKind.unavailable);
    }
    final Map<Object?, Object?> data = value;
    if (data.length != 2 ||
        data['status'] != safeUnavailableStatus ||
        data['contractVersion'] != AssistantRemoteRequest.contractVersion) {
      throw const AssistantFailure(AssistantFailureKind.unavailable);
    }
    return safeUnavailable;
  }

  String get safeMessage =>
      'O Assistente Financeiro está indisponível no momento. '
      'Nenhuma pergunta foi respondida por um provedor externo.';
}

/// This remains false in every Flutter build until a separate server-side
/// activation is approved. It is not a remotely configurable client switch.
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
