import 'package:flutter_riverpod/flutter_riverpod.dart';

final NotifierProvider<FinancialPrivacyController, bool>
financialPrivacyControllerProvider =
    NotifierProvider<FinancialPrivacyController, bool>(
      FinancialPrivacyController.new,
    );

final class FinancialPrivacyController extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() => state = !state;
}
