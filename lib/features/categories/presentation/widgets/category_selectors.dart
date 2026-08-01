import 'package:flutter/material.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
import 'package:meu_gestor_financeiro/features/categories/domain/financial_category.dart';
import 'package:meu_gestor_financeiro/features/categories/presentation/widgets/category_visuals.dart';

class CategoryKindSelector extends StatelessWidget {
  const CategoryKindSelector({
    required this.value,
    required this.enabled,
    required this.onChanged,
    super.key,
  });

  final FinancialCategoryKind value;
  final bool enabled;
  final ValueChanged<FinancialCategoryKind> onChanged;

  @override
  Widget build(BuildContext context) =>
      DropdownButtonFormField<FinancialCategoryKind>(
        initialValue: value,
        decoration: const InputDecoration(labelText: 'Tipo'),
        items: FinancialCategoryKind.values
            .map(
              (FinancialCategoryKind kind) =>
                  DropdownMenuItem(value: kind, child: Text(kind.label)),
            )
            .toList(growable: false),
        onChanged: enabled
            ? (FinancialCategoryKind? kind) {
                if (kind != null) {
                  onChanged(kind);
                }
              }
            : null,
      );
}

class CategoryIconSelector extends StatelessWidget {
  const CategoryIconSelector({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final FinancialCategoryIcon value;
  final ValueChanged<FinancialCategoryIcon> onChanged;

  @override
  Widget build(BuildContext context) =>
      DropdownButtonFormField<FinancialCategoryIcon>(
        initialValue: value,
        decoration: const InputDecoration(labelText: 'Ícone'),
        items: FinancialCategoryIcon.values
            .map(
              (FinancialCategoryIcon icon) => DropdownMenuItem(
                value: icon,
                child: Row(
                  children: <Widget>[
                    Icon(categoryIconData(icon)),
                    const SizedBox(width: AppSpacing.sm),
                    Text(icon.label),
                  ],
                ),
              ),
            )
            .toList(growable: false),
        onChanged: (FinancialCategoryIcon? icon) {
          if (icon != null) {
            onChanged(icon);
          }
        },
      );
}

class CategoryColorSelector extends StatelessWidget {
  const CategoryColorSelector({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final FinancialCategoryColor value;
  final ValueChanged<FinancialCategoryColor> onChanged;

  @override
  Widget build(BuildContext context) =>
      DropdownButtonFormField<FinancialCategoryColor>(
        initialValue: value,
        decoration: const InputDecoration(labelText: 'Cor'),
        items: FinancialCategoryColor.values
            .map(
              (FinancialCategoryColor color) => DropdownMenuItem(
                value: color,
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: categoryColorData(color),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(color.label),
                  ],
                ),
              ),
            )
            .toList(growable: false),
        onChanged: (FinancialCategoryColor? color) {
          if (color != null) {
            onChanged(color);
          }
        },
      );
}
