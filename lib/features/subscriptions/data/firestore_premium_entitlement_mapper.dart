import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_capability.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_entitlement.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_entitlement_failure.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_entitlement_source.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_entitlement_status.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_plan.dart';

abstract final class FirestorePremiumEntitlementMapper {
  static const Set<String> _fields = <String>{
    'ownerId',
    'planId',
    'status',
    'source',
    'environment',
    'capabilities',
    'startedAt',
    'currentPeriodStart',
    'currentPeriodEnd',
    'graceUntil',
    'cancelAtPeriodEnd',
    'cancelledAt',
    'expiredAt',
    'revokedAt',
    'refundedAt',
    'lastVerifiedAt',
    'revision',
    'schemaVersion',
    'createdAt',
    'updatedAt',
  };

  static PremiumEntitlement fromMap({
    required Map<String, dynamic> data,
    required String expectedOwnerId,
  }) {
    _requireExactFields(data);
    final String ownerId = _string(data, 'ownerId');
    if (ownerId != expectedOwnerId) {
      throw _failure('premium_owner_mismatch');
    }
    final DateTime createdAt = _date(data, 'createdAt')!;
    final DateTime updatedAt = _date(data, 'updatedAt')!;
    final DateTime lastVerifiedAt = _date(data, 'lastVerifiedAt')!;
    if (updatedAt.isBefore(createdAt) || updatedAt.isBefore(lastVerifiedAt)) {
      throw _failure('invalid_premium_audit_order');
    }
    return PremiumEntitlement.create(
      ownerId: ownerId,
      plan: _enumValue(PremiumPlan.values, _string(data, 'planId'), 'plan'),
      status: _enumValue(
        PremiumEntitlementStatus.values,
        _string(data, 'status'),
        'status',
      ),
      source: _enumValue(
        PremiumEntitlementSource.values,
        _string(data, 'source'),
        'source',
      ),
      environment: _enumValue(
        PremiumEnvironment.values,
        _string(data, 'environment'),
        'environment',
      ),
      capabilities: _capabilities(data['capabilities']),
      entitlementStartedAt: _date(data, 'startedAt', nullable: true),
      currentPeriodStartedAt: _date(data, 'currentPeriodStart', nullable: true),
      currentPeriodEndsAt: _date(data, 'currentPeriodEnd', nullable: true),
      graceUntil: _date(data, 'graceUntil', nullable: true),
      cancelAtPeriodEnd: _boolean(data, 'cancelAtPeriodEnd'),
      cancelledAt: _date(data, 'cancelledAt', nullable: true),
      expiredAt: _date(data, 'expiredAt', nullable: true),
      revokedAt: _date(data, 'revokedAt', nullable: true),
      refundedAt: _date(data, 'refundedAt', nullable: true),
      lastVerifiedAt: lastVerifiedAt,
      revision: _integer(data, 'revision'),
      schemaVersion: _integer(data, 'schemaVersion'),
    );
  }

  static void _requireExactFields(Map<String, dynamic> data) {
    if (data.keys.toSet().difference(_fields).isNotEmpty ||
        _fields.difference(data.keys.toSet()).isNotEmpty) {
      throw _failure('invalid_premium_fields');
    }
  }

  static String _string(Map<String, dynamic> data, String field) {
    final Object? value = data[field];
    if (value is! String || value.isEmpty || value.trim() != value) {
      throw _failure('invalid_premium_$field');
    }
    return value;
  }

  static bool _boolean(Map<String, dynamic> data, String field) {
    final Object? value = data[field];
    if (value is! bool) throw _failure('invalid_premium_$field');
    return value;
  }

  static int _integer(Map<String, dynamic> data, String field) {
    final Object? value = data[field];
    if (value is! int) throw _failure('invalid_premium_$field');
    return value;
  }

  static DateTime? _date(
    Map<String, dynamic> data,
    String field, {
    bool nullable = false,
  }) {
    final Object? value = data[field];
    if (nullable && value == null) return null;
    if (value is! Timestamp) throw _failure('invalid_premium_$field');
    return value.toDate().toUtc();
  }

  static List<PremiumCapability> _capabilities(Object? value) {
    if (value is! List<dynamic>) {
      throw _failure('invalid_premium_capabilities');
    }
    final List<PremiumCapability> result = value
        .map(
          (dynamic item) => item is String
              ? _enumValue(PremiumCapability.values, item, 'capability')
              : throw _failure('invalid_premium_capability'),
        )
        .toList(growable: false);
    if (result.toSet().length != result.length) {
      throw _failure('duplicated_premium_capability');
    }
    return result;
  }

  static T _enumValue<T extends Enum>(
    Iterable<T> values,
    String name,
    String field,
  ) {
    for (final T value in values) {
      if (value.name == name) return value;
    }
    throw _failure('unknown_premium_$field');
  }

  static PremiumEntitlementFailure _failure(String code) =>
      PremiumEntitlementFailure(
        kind: PremiumEntitlementFailureKind.inconsistentData,
        safeMessage: 'Os dados do acesso Premium são incompatíveis.',
        code: code,
      );
}
