import 'package:flutter/material.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
import 'package:meu_gestor_financeiro/features/categories/domain/financial_category.dart';
import 'package:meu_gestor_financeiro/features/categories/presentation/widgets/category_visuals.dart';

class CategoryCard extends StatelessWidget {
  const CategoryCard({
    required this.category,
    required this.onEdit,
    required this.onArchive,
    super.key,
  });

  final FinancialCategory category;
  final VoidCallback onEdit;
  final VoidCallback onArchive;

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
            IconButton(
              tooltip: 'Editar categoria',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'Arquivar categoria',
              onPressed: onArchive,
              icon: const Icon(Icons.archive_outlined),
            ),
          ],
        ),
      ),
    );
  }
}
