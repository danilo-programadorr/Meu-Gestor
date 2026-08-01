import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

void popOrGoToFallback(BuildContext context, String fallbackLocation) {
  if (context.canPop()) {
    context.pop();
    return;
  }
  context.go(fallbackLocation);
}

final class SafeBackButton extends StatelessWidget {
  const SafeBackButton({required this.fallbackLocation, super.key});

  final String fallbackLocation;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: MaterialLocalizations.of(context).backButtonTooltip,
    onPressed: () => popOrGoToFallback(context, fallbackLocation),
    icon: const BackButtonIcon(),
  );
}

final class SafeBackScope extends StatelessWidget {
  const SafeBackScope({
    required this.fallbackLocation,
    required this.child,
    super.key,
  });

  final String fallbackLocation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bool canPop = context.canPop();
    return PopScope<Object?>(
      canPop: canPop,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop && context.mounted) {
          context.go(fallbackLocation);
        }
      },
      child: child,
    );
  }
}
