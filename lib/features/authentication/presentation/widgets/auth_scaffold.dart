import 'package:flutter/material.dart';

import 'package:meu_gestor_financeiro/app/theme/app_gradients.dart';
import 'package:meu_gestor_financeiro/app/theme/app_radius.dart';
import 'package:meu_gestor_financeiro/app/theme/app_shadows.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
import 'package:meu_gestor_financeiro/features/authentication/presentation/widgets/auth_hero.dart';

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    required this.child,
    this.showHero = true,
    this.showFinancialMark = true,
    super.key,
  });

  final Widget child;
  final bool showHero;
  final bool showFinancialMark;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final EdgeInsets viewInsets = MediaQuery.viewInsetsOf(context);
    final double horizontalPadding = MediaQuery.sizeOf(context).width < 380
        ? AppSpacing.compactPageHorizontal
        : AppSpacing.pageHorizontal;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: isDark ? AppGradients.authDark : AppGradients.authLight,
        ),
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _DigitalAccentPainter(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  return SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      AppSpacing.md,
                      horizontalPadding,
                      AppSpacing.lg + viewInsets.bottom,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: 560,
                          minHeight: constraints.maxHeight - AppSpacing.xxl,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            if (showHero) const AuthHero(),
                            Transform.translate(
                              offset: Offset(0, showHero ? -AppSpacing.lg : 0),
                              child: Stack(
                                clipBehavior: Clip.none,
                                alignment: Alignment.topCenter,
                                children: <Widget>[
                                  Container(
                                    width: double.infinity,
                                    margin: EdgeInsets.only(
                                      top: showFinancialMark
                                          ? AppSpacing.xl
                                          : 0,
                                    ),
                                    padding: EdgeInsets.fromLTRB(
                                      horizontalPadding,
                                      showFinancialMark
                                          ? AppSpacing.xxl + AppSpacing.sm
                                          : AppSpacing.xl,
                                      horizontalPadding,
                                      AppSpacing.xl,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.surface,
                                      borderRadius: AppRadius.large,
                                      border: Border.all(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.outline,
                                      ),
                                      boxShadow: AppShadows.elevated(context),
                                    ),
                                    child: child,
                                  ),
                                  if (showFinancialMark)
                                    _FinancialMark(
                                      backgroundColor: Theme.of(
                                        context,
                                      ).colorScheme.surface,
                                      foregroundColor: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FinancialMark extends StatelessWidget {
  const _FinancialMark({
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Símbolo do Meu Gestor Financeiro',
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: backgroundColor,
          border: Border.all(color: foregroundColor),
          boxShadow: AppShadows.focus(context),
        ),
        child: Icon(
          Icons.trending_up_rounded,
          color: foregroundColor,
          size: 36,
        ),
      ),
    );
  }
}

final class _DigitalAccentPainter extends CustomPainter {
  const _DigitalAccentPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = color.withValues(alpha: 0.18);
    const double gap = 22;
    final double startY = size.height * 0.76;
    for (double y = startY; y < size.height; y += gap) {
      final double curve = (y - startY) * 0.42;
      for (double x = -curve; x < size.width + curve; x += gap) {
        final double wave = (x / gap).round().isEven ? 0 : 5;
        canvas.drawCircle(Offset(x, y + wave), 1.35, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DigitalAccentPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
