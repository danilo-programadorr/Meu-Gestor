import 'assistant_context.dart';
import 'assistant_failure.dart';

enum AssistantGroundedResponseStatus { grounded, safeUnavailable }

final class AssistantResponseEvidenceReference {
  AssistantResponseEvidenceReference({
    required this.alias,
    required this.source,
    required this.period,
  }) {
    if (!RegExp(r'^[a-z][a-z0-9_]{2,63}$').hasMatch(alias)) {
      throw const AssistantFailure(AssistantFailureKind.invalidContext);
    }
  }

  final String alias;
  final AssistantContextSource source;
  final AssistantCivilPeriod period;
}

final class AssistantGroundedAssertion {
  AssistantGroundedAssertion({
    required this.statement,
    required this.evidence,
  }) {
    if (!AssistantContentSafety.isSafe(statement) ||
        RegExp(
          r'\b(compre|compra|venda|vender|alocar|alocação|pague|receba|cancele|edite|transfira|agende)\b',
          caseSensitive: false,
        ).hasMatch(statement)) {
      throw const AssistantFailure(AssistantFailureKind.invalidContext);
    }
  }

  final String statement;
  final AssistantResponseEvidenceReference evidence;
}

/// Flutter only renders aliases and sources; the backend proves the fact binding.
final class AssistantGroundedResponse {
  AssistantGroundedResponse({
    required this.status,
    required this.answer,
    required this.assertions,
    required this.missingData,
    required this.disclaimer,
  }) {
    if (!AssistantContentSafety.isSafe(answer) ||
        !AssistantContentSafety.isSafe(disclaimer) ||
        (status == AssistantGroundedResponseStatus.grounded &&
            assertions.isEmpty) ||
        (status == AssistantGroundedResponseStatus.safeUnavailable &&
            assertions.isNotEmpty) ||
        missingData.any(
          (String item) => !RegExp(r'^[a-z][a-z0-9_]{2,63}$').hasMatch(item),
        )) {
      throw const AssistantFailure(AssistantFailureKind.invalidContext);
    }
  }

  final AssistantGroundedResponseStatus status;
  final String answer;
  final List<AssistantGroundedAssertion> assertions;
  final List<String> missingData;
  final String disclaimer;
}
