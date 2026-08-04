import 'package:flutter/material.dart';
import 'package:meu_gestor_financeiro/app/theme/app_gradients.dart';
import 'package:meu_gestor_financeiro/app/theme/app_radius.dart';

class AuthHero extends StatelessWidget {
  const AuthHero({super.key});

  static const String assetPath = 'assets/images/auth/auth_hero.webp';

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'Pessoas organizando informações financeiras em um tablet',
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.heroValue),
          bottom: Radius.circular(AppRadius.largeValue),
        ),
        child: AspectRatio(
          aspectRatio: 1.95,
          child: Image.asset(
            assetPath,
            alignment: Alignment.center,
            fit: BoxFit.cover,
            errorBuilder:
                (BuildContext context, Object error, StackTrace? stack) {
                  return DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: AppGradients.accent,
                    ),
                    child: Center(
                      child: Icon(
                        Icons.account_balance_wallet_outlined,
                        color: Theme.of(context).colorScheme.onPrimary,
                        size: 64,
                        semanticLabel: 'Meu Gestor Financeiro',
                      ),
                    ),
                  );
                },
          ),
        ),
      ),
    );
  }
}
