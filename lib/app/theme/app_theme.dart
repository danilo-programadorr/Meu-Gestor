import 'package:flutter/material.dart';
import 'package:meu_gestor_financeiro/app/theme/app_colors.dart';
import 'package:meu_gestor_financeiro/app/theme/app_radius.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
import 'package:meu_gestor_financeiro/app/theme/app_theme_colors.dart';
import 'package:meu_gestor_financeiro/app/theme/app_typography.dart';

abstract final class AppTheme {
  static ThemeData get light => _buildLight();

  static ThemeData get dark => _buildDark();

  static ThemeData _buildDark() {
    const ColorScheme colorScheme = ColorScheme.dark(
      primary: AppColors.primaryCyan,
      onPrimary: AppColors.onPrimaryAction,
      primaryContainer: Color(0xFF20384A),
      onPrimaryContainer: Color(0xFFD9F0F6),
      secondary: AppColors.chartBlue,
      onSecondary: AppColors.onPrimaryAction,
      secondaryContainer: Color(0xFF223047),
      onSecondaryContainer: AppColors.textPrimary,
      tertiary: Color(0xFFE5AE5B),
      onTertiary: Color(0xFF2D1B00),
      error: AppColors.errorRed,
      onError: Color(0xFF350704),
      surface: AppColors.backgroundSecondary,
      onSurface: AppColors.textPrimary,
      surfaceContainerLowest: AppColors.backgroundPrimary,
      surfaceContainerLow: Color(0xFF10192A),
      surfaceContainer: AppColors.backgroundSecondary,
      surfaceContainerHigh: AppColors.backgroundElevated,
      surfaceContainerHighest: Color(0xFF223149),
      outline: AppColors.borderDefault,
      outlineVariant: Color(0xFF20364A),
      shadow: AppColors.shadow,
      scrim: Color(0xB3050B18),
    );
    const AppThemeColors extension = AppThemeColors(
      success: AppColors.positiveGreen,
      onSuccess: Color(0xFF071F12),
      expense: AppColors.errorRed,
      onExpense: Color(0xFF350704),
      warning: Color(0xFFE5AE5B),
      onWarning: Color(0xFF2D1B00),
      info: AppColors.primaryCyan,
      onInfo: AppColors.onPrimaryAction,
      elevatedSurface: AppColors.backgroundElevated,
      subtleSurface: Color(0xFF10192A),
      balanceGradientStart: Color(0xFF14243A),
      balanceGradientEnd: Color(0xFF1B3548),
      chartTrack: Color(0xFF2B3B51),
      shadow: Color(0x52000000),
    );
    return _base(
      colorScheme: colorScheme,
      scaffoldColor: AppColors.backgroundPrimary,
      textTheme: AppTypography.textTheme(
        primary: AppColors.textPrimary,
        secondary: AppColors.textSecondary,
      ),
      extension: extension,
    );
  }

  static ThemeData _buildLight() {
    const ColorScheme colorScheme = ColorScheme.light(
      primary: AppColors.lightPrimary,
      onPrimary: AppColors.lightSurface,
      primaryContainer: AppColors.lightPrimarySoft,
      onPrimaryContainer: AppColors.lightTextPrimary,
      secondary: Color(0xFF54798C),
      onSecondary: AppColors.lightSurface,
      secondaryContainer: AppColors.lightSurfaceElevated,
      onSecondaryContainer: AppColors.lightTextPrimary,
      tertiary: Color(0xFF946200),
      onTertiary: AppColors.lightSurface,
      error: Color(0xFFB94B45),
      onError: AppColors.lightSurface,
      surface: AppColors.lightSurface,
      onSurface: AppColors.lightTextPrimary,
      surfaceContainerLowest: AppColors.lightSurface,
      surfaceContainerLow: Color(0xFFF0F4F7),
      surfaceContainer: AppColors.lightSurfaceElevated,
      surfaceContainerHigh: Color(0xFFE2EBF0),
      surfaceContainerHighest: Color(0xFFD9E5EB),
      outline: AppColors.lightBorder,
      outlineVariant: Color(0xFFD8E2E8),
      shadow: Color(0x240F2940),
      scrim: Color(0x66142033),
    );
    const AppThemeColors extension = AppThemeColors(
      success: Color(0xFF287A4B),
      onSuccess: AppColors.lightSurface,
      expense: Color(0xFFB94B45),
      onExpense: AppColors.lightSurface,
      warning: Color(0xFF946200),
      onWarning: AppColors.lightSurface,
      info: AppColors.lightPrimary,
      onInfo: AppColors.lightSurface,
      elevatedSurface: AppColors.lightSurface,
      subtleSurface: AppColors.lightSurfaceElevated,
      balanceGradientStart: Color(0xFFFFFFFF),
      balanceGradientEnd: AppColors.lightPrimarySoft,
      chartTrack: Color(0xFFD9E5EB),
      shadow: Color(0x24142A3D),
    );
    return _base(
      colorScheme: colorScheme,
      scaffoldColor: AppColors.lightBackground,
      textTheme: AppTypography.textTheme(
        primary: AppColors.lightTextPrimary,
        secondary: AppColors.lightTextSecondary,
      ),
      extension: extension,
    );
  }

  static ThemeData _base({
    required ColorScheme colorScheme,
    required Color scaffoldColor,
    required TextTheme textTheme,
    required AppThemeColors extension,
  }) {
    final BorderSide quietBorder = BorderSide(color: colorScheme.outline);
    return ThemeData(
      useMaterial3: true,
      brightness: colorScheme.brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldColor,
      canvasColor: scaffoldColor,
      shadowColor: extension.shadow,
      dividerColor: colorScheme.outlineVariant,
      textTheme: textTheme,
      fontFamily: AppTypography.fontFamily,
      visualDensity: VisualDensity.standard,
      extensions: <ThemeExtension<dynamic>>[extension],
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.transparent,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: AppColors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surface,
        surfaceTintColor: AppColors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.large,
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: AppColors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.large),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        modalBackgroundColor: colorScheme.surface,
        surfaceTintColor: AppColors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.largeValue),
          ),
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: AppColors.transparent,
        headerBackgroundColor: colorScheme.primaryContainer,
        headerForegroundColor: colorScheme.onPrimaryContainer,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.large),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onInverseSurface,
        ),
        actionTextColor: colorScheme.inversePrimary,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.medium),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerLow,
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
          borderSide: quietBorder,
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
        disabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.medium,
          borderSide: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.45),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(
            AppSpacing.minimumTapTarget,
            AppSpacing.buttonHeight,
          ),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.medium),
          textStyle: textTheme.labelLarge,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          disabledBackgroundColor: colorScheme.onSurface.withValues(
            alpha: 0.12,
          ),
          disabledForegroundColor: colorScheme.onSurface.withValues(
            alpha: 0.38,
          ),
          elevation: 0,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.medium),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(
            AppSpacing.minimumTapTarget,
            AppSpacing.minimumTapTarget,
          ),
          side: quietBorder,
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
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size.square(AppSpacing.minimumTapTarget),
          foregroundColor: colorScheme.onSurface,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        selectedColor: colorScheme.primaryContainer,
        disabledColor: colorScheme.onSurface.withValues(alpha: 0.08),
        side: quietBorder,
        shape: const StadiumBorder(),
        labelStyle: textTheme.labelMedium,
        checkmarkColor: colorScheme.onPrimaryContainer,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colorScheme.primary,
        textColor: colorScheme.onSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.medium),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        linearTrackColor: extension.chartTrack,
        circularTrackColor: extension.chartTrack,
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
