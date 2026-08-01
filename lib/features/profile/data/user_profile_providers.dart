import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_gestor_financeiro/core/environment/app_environment.dart';
import 'package:meu_gestor_financeiro/features/profile/data/firebase_user_profile_repository.dart';
import 'package:meu_gestor_financeiro/features/profile/data/profile_diagnostics.dart';
import 'package:meu_gestor_financeiro/features/profile/domain/user_profile_repository.dart';

final Provider<FirebaseFirestore> firebaseFirestoreProvider =
    Provider<FirebaseFirestore>((Ref ref) => FirebaseFirestore.instance);

final Provider<ProfileDiagnostics> profileDiagnosticsProvider =
    Provider<ProfileDiagnostics>(
      (Ref ref) =>
          ProfileDiagnostics(environment: ref.watch(appEnvironmentProvider)),
    );

final Provider<UserProfileRepository> userProfileRepositoryProvider =
    Provider<UserProfileRepository>(
      (Ref ref) => FirebaseUserProfileRepository(
        firestore: ref.watch(firebaseFirestoreProvider),
        diagnostics: ref.watch(profileDiagnosticsProvider),
      ),
    );
