import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_gestor_financeiro/app/routing/app_routes.dart';
import 'package:meu_gestor_financeiro/core/firebase/firebase_startup.dart';
import 'package:meu_gestor_financeiro/features/accounts/presentation/pages/account_details_page.dart';
import 'package:meu_gestor_financeiro/features/accounts/presentation/pages/account_form_page.dart';
import 'package:meu_gestor_financeiro/features/accounts/presentation/pages/accounts_page.dart';
import 'package:meu_gestor_financeiro/features/accounts/presentation/pages/archived_accounts_page.dart';
import 'package:meu_gestor_financeiro/features/assistant/presentation/pages/assistant_page.dart';
import 'package:meu_gestor_financeiro/features/authentication/data/auth_providers.dart';
import 'package:meu_gestor_financeiro/features/authentication/domain/auth_user.dart';
import 'package:meu_gestor_financeiro/features/authentication/presentation/pages/email_verification_page.dart';
import 'package:meu_gestor_financeiro/features/authentication/presentation/pages/firebase_unavailable_page.dart';
import 'package:meu_gestor_financeiro/features/authentication/presentation/pages/login_page.dart';
import 'package:meu_gestor_financeiro/features/authentication/presentation/pages/reset_password_page.dart';
import 'package:meu_gestor_financeiro/features/authentication/presentation/pages/sign_up_page.dart';
import 'package:meu_gestor_financeiro/features/authentication/presentation/pages/startup_page.dart';
import 'package:meu_gestor_financeiro/features/calendar/presentation/pages/financial_calendar_page.dart';
import 'package:meu_gestor_financeiro/features/categories/presentation/pages/archived_categories_page.dart';
import 'package:meu_gestor_financeiro/features/categories/presentation/pages/categories_page.dart';
import 'package:meu_gestor_financeiro/features/categories/presentation/pages/category_form_page.dart';
import 'package:meu_gestor_financeiro/features/commitments/domain/financial_commitment.dart';
import 'package:meu_gestor_financeiro/features/commitments/presentation/pages/commitment_details_page.dart';
import 'package:meu_gestor_financeiro/features/commitments/presentation/pages/commitment_form_page.dart';
import 'package:meu_gestor_financeiro/features/commitments/presentation/pages/commitments_page.dart';
import 'package:meu_gestor_financeiro/features/home/presentation/home_page.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_operation.dart';
import 'package:meu_gestor_financeiro/features/investments/presentation/pages/investment_asset_details_page.dart';
import 'package:meu_gestor_financeiro/features/investments/presentation/pages/investment_asset_form_page.dart';
import 'package:meu_gestor_financeiro/features/investments/presentation/pages/investment_income_form_page.dart';
import 'package:meu_gestor_financeiro/features/investments/presentation/pages/investment_operation_form_page.dart';
import 'package:meu_gestor_financeiro/features/investments/presentation/pages/investment_portfolio_form_page.dart';
import 'package:meu_gestor_financeiro/features/investments/presentation/pages/investment_quotes_page.dart';
import 'package:meu_gestor_financeiro/features/investments/presentation/pages/investment_tools_page.dart';
import 'package:meu_gestor_financeiro/features/investments/presentation/pages/investments_page.dart';
import 'package:meu_gestor_financeiro/features/owner_access/presentation/controllers/master_access_controller.dart';
import 'package:meu_gestor_financeiro/features/owner_access/presentation/controllers/master_access_state.dart';
import 'package:meu_gestor_financeiro/features/owner_access/presentation/pages/owner_area_page.dart';
import 'package:meu_gestor_financeiro/features/owner_access/presentation/widgets/master_access_gate.dart';
import 'package:meu_gestor_financeiro/features/privacy/presentation/legal_document_page.dart';
import 'package:meu_gestor_financeiro/features/privacy/presentation/pages/data_and_privacy_page.dart';
import 'package:meu_gestor_financeiro/features/profile/data/profile_diagnostics.dart';
import 'package:meu_gestor_financeiro/features/profile/data/user_profile_providers.dart';
import 'package:meu_gestor_financeiro/features/profile/presentation/controllers/profile_gate_controller.dart';
import 'package:meu_gestor_financeiro/features/profile/presentation/pages/legal_update_page.dart';
import 'package:meu_gestor_financeiro/features/profile/presentation/pages/privacy_consents_page.dart';
import 'package:meu_gestor_financeiro/features/profile/presentation/pages/profile_access_error_page.dart';
import 'package:meu_gestor_financeiro/features/profile/presentation/pages/profile_page.dart';
import 'package:meu_gestor_financeiro/features/profile/presentation/pages/profile_setup_page.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_transaction.dart';
import 'package:meu_gestor_financeiro/features/transactions/presentation/pages/transaction_details_page.dart';
import 'package:meu_gestor_financeiro/features/transactions/presentation/pages/transaction_form_page.dart';
import 'package:meu_gestor_financeiro/features/transactions/presentation/pages/transactions_page.dart';

