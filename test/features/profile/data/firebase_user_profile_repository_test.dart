import 'package:flutter_test/flutter_test.dart';
import 'package:meu_gestor_financeiro/features/profile/data/firebase_user_profile_repository.dart';
import 'package:meu_gestor_financeiro/features/profile/domain/user_profile.dart';

void main() {
  test('snapshot de servidor sem documento é resultado ausente válido', () {
    final UserProfileReadResult result =
        FirebaseUserProfileRepository.decodeReadSnapshot(
          ownerId: 'owner',
          exists: false,
          data: null,
          isFromCache: false,
          hasPendingWrites: false,
        );

    expect(result.profile, isNull);
    expect(result.isFromServer, isTrue);
    expect(result.hasPendingWrites, isFalse);
  });
}
