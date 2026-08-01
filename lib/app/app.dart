import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_gestor_financeiro/app/l10n/app_localizations_config.dart';
import 'package:meu_gestor_financeiro/app/routing/app_router.dart';
import 'package:meu_gestor_financeiro/app/theme/app_theme.dart';
import 'package:meu_gestor_financeiro/features/owner_access/presentation/widgets/master_access_lifecycle_observer.dart';

class MeuGestorFinanceiroApp extends ConsumerWidget {
  const MeuGestorFinanceiroApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Meu Gestor Financeiro',
      debugShowCheckedModeBanner: false,
      locale: AppLocalizationsConfig.locale,
      supportedLocales: AppLocalizationsConfig.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      builder: (BuildContext context, Widget? child) =>
          MasterAccessLifecycleObserver(
            child: child ?? const SizedBox.shrink(),
          ),
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
