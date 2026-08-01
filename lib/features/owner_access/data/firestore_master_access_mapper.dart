import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meu_gestor_financeiro/features/owner_access/domain/app_role.dart';
import 'package:meu_gestor_financeiro/features/owner_access/domain/master_access.dart';
import 'package:meu_gestor_financeiro/features/owner_access/domain/master_access_failure.dart';

abstract final class FirestoreMasterAccessMapper {
  static const Set<String> fieldNames = <String>{
    'role',
    'active',
    'environment',
    'grantedAt',
    'schemaVersion',
  };

  static MasterAccess fromMap(Map<String, dynamic> data) {
    if (data.keys.toSet().difference(fieldNames).isNotEmpty ||
        fieldNames.difference(data.keys.toSet()).isNotEmpty) {
      throw _invalid('owner_access_fields_invalid');
    }

    final Object? role = data['role'];
    final Object? active = data['active'];
    final Object? environment = data['environment'];
    final Object? grantedAt = data['grantedAt'];
    final Object? schemaVersion = data['schemaVersion'];

    if (role is! String ||
        active is! bool ||
        environment is! String ||
        grantedAt is! Timestamp ||
        schemaVersion is! int) {
      throw _invalid('owner_access_types_invalid');
    }
    if (role != 'owner') {
      throw _invalid('owner_access_role_invalid');
    }
    if (environment != MasterAccess.supportedEnvironment) {
      throw _invalid('owner_access_environment_invalid');
    }
    if (schemaVersion != MasterAccess.currentSchemaVersion) {
      throw _invalid('owner_access_schema_invalid');
    }

    return MasterAccess(
      role: AppRole.owner,
      active: active,
      environment: environment,
      grantedAt: grantedAt.toDate().toUtc(),
      schemaVersion: schemaVersion,
    );
  }

  static MasterAccessFailure _invalid(String code) => MasterAccessFailure(
    kind: MasterAccessFailureKind.incompatible,
    safeMessage:
        'A autorização administrativa possui uma configuração incompatível.',
    code: code,
  );
}
