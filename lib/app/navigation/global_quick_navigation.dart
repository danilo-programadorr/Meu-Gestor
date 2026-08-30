import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_gestor_financeiro/app/routing/app_routes.dart';

class GlobalQuickNavigation extends StatefulWidget {
  const GlobalQuickNavigation({
    required this.router,
    required this.location,
    required this.child,
    this.onNavigate,
    super.key,
  });
  final GoRouter router;
  final String location;
  final Widget child;
  final void Function(String location)? onNavigate;

  @override
  State<GlobalQuickNavigation> createState() => _GlobalQuickNavigationState();
}

class _GlobalQuickNavigationState extends State<GlobalQuickNavigation> {
  static const double _reservedBottomSpace = 92;

  late String _location;

  @override
  void initState() {
    super.initState();
    _location = widget.location;
    widget.router.routerDelegate.addListener(_onRouteChanged);
  }

  @override
  void didUpdateWidget(covariant GlobalQuickNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.router != widget.router) {
      oldWidget.router.routerDelegate.removeListener(_onRouteChanged);
      widget.router.routerDelegate.addListener(_onRouteChanged);
    }
    if (oldWidget.location != widget.location) {
      _location = widget.location;
    }
  }

  @override
  void dispose() {
    widget.router.routerDelegate.removeListener(_onRouteChanged);
    super.dispose();
  }

  void _onRouteChanged() {
    final String next =
        widget.router.routerDelegate.currentConfiguration.uri.path;
    if (next == _location) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && next != _location) setState(() => _location = next);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAuthenticatedInternalRoute(_location)) return widget.child;
    return ValueListenableBuilder<int>(
      valueListenable: GlobalQuickNavigationModalVisibility._modalCount,
      builder: (BuildContext context, int modalCount, Widget? child) {
        if (modalCount > 0) return child!;
        return Stack(
          children: <Widget>[
            Padding(
              padding: EdgeInsets.only(
                bottom:
                    _reservedBottomSpace + MediaQuery.paddingOf(context).bottom,
              ),
              child: child,
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: _QuickBar(
                    activeLocation: _location,
                    onGo: widget.onNavigate ?? context.go,
                  ),
                ),
              ),
            ),
          ],
        );
      },
      child: widget.child,
    );
  }
}

/// Oculta a faixa enquanto um diálogo de resultado está aberto, para que o
/// modal permaneça no topo visual e sem receber toques concorrentes.
abstract final class GlobalQuickNavigationModalVisibility {
  static final ValueNotifier<int> _modalCount = ValueNotifier<int>(0);

  static Future<T?> whileModalIsOpen<T>(Future<T?> Function() present) async {
    _modalCount.value++;
    try {
      return await present();
    } finally {
      _modalCount.value--;
    }
  }
}

bool _isAuthenticatedInternalRoute(String location) => <String>{
  AppRoutes.home,
  AppRoutes.calendar,
  AppRoutes.assistant,
  AppRoutes.assistantConversation,
  AppRoutes.accounts,
  AppRoutes.categories,
  AppRoutes.transactions,
  AppRoutes.payables,
  AppRoutes.receivables,
  AppRoutes.investments,
  AppRoutes.rankings,
  AppRoutes.investmentQuotes,
  AppRoutes.investmentTools,
  AppRoutes.fairValue,
  AppRoutes.profile,
  AppRoutes.privacyConsents,
  AppRoutes.dataAndPrivacy,
  AppRoutes.ownerArea,
}.contains(location);

class _QuickBar extends StatelessWidget {
  const _QuickBar({required this.activeLocation, required this.onGo});
  final String activeLocation;
  final void Function(String location) onGo;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 84,
    child: Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      constraints: const BoxConstraints(maxWidth: 520),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHigh.withValues(alpha: .96),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 16,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) => Row(
          children: <Widget>[
            Expanded(
              child: _QuickButton(
                asset: 'assets/icone/home.png',
                label: 'Home',
                active: activeLocation == AppRoutes.home,
                onTap: () => onGo(AppRoutes.home),
              ),
            ),
            Expanded(
              child: _QuickButton(
                asset: 'assets/icone/ranking.png',
                label: 'Ranking',
                active: activeLocation == AppRoutes.rankings,
                onTap: () => onGo(AppRoutes.rankings),
              ),
            ),
            Expanded(
              child: _QuickButton(
                asset: 'assets/icone/modo-conversa.png',
                label: 'Conversa',
                active: activeLocation == AppRoutes.assistantConversation,
                central: true,
                onTap: () =>
                    onGo('${AppRoutes.assistantConversation}?listen=auto'),
              ),
            ),
            Expanded(
              child: _QuickButton(
                asset: 'assets/icone/investimentos.png',
                label: 'Investimentos',
                active: activeLocation.startsWith(AppRoutes.investments),
                onTap: () => onGo(AppRoutes.investments),
              ),
            ),
            Expanded(
              child: _QuickButton(
                asset: 'assets/icone/calculadora.png',
                label: 'Calculadora',
                active: activeLocation == AppRoutes.investmentTools,
                onTap: () => onGo(AppRoutes.investmentTools),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _QuickButton extends StatelessWidget {
  const _QuickButton({
    required this.asset,
    required this.label,
    required this.active,
    required this.onTap,
    this.central = false,
  });
  final String asset;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final bool central;

  @override
  Widget build(BuildContext context) => Semantics(
    key: Key('quick-nav-$label'),
    button: true,
    selected: active,
    label: '$label${active ? ', atual' : ''}',
    tooltip: label,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: 76,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              AnimatedContainer(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 160),
                width: central ? 36 : 30,
                height: central ? 36 : 30,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: active
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Image.asset(
                  asset,
                  fit: BoxFit.contain,
                  semanticLabel: label,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
