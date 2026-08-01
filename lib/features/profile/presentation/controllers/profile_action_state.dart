import 'package:meu_gestor_financeiro/features/profile/domain/user_profile.dart';

enum ProfileActionStatus { idle, loading, success, failure }

final class ProfileActionState {
  const ProfileActionState._({
    required this.status,
    this.profile,
    this.message,
    this.hasPartialFailure = false,
  });

  const ProfileActionState.idle() : this._(status: ProfileActionStatus.idle);

  const ProfileActionState.loading()
    : this._(status: ProfileActionStatus.loading);

  const ProfileActionState.success({
    required UserProfile profile,
    String? message,
    bool hasPartialFailure = false,
  }) : this._(
         status: ProfileActionStatus.success,
         profile: profile,
         message: message,
         hasPartialFailure: hasPartialFailure,
       );

  const ProfileActionState.failure({required String message})
    : this._(status: ProfileActionStatus.failure, message: message);

  final ProfileActionStatus status;
  final UserProfile? profile;
  final String? message;
  final bool hasPartialFailure;

  bool get isLoading => status == ProfileActionStatus.loading;
}
