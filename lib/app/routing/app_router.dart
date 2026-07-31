import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_gestor_financeiro/app/routing/app_routes.dart';
import 'package:meu_gestor_financeiro/core/firebase/firebase_startup.dart';
import 'package:meu_gestor_financeiro/features/authentication/data/auth_providers.dart';
import 'package:meu_gestor_financeiro/features/authentication/domain/auth_user.dart';
import 'package:meu_gestor_financeiro/features/authentication/presentation/pages/email_verification_page.dart';
import 'package:meu_gestor_financeiro/features/authentication/presentation/pages/firebase_unavailable_page.dart';
import 'package:meu_gestor_financeiro/features/authentication/presentation/pages/login_page.dart';
import 'package:meu_gestor_financeiro/features/authentication/presentation/pages/reset_password_page.dart';
import 'package:meu_gestor_financeiro/features/authentication/presentation/pages/sign_up_page.dart';
import 'package:meu_gestor_financeiro/features/authentication/presentation/pages/startup_page.dart';
import 'package:meu_gestor_financeiro/features/home/presentation/home_page.dart';
import 'package:meu_gestor_financeiro/features/privacy/presentation/legal_document_page.dart';

final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((Ref ref) {
  final FirebaseStartupState startup = ref.watch(firebaseStartupProvider);
  final AsyncValue<AuthUser?>? authState = startup.isAvailable
      ? ref.watch(authStateProvider)
      : null;

  return GoRouter(
    initialLocation: AppRoutes.root,
    redirect: (context, state) {
      final String location = state.uri.path;
      if (startup is FirebaseStartupProductionBlocked ||
          startup is FirebaseStartupFailure) {
        return location == AppRoutes.unavailable ? null : AppRoutes.unavailable;
      }
      if (startup is FirebaseStartupInitializing) {
        return location == AppRoutes.splash ? null : AppRoutes.splash;
      }

      final bool isLegalRoute =
          location == AppRoutes.terms || location == AppRoutes.privacy;
      if (isLegalRoute) {
        return null;
      }
      if (authState == null || authState.isLoading) {
        return location == AppRoutes.splash ? null : AppRoutes.splash;
      }
      if (authState.hasError) {
        return location == AppRoutes.unavailable ? null : AppRoutes.unavailable;
      }

      final AuthUser? user = authState.value;
      final bool isPublicAuthRoute =
          location == AppRoutes.login ||
          location == AppRoutes.signUp ||
          location == AppRoutes.resetPassword;
      if (user == null) {
        return isPublicAuthRoute ? null : AppRoutes.login;
      }
      if (!user.emailVerified) {
        return location == AppRoutes.verifyEmail ? null : AppRoutes.verifyEmail;
      }
      if (location == AppRoutes.home) {
        return null;
      }
      return AppRoutes.home;
    },
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.root,
        builder: (context, state) => const StartupPage(),
      ),
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const StartupPage(),
      ),
      GoRoute(
        path: AppRoutes.unavailable,
        builder: (context, state) => const FirebaseUnavailablePage(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.signUp,
        builder: (context, state) => const SignUpPage(),
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        builder: (context, state) => const ResetPasswordPage(),
      ),
      GoRoute(
        path: AppRoutes.verifyEmail,
        builder: (context, state) => const EmailVerificationPage(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: AppRoutes.terms,
        builder: (context, state) =>
            const LegalDocumentPage(type: LegalDocumentType.terms),
      ),
      GoRoute(
        path: AppRoutes.privacy,
        builder: (context, state) =>
            const LegalDocumentPage(type: LegalDocumentType.privacy),
      ),
    ],
  );
});
