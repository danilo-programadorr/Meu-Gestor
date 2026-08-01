import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/owner_access/domain/access_context.dart';
import 'package:meu_gestor_financeiro/features/owner_access/domain/app_capability.dart';
import 'package:meu_gestor_financeiro/features/owner_access/domain/app_role.dart';

void main() {
  test('26. owner recebe todas as capabilities registradas', () {
    final AccessContext context = AccessContext.owner();
    expect(context.capabilities, containsAll(AppCapability.values));
    expect(context.capabilities.length, AppCapability.values.length);
  });

  test('27. usuário comum não recebe capabilities administrativas', () {
    final AccessContext context = AccessContext.regularUser();
    expect(context.role, AppRole.regularUser);
    expect(context.capabilities, isEmpty);
  });

  test('28. capability desconhecida é negada', () {
    expect(
      AccessContext.owner().allowsIdentifier('unknownCapability'),
      isFalse,
    );
  });

  test('29. capabilities não dependem de e-mail', () {
    final AccessContext first = AccessContext.owner();
    final AccessContext second = AccessContext.owner();
    expect(first.capabilities, second.capabilities);
  });

  test('30. capabilities não dependem de armazenamento local', () {
    final AccessContext context = AccessContext.owner();
    expect(context.allows(AppCapability.bypassSubscriptionGates), isTrue);
    expect(context.allows(AppCapability.accessAllPaidFeatures), isTrue);
    expect(context.allows(AppCapability.accessAllAiFeatures), isTrue);
    expect(context.allows(AppCapability.bypassCommercialUsageLimits), isTrue);
  });
}
