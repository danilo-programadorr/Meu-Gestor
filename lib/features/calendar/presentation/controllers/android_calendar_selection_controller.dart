import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_gestor_financeiro/core/security/financial_access.dart';
import 'package:meu_gestor_financeiro/features/calendar/data/android_calendar_selection_repository.dart';
import 'package:meu_gestor_financeiro/features/calendar/data/method_channel_android_calendar_gateway.dart';
import 'package:meu_gestor_financeiro/features/calendar/domain/android_calendar_contract.dart';
import 'package:shared_preferences/shared_preferences.dart';

final Provider<AndroidCalendarGateway> androidCalendarGatewayProvider =
    Provider<AndroidCalendarGateway>(
      (Ref ref) => const MethodChannelAndroidCalendarGateway(),
    );

final FutureProvider<AndroidCalendarSelectionRepository>
androidCalendarSelectionRepositoryProvider =
    FutureProvider<AndroidCalendarSelectionRepository>((Ref ref) async {
      return SharedPreferencesAndroidCalendarSelectionRepository(
        await SharedPreferences.getInstance(),
      );
    });

final AsyncNotifierProvider<AndroidCalendarSelectionController, Set<String>>
androidCalendarSelectionControllerProvider =
    AsyncNotifierProvider<AndroidCalendarSelectionController, Set<String>>(
      AndroidCalendarSelectionController.new,
    );

final class AndroidCalendarSelectionController
    extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() async =>
      (await _repository).readOwn(ownerId: _ownerId);

  Future<bool> save(Set<String> calendarIds) async {
    if (state.isLoading) return false;
    state = const AsyncLoading<Set<String>>();
    try {
      await (await _repository).saveOwn(
        ownerId: _ownerId,
        calendarIds: calendarIds,
      );
      state = AsyncData<Set<String>>(calendarIds);
      return true;
    } on Object {
      state = AsyncError<Set<String>>(
        const AndroidCalendarSelectionFailure(),
        StackTrace.current,
      );
      return false;
    }
  }

  String get _ownerId {
    final String? ownerId = verifiedFinancialOwner(ref);
    if (ownerId == null) throw const AndroidCalendarSelectionFailure();
    return ownerId;
  }

  Future<AndroidCalendarSelectionRepository> get _repository =>
      ref.read(androidCalendarSelectionRepositoryProvider.future);
}
