import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_entitlement.dart';

enum PremiumEntitlementPresence { present, absent }

final class PremiumEntitlementReadResult {
  const PremiumEntitlementReadResult._({
    required this.presence,
    required this.entitlement,
    required this.isFromServer,
    required this.hasPendingWrites,
  });

  factory PremiumEntitlementReadResult.present({
    required PremiumEntitlement entitlement,
    required bool isFromServer,
    required bool hasPendingWrites,
  }) => PremiumEntitlementReadResult._(
    presence: PremiumEntitlementPresence.present,
    entitlement: entitlement,
    isFromServer: isFromServer,
    hasPendingWrites: hasPendingWrites,
  );

  factory PremiumEntitlementReadResult.absent({
    required bool isFromServer,
    required bool hasPendingWrites,
  }) => PremiumEntitlementReadResult._(
    presence: PremiumEntitlementPresence.absent,
    entitlement: null,
    isFromServer: isFromServer,
    hasPendingWrites: hasPendingWrites,
  );

  final PremiumEntitlementPresence presence;
  final PremiumEntitlement? entitlement;
  final bool isFromServer;
  final bool hasPendingWrites;
}

final class PremiumEntitlementDiagnostic {
  const PremiumEntitlementDiagnostic({
    required this.code,
    required this.isFromServer,
    required this.schemaVersion,
    required this.revision,
  });

  final String code;
  final bool isFromServer;
  final int? schemaVersion;
  final int? revision;

  @override
  String toString() =>
      'PremiumEntitlementDiagnostic($code, server: $isFromServer, '
      'schema: $schemaVersion, revision: $revision)';
}

abstract interface class PremiumEntitlementRepository {
  Future<PremiumEntitlementReadResult> readCurrent({
    required String ownerId,
    required bool serverOnly,
  });

  Stream<PremiumEntitlementReadResult> watchConfirmed({
    required String ownerId,
  });

  Future<PremiumEntitlementReadResult> refreshFromServer({
    required String ownerId,
  });

  Future<PremiumEntitlementDiagnostic> readSanitizedDiagnostic({
    required String ownerId,
  });
}
