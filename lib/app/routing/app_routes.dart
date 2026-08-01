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
}
