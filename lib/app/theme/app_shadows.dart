import 'package:flutter/material.dart';
import 'package:meu_gestor_financeiro/app/theme/app_theme_colors.dart';

abstract final class AppShadows {
  static List<BoxShadow> elevated(BuildContext context) => <BoxShadow>[
    BoxShadow(
      color: AppThemeColors.of(context).shadow,
      blurRadius: 24,
      offset: const Offset(0, 10),
    ),
  ];

  static List<BoxShadow> focus(BuildContext context) => <BoxShadow>[
    BoxShadow(
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.20),
      blurRadius: 14,
      spreadRadius: 1,
    ),
  ];
}
