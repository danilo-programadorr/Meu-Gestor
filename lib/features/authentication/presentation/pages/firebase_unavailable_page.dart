import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
import 'package:meu_gestor_financeiro/core/firebase/firebase_startup.dart';

class FirebaseUnavailablePage extends ConsumerWidget {
  const FirebaseUnavailablePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final FirebaseStartupState state = ref.watch(firebaseStartupProvider);
    final bool productionBlocked = state is FirebaseStartupProductionBlocked;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.shield_outlined,
                        size: 64,
                        color: Theme.of(context).colorScheme.primary,
                        semanticLabel: 'Serviço protegido',
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Serviço indisponível',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        productionBlocked
                            ? 'O ambiente de produção ainda não foi configurado.'
                            : 'Não foi possível iniciar o acesso seguro. Feche o aplicativo e tente novamente.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
