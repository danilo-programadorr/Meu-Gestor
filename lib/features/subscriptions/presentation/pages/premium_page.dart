import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_gestor_financeiro/app/routing/app_routes.dart';
import 'package:meu_gestor_financeiro/app/routing/safe_back_navigation.dart';
import 'package:meu_gestor_financeiro/app/theme/app_radius.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/data/premium_billing_providers.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_billing_models.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/presentation/controllers/investment_premium_access_controller.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/presentation/controllers/premium_products_controller.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/presentation/controllers/premium_purchase_controller.dart';

class PremiumPage extends ConsumerWidget {
  const PremiumPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<PremiumProductsState> products = ref.watch(
      premiumProductsControllerProvider,
    );
    final PremiumPurchaseState purchase = ref.watch(
      premiumPurchaseControllerProvider,
    );
    final AsyncValue<InvestmentPremiumAccessState> access = ref.watch(
      investmentPremiumAccessControllerProvider,
    );
    return SafeBackScope(
      fallbackLocation: AppRoutes.home,
      child: Scaffold(
        appBar: AppBar(
          leading: const SafeBackButton(fallbackLocation: AppRoutes.home),
          title: const Text('Premium e assinatura'),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageHorizontal,
              AppSpacing.md,
              AppSpacing.pageHorizontal,
              AppSpacing.xxl,
            ),
            children: <Widget>[
              Semantics(
                header: true,
                child: Text(
                  'Premium',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Acompanhe seus investimentos com clareza. Seus dados continuam preservados se a assinatura terminar.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.lg),
              _PremiumStatusCard(access: access, purchase: purchase),
              const SizedBox(height: AppSpacing.lg),
              const _PremiumBenefits(),
              const SizedBox(height: AppSpacing.lg),
              products.when(
                loading: () => const _PremiumMessageCard(
                  icon: Icons.hourglass_top_rounded,
                  title: 'Carregando planos',
                  message: 'Consultando a disponibilidade das assinaturas.',
                  loading: true,
                ),
                error: (Object _, StackTrace _) => _PremiumMessageCard(
                  icon: Icons.cloud_off_outlined,
                  title: 'Planos indisponíveis',
                  message: 'Não foi possível consultar os planos agora.',
                  actionLabel: 'Tentar novamente',
                  onAction: () => ref
                      .read(premiumProductsControllerProvider.notifier)
                      .retry(),
                ),
                data: (PremiumProductsState state) => _PlansSection(
                  state: state,
                  purchase: purchase,
                  onPurchase: (PremiumStoreProduct product) =>
                      _confirmPurchase(context, ref, product),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton.icon(
                onPressed: purchase.isBusy
                    ? null
                    : () => ref
                          .read(premiumPurchaseControllerProvider.notifier)
                          .restore(),
                icon: const Icon(Icons.restore_rounded),
                label: const Text('Restaurar assinatura'),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: () async {
                  final bool opened = await ref
                      .read(premiumSubscriptionManagementProvider)
                      .open();
                  if (context.mounted && !opened) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Não foi possível abrir a Google Play. Tente novamente mais tarde.',
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Gerenciar assinatura na Google Play'),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'As assinaturas renovam automaticamente até serem canceladas na Google Play. Preços e condições só serão mostrados quando forem fornecidos pela loja.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: AppSpacing.sm,
                children: <Widget>[
                  TextButton(
                    onPressed: () => context.push(AppRoutes.terms),
                    child: const Text('Termos de uso'),
                  ),
                  TextButton(
                    onPressed: () => context.push(AppRoutes.privacy),
                    child: const Text('Política de privacidade'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmPurchase(
    BuildContext context,
    WidgetRef ref,
    PremiumStoreProduct product,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('Assinar ${product.title}'),
        content: Text(
          'A Google Play mostrará o preço e as condições oficiais (${product.localizedPrice}, ${product.periodLabel.toLowerCase()}). O acesso só será liberado após confirmação do servidor.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref
          .read(premiumPurchaseControllerProvider.notifier)
          .purchase(product);
    }
  }
}

class _PremiumStatusCard extends StatelessWidget {
  const _PremiumStatusCard({required this.access, required this.purchase});

  final AsyncValue<InvestmentPremiumAccessState> access;
  final PremiumPurchaseState purchase;

  @override
  Widget build(BuildContext context) {
    final (
      IconData icon,
      String title,
      String message,
    ) = switch (purchase.phase) {
      PremiumPurchasePhase.pending => (
        Icons.schedule_outlined,
        'Pagamento pendente',
        purchase.message,
      ),
      PremiumPurchasePhase.verifying || PremiumPurchasePhase.starting => (
        Icons.verified_user_outlined,
        'Verificando assinatura',
        purchase.message,
      ),
      PremiumPurchasePhase.active => (
        Icons.workspace_premium_outlined,
        'Premium ativo',
        purchase.message,
      ),
      PremiumPurchasePhase.cancelled => (
        Icons.info_outline_rounded,
        'Assinatura não concluída',
        purchase.message,
      ),
      PremiumPurchasePhase.error => (
        Icons.error_outline_rounded,
        'Confirmação necessária',
        purchase.message,
      ),
      PremiumPurchasePhase.idle => _accessContent(access),
    };
    return _PremiumMessageCard(icon: icon, title: title, message: message);
  }

  (IconData, String, String) _accessContent(
    AsyncValue<InvestmentPremiumAccessState> access,
  ) => access.when(
    loading: () => (
      Icons.hourglass_top_rounded,
      'Confirmando status',
      'Aguarde a confirmação do seu acesso Premium pelo servidor.',
    ),
    error: (Object _, StackTrace _) => (
      Icons.cloud_off_outlined,
      'Status indisponível',
      'Não foi possível confirmar seu acesso agora.',
    ),
    data: (InvestmentPremiumAccessState value) => switch (value.status) {
      InvestmentPremiumAccessStatus.full => (
        Icons.workspace_premium_outlined,
        'Premium ativo',
        value.safeMessage,
      ),
      InvestmentPremiumAccessStatus.readOnly => (
        Icons.visibility_outlined,
        'Somente leitura',
        value.safeMessage,
      ),
      InvestmentPremiumAccessStatus.confirmationError => (
        Icons.cloud_off_outlined,
        'Status indisponível',
        value.safeMessage,
      ),
      InvestmentPremiumAccessStatus.denied => (
        Icons.workspace_premium_outlined,
        'Assinaturas em preparação',
        'A cobrança ainda não está disponível. Seus dados financeiros não são afetados.',
      ),
    },
  );
}

class _PlansSection extends StatelessWidget {
  const _PlansSection({
    required this.state,
    required this.purchase,
    required this.onPurchase,
  });

  final PremiumProductsState state;
  final PremiumPurchaseState purchase;
  final ValueChanged<PremiumStoreProduct> onPurchase;

  @override
  Widget build(BuildContext context) {
    if (state.status != PremiumProductsStatus.ready) {
      return _PremiumMessageCard(
        icon: Icons.construction_outlined,
        title: state.status == PremiumProductsStatus.preparation
            ? 'Assinaturas em preparação'
            : 'Planos indisponíveis',
        message: state.message,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('Planos', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        for (final PremiumStoreProduct product in state.products) ...<Widget>[
          _PremiumOfferCard(
            product: product,
            enabled: state.canPurchase && !purchase.isBusy,
            onPressed: () => onPurchase(product),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _PremiumOfferCard extends StatelessWidget {
  const _PremiumOfferCard({
    required this.product,
    required this.enabled,
    required this.onPressed,
  });

  final PremiumStoreProduct product;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: enabled,
    label:
        '${product.title}, ${product.localizedPrice}, ${product.periodLabel}',
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(product.title, style: Theme.of(context).textTheme.titleMedium),
            if (product.description.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.xxs),
              Text(product.description),
            ],
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${product.localizedPrice} • ${product.periodLabel}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (product.offerLabel case final String offer) Text(offer),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: enabled ? onPressed : null,
                child: const Text('Assinar pela Google Play'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PremiumBenefits extends StatelessWidget {
  const _PremiumBenefits();

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'O que o Premium inclui',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          const _Benefit('Acompanhamento manual de investimentos'),
          const _Benefit('Operações, custo médio e proventos'),
          const _Benefit('Seus dados permanecem preservados'),
          const _Benefit(
            'Cotações, calculadoras e análises: indisponíveis por enquanto',
          ),
        ],
      ),
    ),
  );
}

class _Benefit extends StatelessWidget {
  const _Benefit(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Icon(Icons.check_circle_outline_rounded, size: 20),
        const SizedBox(width: AppSpacing.xs),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

class _PremiumMessageCard extends StatelessWidget {
  const _PremiumMessageCard({
    required this.icon,
    required this.title,
    required this.message,
    this.loading = false,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool loading;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: loading,
    child: Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: AppRadius.large,
      ),
      child: Column(
        children: <Widget>[
          if (loading)
            const CircularProgressIndicator()
          else
            Icon(icon, size: 34),
          const SizedBox(height: AppSpacing.sm),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xxs),
          Text(message, textAlign: TextAlign.center),
          if (actionLabel != null && onAction != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    ),
  );
}
