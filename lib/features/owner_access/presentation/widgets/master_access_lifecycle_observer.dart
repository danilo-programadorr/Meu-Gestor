import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_gestor_financeiro/features/owner_access/presentation/controllers/master_access_controller.dart';

final class MasterAccessLifecycleObserver extends ConsumerStatefulWidget {
  const MasterAccessLifecycleObserver({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<MasterAccessLifecycleObserver> createState() =>
      _MasterAccessLifecycleObserverState();
}

final class _MasterAccessLifecycleObserverState
    extends ConsumerState<MasterAccessLifecycleObserver>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(masterAccessControllerProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
