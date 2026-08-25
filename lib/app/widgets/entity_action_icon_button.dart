import 'package:flutter/material.dart';

enum EntityActionIcon { edit, delete, archive, restore }

/// Ícones canônicos para ações sobre entidades. O tooltip também compõe o
/// rótulo semântico do botão; nomes específicos evitam ações ambíguas.
final class EntityActionIconButton extends StatelessWidget {
  const EntityActionIconButton({
    required this.action,
    required this.entityName,
    required this.onPressed,
    this.destructive = false,
    super.key,
  });

  final EntityActionIcon action;
  final String entityName;
  final VoidCallback? onPressed;
  final bool destructive;

  String get _verb => switch (action) {
    EntityActionIcon.edit => 'Editar',
    EntityActionIcon.delete => 'Excluir',
    EntityActionIcon.archive => 'Arquivar',
    EntityActionIcon.restore => 'Restaurar',
  };

  IconData get _icon => switch (action) {
    EntityActionIcon.edit => Icons.edit_outlined,
    EntityActionIcon.delete => Icons.delete_outline_rounded,
    EntityActionIcon.archive => Icons.archive_outlined,
    EntityActionIcon.restore => Icons.unarchive_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final String label = '$_verb $entityName';
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      excludeSemantics: true,
      child: IconButton(
        tooltip: label,
        onPressed: onPressed,
        icon: Icon(
          _icon,
          color: destructive ? Theme.of(context).colorScheme.error : null,
        ),
      ),
    );
  }
}
