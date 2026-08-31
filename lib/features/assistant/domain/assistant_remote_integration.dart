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
  Future<AssistantAnswer> ask(AssistantRemoteRequest request);
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
