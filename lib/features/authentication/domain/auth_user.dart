final class AuthUser {
  const AuthUser({
    required this.id,
    required this.emailVerified,
    this.displayName,
    this.email,
  });

  final String id;
  final String? displayName;
  final String? email;
  final bool emailVerified;
}
