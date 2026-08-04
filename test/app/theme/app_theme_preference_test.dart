import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/app/theme/app_theme.dart';
import 'package:meu_gestor_financeiro/app/theme/app_theme_preference.dart';
import 'package:meu_gestor_financeiro/app/theme/app_theme_preference_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('padrão e valores desconhecidos seguem o sistema', () {
    expect(AppThemePreference.fromStorage(null), AppThemePreference.system);
    expect(
      AppThemePreference.fromStorage('valor-incompatível'),
      AppThemePreference.system,
    );
    expect(AppThemePreference.system.themeMode, ThemeMode.system);
    expect(AppThemePreference.light.themeMode, ThemeMode.light);
    expect(AppThemePreference.dark.themeMode, ThemeMode.dark);
  });

  test('preferência é persistida e recuperada após nova instância', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferencesAppThemePreferenceStore first =
        await SharedPreferencesAppThemePreferenceStore.create();
    await first.save(AppThemePreference.dark);

    final SharedPreferencesAppThemePreferenceStore second =
        await SharedPreferencesAppThemePreferenceStore.create();
    expect(await second.load(), AppThemePreference.dark);
  });

  test('controlador restaura estado quando a persistência falha', () async {
    final _TestThemeStore store = _TestThemeStore(
      value: AppThemePreference.system,
      failOnSave: true,
    );
    final ProviderContainer container = ProviderContainer(
      overrides: [appThemePreferenceStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);

    await expectLater(
      container
          .read(appThemePreferenceControllerProvider.notifier)
          .select(AppThemePreference.dark),
      throwsStateError,
    );
    expect(
      container.read(appThemePreferenceControllerProvider),
      AppThemePreference.system,
    );
  });

  testWidgets('seletor de aparência oferece sistema, claro e escuro', (
    WidgetTester tester,
  ) async {
    final _TestThemeStore store = _TestThemeStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appThemePreferenceStoreProvider.overrideWithValue(store)],
        child: Consumer(
          builder: (BuildContext context, WidgetRef ref, Widget? child) {
            final AppThemePreference preference = ref.watch(
              appThemePreferenceControllerProvider,
            );
            return MaterialApp(
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: preference.themeMode,
              home: const Scaffold(
                body: SingleChildScrollView(
                  child: AppThemePreferenceSelector(),
                ),
              ),
            );
          },
        ),
      ),
    );

    expect(find.text('Sistema'), findsOneWidget);
    expect(find.text('Claro'), findsOneWidget);
    expect(find.text('Escuro'), findsOneWidget);
    await tester.tap(find.text('Escuro'));
    await tester.pumpAndSettle();

    expect(store.value, AppThemePreference.dark);
    final BuildContext scaffold = tester.element(find.byType(Scaffold));
    expect(Theme.of(scaffold).brightness, Brightness.dark);
  });

  test('paletas mantêm contraste de texto principal', () {
    for (final ThemeData theme in <ThemeData>[AppTheme.light, AppTheme.dark]) {
      expect(
        _contrastRatio(
          theme.colorScheme.onSurface,
          theme.scaffoldBackgroundColor,
        ),
        greaterThanOrEqualTo(7),
      );
      expect(
        _contrastRatio(theme.colorScheme.onPrimary, theme.colorScheme.primary),
        greaterThanOrEqualTo(3),
      );
    }
  });
}

double _contrastRatio(Color first, Color second) {
  final double light = first.computeLuminance() >= second.computeLuminance()
      ? first.computeLuminance()
      : second.computeLuminance();
  final double dark = first.computeLuminance() < second.computeLuminance()
      ? first.computeLuminance()
      : second.computeLuminance();
  return (light + 0.05) / (dark + 0.05);
}

final class _TestThemeStore implements AppThemePreferenceStore {
  _TestThemeStore({
    this.value = AppThemePreference.system,
    this.failOnSave = false,
  });

  AppThemePreference value;
  final bool failOnSave;

  @override
  Future<AppThemePreference> load() async => value;

  @override
  Future<void> save(AppThemePreference preference) async {
    if (failOnSave) {
      throw StateError('falha controlada');
    }
    value = preference;
  }
}