final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((Ref ref) {
  final FirebaseStartupState startup = ref.watch(firebaseStartupProvider);
  final AsyncValue<AuthUser?>? authState = startup.isAvailable
      ? ref.watch(authStateProvider)
      : null;
  final AuthUser? authenticatedUser = authState?.value;
  final AsyncValue<ProfileGateState>? profileGate =
      startup.isAvailable && authenticatedUser?.emailVerified == true
      ? ref.watch(profileGateControllerProvider)
      : null;
  final ProfileDiagnostics profileDiagnostics = ref.watch(
    profileDiagnosticsProvider,
  );

  return GoRouter(
    initialLocation: AppRoutes.root,
    redirect: (context, state) {
      final String location = state.uri.path;
      final MasterAccessState masterAccess = ref.read(
        masterAccessControllerProvider,
      );
      String? redirectTo(String target, String finalState) {
        profileDiagnostics.recordGateEvent(
          stage: 'redirect-target',
          duration: Duration.zero,
          finalState: finalState,
        );
        return location == target ? null : target;
      }

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
      if (profileGate == null || profileGate.isLoading) {
        return location == AppRoutes.splash ? null : AppRoutes.splash;
      }
      if (profileGate.hasError) {
        return redirectTo(AppRoutes.profileUnavailable, 'recoverableError');
      }

      final ProfileGateState? profileState = profileGate.value;
      return switch (profileState) {
        ProfileGateProgress() => redirectTo(
          AppRoutes.splash,
          profileState.diagnosticName,
        ),
        ProfileGateUnauthenticated() => redirectTo(
          AppRoutes.login,
          profileState.diagnosticName,
        ),
        ProfileGateUnverifiedEmail() => redirectTo(
          AppRoutes.verifyEmail,
          profileState.diagnosticName,
        ),
        ProfileGateMissing() => redirectTo(
          AppRoutes.profileSetup,
          profileState.diagnosticName,
        ),
        ProfileGateLegalUpdateRequired() => redirectTo(
          AppRoutes.legalUpdate,
          profileState.diagnosticName,
        ),
        ProfileGateFailure() || ProfileGateIncompatible() => redirectTo(
          AppRoutes.profileUnavailable,
          'recoverableError',
        ),
        ProfileGateValid() =>
          location == AppRoutes.ownerArea
              ? masterAccess.isActiveOwner ||
                        masterAccess.isLoading ||
                        masterAccess.status == MasterAccessStatus.idle
                    ? null
                    : redirectTo(AppRoutes.home, 'ownerAccessDenied')
              : _isValidProfileRoute(location)
              ? null
              : redirectTo(AppRoutes.home, 'profileReady'),
        null => location == AppRoutes.splash ? null : AppRoutes.splash,
      };
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
        path: AppRoutes.calendar,
        builder: (context, state) => const FinancialCalendarPage(),
      ),
      GoRoute(
        path: AppRoutes.assistant,
        builder: (context, state) => const AssistantPage(),
      ),
      GoRoute(
        path: AppRoutes.accounts,
        builder: (context, state) => const AccountsPage(),
      ),
      GoRoute(
        path: AppRoutes.newAccount,
        builder: (context, state) => AccountFormPage(
          returnToPrevious:
              state.uri.queryParameters['returnToPrevious'] == 'true',
        ),
      ),
      GoRoute(
        path: '/contas/:accountId/editar',
        builder: (context, state) =>
            AccountFormPage(accountId: state.pathParameters['accountId']),
      ),
      GoRoute(
        path: '/contas/:accountId',
        builder: (context, state) => AccountDetailsPage(
          accountId: state.pathParameters['accountId'] ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.archivedAccounts,
        builder: (context, state) => const ArchivedAccountsPage(),
      ),
      GoRoute(
        path: AppRoutes.categories,
        builder: (context, state) => const CategoriesPage(),
      ),
      GoRoute(
        path: AppRoutes.newCategory,
        builder: (context, state) => CategoryFormPage(
          returnToPrevious:
              state.uri.queryParameters['returnToPrevious'] == 'true',
        ),
      ),
      GoRoute(
        path: '/categorias/:categoryId/editar',
        builder: (context, state) =>
            CategoryFormPage(categoryId: state.pathParameters['categoryId']),
      ),
      GoRoute(
        path: AppRoutes.archivedCategories,
        builder: (context, state) => const ArchivedCategoriesPage(),
      ),
      GoRoute(
        path: AppRoutes.transactions,
        builder: (context, state) => const TransactionsPage(),
      ),
      GoRoute(
        path: AppRoutes.newTransaction,
        builder: (context, state) => TransactionFormPage(
          initialKind: switch (state.uri.queryParameters['kind']) {
            'income' => FinancialTransactionKind.income,
            'expense' => FinancialTransactionKind.expense,
            _ => null,
          },
        ),
      ),
      GoRoute(
        path: '/lancamentos/:transactionId/editar',
        builder: (context, state) => TransactionFormPage(
          transactionId: state.pathParameters['transactionId'],
        ),
      ),
      GoRoute(
        path: '/lancamentos/:transactionId',
        builder: (context, state) => TransactionDetailsPage(
          transactionId: state.pathParameters['transactionId'] ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.payables,
        builder: (context, state) =>
            const CommitmentsPage(kind: FinancialCommitmentKind.payable),
      ),
      GoRoute(
        path: AppRoutes.newPayable,
        builder: (context, state) =>
            const CommitmentFormPage(kind: FinancialCommitmentKind.payable),
      ),
      GoRoute(
        path: '/contas-a-pagar/:commitmentId/editar',
        builder: (context, state) => CommitmentFormPage(
          kind: FinancialCommitmentKind.payable,
          commitmentId: state.pathParameters['commitmentId'],
        ),
      ),
      GoRoute(
        path: '/contas-a-pagar/:commitmentId',
        builder: (context, state) => CommitmentDetailsPage(
          kind: FinancialCommitmentKind.payable,
          commitmentId: state.pathParameters['commitmentId'] ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.receivables,
        builder: (context, state) =>
            const CommitmentsPage(kind: FinancialCommitmentKind.receivable),
      ),
      GoRoute(
        path: AppRoutes.newReceivable,
        builder: (context, state) =>
            const CommitmentFormPage(kind: FinancialCommitmentKind.receivable),
      ),
      GoRoute(
        path: '/contas-a-receber/:commitmentId/editar',
        builder: (context, state) => CommitmentFormPage(
          kind: FinancialCommitmentKind.receivable,
          commitmentId: state.pathParameters['commitmentId'],
        ),
      ),
      GoRoute(
        path: '/contas-a-receber/:commitmentId',
        builder: (context, state) => CommitmentDetailsPage(
          kind: FinancialCommitmentKind.receivable,
          commitmentId: state.pathParameters['commitmentId'] ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.investments,
        builder: (context, state) => const InvestmentsPage(),
      ),
      GoRoute(
        path: AppRoutes.investmentQuotes,
        builder: (context, state) => const InvestmentQuotesPage(),
      ),
      GoRoute(
        path: AppRoutes.investmentTools,
        builder: (context, state) => const InvestmentToolsPage(),
      ),
      GoRoute(
        path: AppRoutes.newInvestmentPortfolio,
        builder: (context, state) => const InvestmentPortfolioFormPage(),
      ),
      GoRoute(
        path: '/investimentos/carteira/:portfolioId/editar',
        builder: (context, state) => InvestmentPortfolioFormPage(
          portfolioId: state.pathParameters['portfolioId'],
        ),
      ),
      GoRoute(
        path: '/investimentos/ativo/novo',
        builder: (context, state) => InvestmentAssetFormPage(
          portfolioId: state.uri.queryParameters['portfolioId'] ?? '',
        ),
      ),
      GoRoute(
        path: '/investimentos/ativo/:assetId/editar',
        builder: (context, state) =>
            InvestmentAssetFormPage(assetId: state.pathParameters['assetId']),
      ),
      GoRoute(
        path: '/investimentos/ativo/:assetId/operacao/nova',
        builder: (context, state) => InvestmentOperationFormPage(
          assetId: state.pathParameters['assetId'] ?? '',
          initialKind: state.uri.queryParameters['kind'] == 'sell'
              ? InvestmentOperationKind.sell
              : InvestmentOperationKind.buy,
        ),
      ),
      GoRoute(
        path: '/investimentos/ativo/:assetId',
        builder: (context, state) => InvestmentAssetDetailsPage(
          assetId: state.pathParameters['assetId'] ?? '',
        ),
      ),
      GoRoute(
        path: '/investimentos/provento/novo',
        builder: (context, state) => InvestmentIncomeFormPage(
          portfolioId: state.uri.queryParameters['portfolioId'] ?? '',
        ),
      ),
      GoRoute(
        path: '/investimentos/provento/:eventId/editar',
        builder: (context, state) =>
            InvestmentIncomeFormPage(eventId: state.pathParameters['eventId']),
      ),
      GoRoute(
        path: AppRoutes.profileSetup,
        builder: (context, state) => const ProfileSetupPage(),
      ),
      GoRoute(
        path: AppRoutes.legalUpdate,
        builder: (context, state) => const LegalUpdatePage(),
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) => const ProfilePage(),
      ),
      GoRoute(
        path: AppRoutes.ownerArea,
        builder: (context, state) =>
            const MasterAccessGate(child: OwnerAreaPage()),
      ),
      GoRoute(
        path: AppRoutes.privacyConsents,
        builder: (context, state) => const PrivacyConsentsPage(),
      ),
      GoRoute(
        path: AppRoutes.dataAndPrivacy,
        builder: (context, state) => const DataAndPrivacyPage(),
      ),
      GoRoute(
        path: AppRoutes.profileUnavailable,
        builder: (context, state) => const ProfileAccessErrorPage(),
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

bool _isValidProfileRoute(String location) {
  return location == AppRoutes.home ||
      location == AppRoutes.calendar ||
      location == AppRoutes.assistant ||
      location == AppRoutes.profile ||
      location == AppRoutes.privacyConsents ||
      location == AppRoutes.accounts ||
      location == AppRoutes.archivedAccounts ||
      location.startsWith('${AppRoutes.accounts}/') ||
      location == AppRoutes.categories ||
      location == AppRoutes.archivedCategories ||
      location.startsWith('${AppRoutes.categories}/') ||
      location == AppRoutes.transactions ||
      location.startsWith('${AppRoutes.transactions}/') ||
      location == AppRoutes.payables ||
      location.startsWith('${AppRoutes.payables}/') ||
      location == AppRoutes.receivables ||
      location.startsWith('${AppRoutes.receivables}/') ||
      location == AppRoutes.investments ||
      location.startsWith('${AppRoutes.investments}/');
}
