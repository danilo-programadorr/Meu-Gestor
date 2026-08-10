import 'package:meu_gestor_financeiro/features/commitments/domain/financial_commitment.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_operation.dart';

abstract final class AppRoutes {
  static const String root = '/';
  static const String login = '/login';
  static const String signUp = '/criar-conta';
  static const String resetPassword = '/redefinir-senha';
  static const String verifyEmail = '/verificar-email';
  static const String home = '/inicio';
  static const String accounts = '/contas';
  static const String newAccount = '/contas/nova';
  static const String newAccountReturning =
      '/contas/nova?returnToPrevious=true';
  static const String archivedAccounts = '/contas-arquivadas';
  static const String categories = '/categorias';
  static const String newCategory = '/categorias/nova';
  static const String newCategoryReturning =
      '/categorias/nova?returnToPrevious=true';
  static const String archivedCategories = '/categorias-arquivadas';
  static const String transactions = '/lancamentos';
  static const String newTransaction = '/lancamentos/novo';
  static const String newIncome = '/lancamentos/novo?kind=income';
  static const String newExpense = '/lancamentos/novo?kind=expense';
  static const String payables = '/contas-a-pagar';
  static const String newPayable = '/contas-a-pagar/nova';
  static const String receivables = '/contas-a-receber';
  static const String newReceivable = '/contas-a-receber/nova';
  static const String investments = '/investimentos';
  static const String newInvestmentPortfolio = '/investimentos/carteira/nova';
  static const String profileSetup = '/configurar-perfil';
  static const String legalUpdate = '/atualizar-documentos';
  static const String profile = '/perfil';
  static const String ownerArea = '/proprietario';
  static const String privacyConsents = '/privacidade-e-consentimentos';
  static const String profileUnavailable = '/perfil-indisponivel';
  static const String terms = '/termos-de-uso';
  static const String privacy = '/politica-de-privacidade';
  static const String unavailable = '/indisponivel';
  static const String splash = '/carregando';

  static String accountDetails(String accountId) =>
      '/contas/${Uri.encodeComponent(accountId)}';

  static String editAccount(String accountId) =>
      '/contas/${Uri.encodeComponent(accountId)}/editar';

  static String editCategory(String categoryId) =>
      '/categorias/${Uri.encodeComponent(categoryId)}/editar';

  static String transactionDetails(String transactionId) =>
      '/lancamentos/${Uri.encodeComponent(transactionId)}';

  static String editTransaction(String transactionId) =>
      '/lancamentos/${Uri.encodeComponent(transactionId)}/editar';

  static String commitments(FinancialCommitmentKind kind) =>
      kind == FinancialCommitmentKind.payable ? payables : receivables;

  static String newCommitment(FinancialCommitmentKind kind) =>
      kind == FinancialCommitmentKind.payable ? newPayable : newReceivable;

  static String commitmentDetails(
    FinancialCommitmentKind kind,
    String commitmentId,
  ) => '${commitments(kind)}/${Uri.encodeComponent(commitmentId)}';

  static String editCommitment(
    FinancialCommitmentKind kind,
    String commitmentId,
  ) => '${commitmentDetails(kind, commitmentId)}/editar';

  static String editInvestmentPortfolio(String portfolioId) =>
      '/investimentos/carteira/${Uri.encodeComponent(portfolioId)}/editar';

  static String newInvestmentAsset(String portfolioId) =>
      '/investimentos/ativo/novo?portfolioId=${Uri.encodeQueryComponent(portfolioId)}';

  static String investmentAssetDetails(String assetId) =>
      '/investimentos/ativo/${Uri.encodeComponent(assetId)}';

  static String newInvestmentOperation(
    String assetId,
    InvestmentOperationKind kind,
  ) => '${investmentAssetDetails(assetId)}/operacao/nova?kind=${kind.name}';
}
