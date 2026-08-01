import 'package:meu_gestor_financeiro/features/categories/domain/financial_category.dart';

FinancialCategory createTestCategory({
  String id = 'category-1',
  String ownerId = 'owner',
  String name = 'Salário',
  FinancialCategoryKind kind = FinancialCategoryKind.income,
  FinancialCategoryIcon icon = FinancialCategoryIcon.salary,
  FinancialCategoryColor color = FinancialCategoryColor.green,
  bool isArchived = false,
}) {
  final DateTime timestamp = DateTime.utc(2026, 8, 1, 12);
  return FinancialCategory(
    id: id,
    ownerId: ownerId,
    name: name,
    kind: kind,
    icon: icon,
    color: color,
    isArchived: isArchived,
    archivedAt: isArchived ? timestamp : null,
    createdAt: timestamp,
    updatedAt: timestamp,
    schemaVersion: FinancialCategory.currentSchemaVersion,
  );
}
