import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/app/theme/app_colors.dart';
import 'package:meu_gestor_financeiro/app/theme/app_theme.dart';

void main() {
  test('tema claro e escuro mantêm contraste estrutural', () {
    expect(AppTheme.light.brightness, Brightness.light);
    expect(AppTheme.dark.brightness, Brightness.dark);
    expect(AppTheme.dark.colorScheme.primary, AppColors.primaryCyan);
    expect(AppTheme.dark.colorScheme.onSurface, AppColors.textPrimary);
    expect(
      AppTheme.dark.colorScheme.onSurface.computeLuminance(),
      greaterThan(AppTheme.dark.colorScheme.surface.computeLuminance()),
    );
    expect(
      AppTheme.light.colorScheme.onSurface.computeLuminance(),
      lessThan(AppTheme.light.colorScheme.surface.computeLuminance()),
    );
  });
}
