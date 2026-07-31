enum AuthActionStatus { idle, loading, success, cancelled, failure }

final class AuthActionState {
  const AuthActionState._({required this.status, this.message});

  const AuthActionState.idle() : this._(status: AuthActionStatus.idle);

  const AuthActionState.loading() : this._(status: AuthActionStatus.loading);

  const AuthActionState.success({String? message})
    : this._(status: AuthActionStatus.success, message: message);

  const AuthActionState.cancelled({required String message})
    : this._(status: AuthActionStatus.cancelled, message: message);

  const AuthActionState.failure({required String message})
    : this._(status: AuthActionStatus.failure, message: message);

  final AuthActionStatus status;
  final String? message;

  bool get isLoading => status == AuthActionStatus.loading;
}
