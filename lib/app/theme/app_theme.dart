import 'package:flutter/material.dart';
import 'package:meu_gestor_financeiro/app/theme/app_colors.dart';
import 'package:meu_gestor_financeiro/app/theme/app_radius.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
import 'package:meu_gestor_financeiro/app/theme/app_typography.dart';

abstract final class AppTheme {
  static ThemeData get light => _buildLight();

  static ThemeData get dark => _buildDark();

  static ThemeData _buildDark() {
    const ColorScheme colorScheme = ColorScheme.dark(
      primary: AppColors.primaryCyan,
      onPrimary: AppColors.onPrimaryAction,
      secondary: AppColors.primaryBlue,
      onSecondary: AppColors.textPrimary,
      error: AppColors.errorRed,
      onError: AppColors.backgroundPrimary,
      surface: AppColors.backgroundSecondary,
      onSurface: AppColors.textPrimary,
      surfaceContainerHighest: AppColors.surfacePrimary,
      outline: AppColors.borderDefault,
    );
    return _base(
      colorScheme: colorScheme,
      scaffoldColor: AppColors.backgroundPrimary,
      textTheme: AppTypography.textTheme(
        primary: AppColors.textPrimary,
        secondary: AppColors.textSecondary,
      ),
    );
  }

  static ThemeData _buildLight() {
    const ColorScheme colorScheme = ColorScheme.light(
      primary: AppColors.primaryBlue,
      onPrimary: AppColors.textPrimary,
      secondary: AppColors.primaryCyan,
      onSecondary: AppColors.onPrimaryAction,
      error: Color(0xFFB42335),
      onError: AppColors.lightSurface,
      surface: AppColors.lightSurface,
      onSurface: AppColors.lightTextPrimary,
      surfaceContainerHighest: AppColors.lightSurfaceElevated,
      outline: AppColors.lightBorder,
    );
    return _base(
      colorScheme: colorScheme,
      scaffoldColor: AppColors.lightBackground,
      textTheme: AppTypography.textTheme(
        primary: AppColors.lightTextPrimary,
        secondary: AppColors.lightTextSecondary,
      ),
    );
  }

  static ThemeData _base({
    required ColorScheme colorScheme,
    required Color scaffoldColor,
    required TextTheme textTheme,
  }) {
    return ThemeData(
      useMaterial3: true,
      brightness: colorScheme.brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldColor,
      textTheme: textTheme,
      fontFamily: AppTypography.fontFamily,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: AppColors.transparent,
        foregroundColor: colorScheme.onSurface,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainerHighest,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.large),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        constraints: const BoxConstraints(minHeight: AppSpacing.fieldHeight),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        labelStyle: textTheme.bodyMedium,
        hintStyle: textTheme.bodyMedium,
        prefixIconColor: colorScheme.primary,
        suffixIconColor: colorScheme.primary,
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.medium,
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.medium,
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.medium,
          borderSide: BorderSide(color: colorScheme.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.medium,
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
        disabledBorder: const OutlineInputBorder(
          borderRadius: AppRadius.medium,
          borderSide: BorderSide(color: AppColors.disabled),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.medium),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(
            AppSpacing.minimumTapTarget,
            AppSpacing.minimumTapTarget,
          ),
          foregroundColor: colorScheme.primary,
          textStyle: textTheme.labelLarge,
        ),
      ),
    );
  }
}
