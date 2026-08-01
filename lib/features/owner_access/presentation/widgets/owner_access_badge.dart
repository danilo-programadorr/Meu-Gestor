import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_gestor_financeiro/app/routing/app_routes.dart';

final class OwnerAccessBadge extends StatelessWidget {
  const OwnerAccessBadge({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Acesso proprietário. Abrir Área do proprietário',
    excludeSemantics: true,
    child: ActionChip(
      avatar: const Icon(Icons.admin_panel_settings_outlined),
      label: const Text('Acesso proprietário'),
      onPressed: () => context.push(AppRoutes.ownerArea),
    ),
  );
}
