import 'package:flutter/material.dart';
import 'package:meu_gestor_financeiro/app/theme/app_colors.dart';
import 'package:meu_gestor_financeiro/features/categories/domain/financial_category.dart';
import 'package:meu_gestor_financeiro/features/categories/domain/financial_category_failure.dart';

IconData categoryIconData(FinancialCategoryIcon icon) => switch (icon) {
  FinancialCategoryIcon.salary => Icons.payments_outlined,
  FinancialCategoryIcon.extraIncome => Icons.add_card_outlined,
  FinancialCategoryIcon.sale => Icons.sell_outlined,
  FinancialCategoryIcon.refund => Icons.currency_exchange_outlined,
  FinancialCategoryIcon.food => Icons.restaurant_outlined,
  FinancialCategoryIcon.home => Icons.home_outlined,
  FinancialCategoryIcon.transport => Icons.directions_bus_outlined,
  FinancialCategoryIcon.health => Icons.health_and_safety_outlined,
  FinancialCategoryIcon.education => Icons.school_outlined,
  FinancialCategoryIcon.leisure => Icons.sports_esports_outlined,
  FinancialCategoryIcon.subscription => Icons.subscriptions_outlined,
  FinancialCategoryIcon.shopping => Icons.shopping_bag_outlined,
  FinancialCategoryIcon.bill => Icons.receipt_long_outlined,
  FinancialCategoryIcon.other => Icons.category_outlined,
};

Color categoryColorData(FinancialCategoryColor color) => switch (color) {
  FinancialCategoryColor.cyan => AppColors.primaryCyan,
  FinancialCategoryColor.blue => AppColors.primaryBlue,
  FinancialCategoryColor.green => AppColors.positiveGreen,
  FinancialCategoryColor.purple => AppColors.secondaryPurple,
  FinancialCategoryColor.orange => AppColors.categoryOrange,
  FinancialCategoryColor.pink => AppColors.categoryPink,
  FinancialCategoryColor.red => AppColors.errorRed,
  FinancialCategoryColor.yellow => AppColors.categoryYellow,
  FinancialCategoryColor.teal => AppColors.categoryTeal,
  FinancialCategoryColor.gray => AppColors.categoryGray,
};

Color contrastingTextColor(Color background) =>
    background.computeLuminance() > 0.45
    ? AppColors.onPrimaryAction
    : AppColors.textPrimary;

String safeCategoriesErrorMessage(Object error) {
  if (error is FinancialCategoryFailure) {
    return switch (error.kind) {
      FinancialCategoryFailureKind.permissionDenied =>
        'Não foi possível acessar suas categorias com segurança.',
      FinancialCategoryFailureKind.unavailable ||
      FinancialCategoryFailureKind.timeout ||
      FinancialCategoryFailureKind.aborted =>
        'Verifique sua conexão e tente novamente.',
      FinancialCategoryFailureKind.conversion ||
      FinancialCategoryFailureKind.incompatible ||
      FinancialCategoryFailureKind.dataLoss =>
        'Encontramos uma inconsistência em uma categoria. Nenhum dado foi alterado.',
      _ => error.safeMessage,
    };
  }
  return 'Não foi possível carregar suas categorias. Tente novamente.';
}
