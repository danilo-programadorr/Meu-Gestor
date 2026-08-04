import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemePreference {
  system('Sistema', Icons.brightness_auto_outlined),
  light('Claro', Icons.light_mode_outlined),
  dark('Escuro', Icons.dark_mode_outlined);

  const AppThemePreference(this.label, this.icon);

  final String label;
  final IconData icon;

  ThemeMode get themeMode => switch (this) {
    AppThemePreference.system => ThemeMode.system,
    AppThemePreference.light => ThemeMode.light,
    AppThemePreference.dark => ThemeMode.dark,
  };

  static AppThemePreference fromStorage(String? value) => switch (value) {
    'light' => AppThemePreference.light,
    'dark' => AppThemePreference.dark,
    _ => AppThemePreference.system,
  };
}

abstract interface class AppThemePreferenceStore {
  Future<AppThemePreference> load();

  Future<void> save(AppThemePreference preference);
}

final class SharedPreferencesAppThemePreferenceStore
    implements AppThemePreferenceStore {
  const SharedPreferencesAppThemePreferenceStore(this._storage);

  static Future<SharedPreferencesAppThemePreferenceStore> create() async =>
      SharedPreferencesAppThemePreferenceStore(
        await SharedPreferences.getInstance(),
      );

  static const String storageKey = 'appearance.theme_mode';

  final SharedPreferences _storage;

  @override
  Future<AppThemePreference> load() async =>
      AppThemePreference.fromStorage(_storage.getString(storageKey));

  @override
  Future<void> save(AppThemePreference preference) =>
      _storage.setString(storageKey, preference.name);
}

final class VolatileAppThemePreferenceStore implements AppThemePreferenceStore {
  VolatileAppThemePreferenceStore([this.value = AppThemePreference.system]);

  AppThemePreference value;

  @override
  Future<AppThemePreference> load() async => value;

  @override
  Future<void> save(AppThemePreference preference) async {
    value = preference;
  }
}

final Provider<AppThemePreferenceStore> appThemePreferenceStoreProvider =
    Provider<AppThemePreferenceStore>(
      (Ref ref) => VolatileAppThemePreferenceStore(),
    );

final Provider<AppThemePreference> initialAppThemePreferenceProvider =
    Provider<AppThemePreference>((Ref ref) => AppThemePreference.system);

final NotifierProvider<AppThemePreferenceController, AppThemePreference>
appThemePreferenceControllerProvider =
    NotifierProvider<AppThemePreferenceController, AppThemePreference>(
      AppThemePreferenceController.new,
    );

final class AppThemePreferenceController extends Notifier<AppThemePreference> {
  @override
  AppThemePreference build() => ref.watch(initialAppThemePreferenceProvider);

  Future<void> select(AppThemePreference preference) async {
    if (preference == state) {
      return;
    }
    final AppThemePreference previous = state;
    state = preference;
    try {
      await ref.read(appThemePreferenceStoreProvider).save(preference);
    } on Object {
      state = previous;
      rethrow;
    }
  }

  Future<void> toggleQuickly(Brightness resolvedBrightness) {
    final AppThemePreference target = resolvedBrightness == Brightness.dark
        ? AppThemePreference.light
        : AppThemePreference.dark;
    return select(target);
  }
}
