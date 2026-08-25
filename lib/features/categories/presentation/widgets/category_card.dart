import 'package:flutter/material.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
import 'package:meu_gestor_financeiro/app/widgets/entity_action_icon_button.dart';
import 'package:meu_gestor_financeiro/features/categories/domain/financial_category.dart';
import 'package:meu_gestor_financeiro/features/categories/presentation/widgets/category_visuals.dart';

class CategoryCard extends StatelessWidget {
  const CategoryCard({
    required this.category,
    required this.onEdit,
    required this.onArchive,
    this.actionsEnabled = true,
    super.key,
  });

  final FinancialCategory category;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  final bool actionsEnabled;

  @override
  Widget build(BuildContext context) {
    final Color color = categoryColorData(category.color);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          children: <Widget>[
            CircleAvatar(
              backgroundColor: color,
              foregroundColor: contrastingTextColor(color),
              child: Icon(
                categoryIconData(category.icon),
                semanticLabel: category.icon.label,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    category.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(category.kind.label),
                ],
              ),
            ),
            EntityActionIconButton(
              action: EntityActionIcon.edit,
              entityName: 'categoria',
              onPressed: actionsEnabled ? onEdit : null,
            ),
            EntityActionIconButton(
              action: EntityActionIcon.archive,
              entityName: 'categoria',
              onPressed: actionsEnabled ? onArchive : null,
            ),
          ],
        ),
      ),
    );
  }
}
