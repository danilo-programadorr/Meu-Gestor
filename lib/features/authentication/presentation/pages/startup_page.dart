import 'package:flutter/material.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
import 'package:meu_gestor_financeiro/features/authentication/presentation/widgets/startup_grid_loader.dart';

class StartupPage extends StatelessWidget {
  const StartupPage({super.key});

  static const String _backgroundAsset = 'assets/images/auth/auth_hero.webp';

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(
            _backgroundAsset,
            key: const ValueKey<String>('startup-static-image'),
            fit: BoxFit.cover,
            alignment: Alignment.center,
            excludeFromSemantics: true,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  colors.scrim.withValues(alpha: 0.48),
                  colors.scrim.withValues(alpha: 0.78),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Semantics(
                  container: true,
                  explicitChildNodes: true,
                  liveRegion: true,
                  label: 'Preparando seu espaço financeiro com segurança',
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const StartupGridLoader(),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Preparando seu espaço financeiro',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Só mais um instante...',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.86),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
