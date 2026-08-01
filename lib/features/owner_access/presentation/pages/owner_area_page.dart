import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_gestor_financeiro/app/routing/app_routes.dart';
import 'package:meu_gestor_financeiro/app/routing/safe_back_navigation.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
import 'package:meu_gestor_financeiro/features/owner_access/domain/app_capability.dart';
import 'package:meu_gestor_financeiro/features/owner_access/presentation/controllers/master_access_controller.dart';
import 'package:meu_gestor_financeiro/features/owner_access/presentation/controllers/master_access_state.dart';

final class OwnerAreaPage extends ConsumerWidget {
  const OwnerAreaPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MasterAccessState access = ref.watch(masterAccessControllerProvider);
    return SafeBackScope(
      fallbackLocation: AppRoutes.home,
      child: Scaffold(
        appBar: AppBar(
          leading: const SafeBackButton(fallbackLocation: AppRoutes.home),
          title: const Text('Área do proprietário'),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Semantics(
                      label: 'Papel Owner confirmado pelo servidor',
                      child: const Card(
                        child: ListTile(
                          leading: Icon(Icons.admin_panel_settings_outlined),
                          title: Text('Owner'),
                          subtitle: Text(
                            'Development — acesso confirmado pelo servidor',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const _NoticeCard(
                      icon: Icons.security_outlined,
                      text:
                          'Este acesso libera funcionalidades do produto, mas não permite consultar ou alterar dados de outras pessoas.',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Módulos disponíveis',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _ModuleLink(
                      label: 'Perfil',
                      icon: Icons.person_outline,
                      onTap: () => context.push(AppRoutes.profile),
                    ),
                    _ModuleLink(
                      label: 'Contas e carteiras',
                      icon: Icons.account_balance_wallet_outlined,
                      onTap: () => context.push(AppRoutes.accounts),
                    ),
                    _ModuleLink(
                      label: 'Categorias',
                      icon: Icons.category_outlined,
                      onTap: () => context.push(AppRoutes.categories),
                    ),
                    _ModuleLink(
                      label: 'Lançamentos',
                      icon: Icons.receipt_long_outlined,
                      onTap: () => context.push(AppRoutes.transactions),
                    ),
                    _ModuleLink(
                      label: 'Privacidade e consentimentos',
                      icon: Icons.privacy_tip_outlined,
                      onTap: () => context.push(AppRoutes.privacyConsents),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Estado interno seguro',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Card(
                      child: Column(
                        children: <Widget>[
                          ListTile(
                            leading: Icon(Icons.check_circle_outline),
                            title: Text('Funcionalidades implementadas'),
                            subtitle: Text('Liberadas para o proprietário'),
                          ),
                          ListTile(
                            leading: Icon(Icons.science_outlined),
                            title: Text('Funcionalidades experimentais'),
                            subtitle: Text(
                              'Capability disponível; nenhum experimento ativo',
                            ),
                          ),
                          ListTile(
                            leading: Icon(Icons.cloud_off_outlined),
                            title: Text('Produção'),
                            subtitle: Text('Ainda não configurada'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (access.accessContext.allows(
                      AppCapability.bypassSubscriptionGates,
                    ))
                      const _NoticeCard(
                        icon: Icons.workspace_premium_outlined,
                        text:
                            'Autorização interna preparada para liberar futuros recursos pagos e de IA, sem remover limites técnicos de segurança.',
                      ),
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton.icon(
                      onPressed: access.isLoading
                          ? null
                          : ref
                                .read(masterAccessControllerProvider.notifier)
                                .refresh,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Atualizar acesso'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _ModuleLink extends StatelessWidget {
  const _ModuleLink({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    ),
  );
}

final class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text)),
        ],
      ),
    ),
  );
}
