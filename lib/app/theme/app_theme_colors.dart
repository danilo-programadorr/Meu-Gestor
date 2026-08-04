import 'package:flutter/material.dart';

@immutable
final class AppThemeColors extends ThemeExtension<AppThemeColors> {
  const AppThemeColors({
    required this.success,
    required this.onSuccess,
    required this.expense,
    required this.onExpense,
    required this.warning,
    required this.onWarning,
    required this.info,
    required this.onInfo,
    required this.elevatedSurface,
    required this.subtleSurface,
    required this.balanceGradientStart,
    required this.balanceGradientEnd,
    required this.chartTrack,
    required this.shadow,
  });

  final Color success;
  final Color onSuccess;
  final Color expense;
  final Color onExpense;
  final Color warning;
  final Color onWarning;
  final Color info;
  final Color onInfo;
  final Color elevatedSurface;
  final Color subtleSurface;
  final Color balanceGradientStart;
  final Color balanceGradientEnd;
  final Color chartTrack;
  final Color shadow;

  static AppThemeColors of(BuildContext context) {
    final AppThemeColors? colors = Theme.of(
      context,
    ).extension<AppThemeColors>();
    assert(colors != null, 'AppThemeColors não está configurado no tema.');
    return colors!;
  }

  @override
  AppThemeColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? expense,
    Color? onExpense,
    Color? warning,
    Color? onWarning,
    Color? info,
    Color? onInfo,
    Color? elevatedSurface,
    Color? subtleSurface,
    Color? balanceGradientStart,
    Color? balanceGradientEnd,
    Color? chartTrack,
    Color? shadow,
  }) => AppThemeColors(
    success: success ?? this.success,
    onSuccess: onSuccess ?? this.onSuccess,
    expense: expense ?? this.expense,
    onExpense: onExpense ?? this.onExpense,
    warning: warning ?? this.warning,
    onWarning: onWarning ?? this.onWarning,
    info: info ?? this.info,
    onInfo: onInfo ?? this.onInfo,
    elevatedSurface: elevatedSurface ?? this.elevatedSurface,
    subtleSurface: subtleSurface ?? this.subtleSurface,
    balanceGradientStart: balanceGradientStart ?? this.balanceGradientStart,
    balanceGradientEnd: balanceGradientEnd ?? this.balanceGradientEnd,
    chartTrack: chartTrack ?? this.chartTrack,
    shadow: shadow ?? this.shadow,
  );

  @override
  AppThemeColors lerp(covariant AppThemeColors? other, double t) {
    if (other == null) {
      return this;
    }
    return AppThemeColors(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      onExpense: Color.lerp(onExpense, other.onExpense, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      info: Color.lerp(info, other.info, t)!,
      onInfo: Color.lerp(onInfo, other.onInfo, t)!,
      elevatedSurface: Color.lerp(elevatedSurface, other.elevatedSurface, t)!,
      subtleSurface: Color.lerp(subtleSurface, other.subtleSurface, t)!,
      balanceGradientStart: Color.lerp(
        balanceGradientStart,
        other.balanceGradientStart,
        t,
      )!,
      balanceGradientEnd: Color.lerp(
        balanceGradientEnd,
        other.balanceGradientEnd,
        t,
      )!,
      chartTrack: Color.lerp(chartTrack, other.chartTrack, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}
