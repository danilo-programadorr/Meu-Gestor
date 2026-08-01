import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_gestor_financeiro/app/routing/app_routes.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
import 'package:meu_gestor_financeiro/features/owner_access/presentation/controllers/master_access_controller.dart';
import 'package:meu_gestor_financeiro/features/owner_access/presentation/controllers/master_access_state.dart';

final class MasterAccessGate extends ConsumerWidget {
  const MasterAccessGate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MasterAccessState access = ref.watch(masterAccessControllerProvider);
    if (access.isActiveOwner) {
      return child;
    }
    if (access.isLoading || access.status == MasterAccessStatus.idle) {
      return const Scaffold(
        body: SafeArea(
          child: Center(
            child: CircularProgressIndicator(
              semanticsLabel: 'Confirmando acesso proprietário',
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Acesso indisponível')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.lock_outline_rounded, size: 56),
                  const SizedBox(height: AppSpacing.md),
                  const Text(
                    'O acesso proprietário não está confirmado.',
                    textAlign: TextAlign.center,
                  ),
                  if (access.status == MasterAccessStatus.invalidDocument ||
                      access.status ==
                          MasterAccessStatus.recoverableError) ...<Widget>[
                    const SizedBox(height: AppSpacing.md),
                    OutlinedButton.icon(
                      onPressed: ref
                          .read(masterAccessControllerProvider.notifier)
                          .refresh,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Tentar novamente'),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  FilledButton.icon(
                    onPressed: () => context.go(AppRoutes.home),
                    icon: const Icon(Icons.home_outlined),
                    label: const Text('Voltar ao início'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
