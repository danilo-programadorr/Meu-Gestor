import 'package:flutter/material.dart';
import 'package:meu_gestor_financeiro/app/theme/app_colors.dart';

abstract final class AppGradients {
  static const LinearGradient authDark = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[
      AppColors.backgroundPrimary,
      AppColors.backgroundSecondary,
      Color(0xFF041746),
    ],
    stops: <double>[0, 0.56, 1],
  );

  static const LinearGradient authLight = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[
      AppColors.lightBackground,
      AppColors.lightSurfaceElevated,
      Color(0xFFD8EFF8),
    ],
    stops: <double>[0, 0.6, 1],
  );

  static const LinearGradient accent = LinearGradient(
    colors: <Color>[AppColors.primaryCyan, AppColors.primaryBlue],
  );
}
