import 'package:shared_preferences/shared_preferences.dart';

abstract interface class AndroidCalendarSelectionRepository {
  Future<Set<String>> readOwn({required String ownerId});

  Future<void> saveOwn({
    required String ownerId,
    required Set<String> calendarIds,
  });
}

final class SharedPreferencesAndroidCalendarSelectionRepository
    implements AndroidCalendarSelectionRepository {
  const SharedPreferencesAndroidCalendarSelectionRepository(this._preferences);

  static const String _keyPrefix = 'android_calendar_selection_v1_';
  final SharedPreferences _preferences;

  @override
  Future<Set<String>> readOwn({required String ownerId}) async {
    _validateOwner(ownerId);
    return Set<String>.unmodifiable(
      (_preferences.getStringList(_key(ownerId)) ?? const <String>[])
          .where((String value) => _isValidCalendarId(value))
          .toSet(),
    );
  }

  @override
  Future<void> saveOwn({
    required String ownerId,
    required Set<String> calendarIds,
  }) async {
    _validateOwner(ownerId);
    if (!calendarIds.every(_isValidCalendarId)) {
      throw const AndroidCalendarSelectionFailure();
    }
    final bool persisted = await _preferences.setStringList(
      _key(ownerId),
      calendarIds.toList()..sort(),
    );
    if (!persisted) throw const AndroidCalendarSelectionFailure();
  }

  String _key(String ownerId) => '$_keyPrefix$ownerId';

  void _validateOwner(String ownerId) {
    if (ownerId.isEmpty || ownerId.length > 150 || ownerId.contains('/')) {
      throw const AndroidCalendarSelectionFailure();
    }
  }

  bool _isValidCalendarId(String value) =>
      value.isNotEmpty && value.length <= 150 && !value.contains('\u0000');
}

final class AndroidCalendarSelectionFailure implements Exception {
  const AndroidCalendarSelectionFailure();
}
