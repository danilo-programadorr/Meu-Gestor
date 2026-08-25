import 'assistant_context.dart';

/// A implementação futura deve usar leitura server-only e montar o contexto
/// pelo UID autenticado; o cliente nunca envia contexto financeiro ao backend.
abstract interface class AssistantContextRepository {
  Future<AssistantFinancialContext> readOwnConfirmedContext();
}

/// Contrato local da experiência. ASSIST-0 não fornece implementação de rede.
abstract interface class AssistantRepository {
  Future<AssistantAnswer> ask({required String message});
}

final class AssistantAnswer {
  AssistantAnswer({
    required this.text,
    required this.evidenceIds,
    required this.missingSources,
  });

  final String text;
  final Set<String> evidenceIds;
  final Set<AssistantContextSource> missingSources;
}
