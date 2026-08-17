import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_plan.dart';

/// Contrato comercial local. Preço, elegibilidade e vigência nunca são
/// configurados aqui: a Google Play e o servidor são suas fontes de verdade.
final class PremiumProductCatalogConfiguration {
  const PremiumProductCatalogConfiguration({
    required this.subscriptionId,
    required this.monthlyBasePlanId,
    required this.annualBasePlanId,
    required this.monthlyTrialOfferId,
    required this.monthlyTrialDurationHours,
    required this.androidPackageName,
  });

  static const String approvedSubscriptionId = 'meu_gestor_premium';
  static const String approvedMonthlyBasePlanId = 'mensal';
  static const String approvedAnnualBasePlanId = 'anual';
  static const String approvedMonthlyTrialOfferId = 'teste-3d';
  static const int approvedMonthlyTrialDurationHours = 72;

  /// Um único produto de assinatura da Google Play.
  final String subscriptionId;
  final String monthlyBasePlanId;
  final String annualBasePlanId;

  /// Oferta opcional na resposta da loja, exclusiva do plano mensal.
  final String monthlyTrialOfferId;

  /// Duração comercial aprovada, que o backend verificará contra a Play.
  /// Ela não é usada pelo cliente para conceder acesso.
  final int monthlyTrialDurationHours;
  final String androidPackageName;

  bool get hasConfiguredProducts =>
      _isValidProductId(subscriptionId) &&
      _isValidBasePlanId(monthlyBasePlanId) &&
      _isValidBasePlanId(annualBasePlanId) &&
      _isValidOfferId(monthlyTrialOfferId) &&
      monthlyTrialDurationHours > 0 &&
      monthlyBasePlanId != annualBasePlanId &&
      monthlyTrialOfferId != monthlyBasePlanId &&
      monthlyTrialOfferId != annualBasePlanId;

  /// Impede que um define acidentalmente troque a oferta comercial aprovada.
  bool get matchesApprovedCommercialModel =>
      subscriptionId == approvedSubscriptionId &&
      monthlyBasePlanId == approvedMonthlyBasePlanId &&
      annualBasePlanId == approvedAnnualBasePlanId &&
      monthlyTrialOfferId == approvedMonthlyTrialOfferId &&
      monthlyTrialDurationHours == approvedMonthlyTrialDurationHours;

  String? subscriptionIdFor(PremiumPlan plan) =>
      plan.isPremium ? subscriptionId : null;

  String? basePlanIdFor(PremiumPlan plan) => switch (plan) {
    PremiumPlan.monthly => monthlyBasePlanId,
    PremiumPlan.annual => annualBasePlanId,
    PremiumPlan.free => null,
  };

  /// Aceita somente a seleção que foi devolvida pela loja para o catálogo
  /// aprovado. O token de oferta não é comparado nem persistido fora da
  /// sessão, mas precisa existir para abrir o fluxo de compra Android.
  bool accepts(PremiumStoreProduct product) {
    if (!hasConfiguredProducts ||
        product.subscriptionId != subscriptionId ||
        product.basePlanId != basePlanIdFor(product.plan)) {
      return false;
    }
    return switch (product.plan) {
      PremiumPlan.monthly =>
        product.offerId == null || product.offerId == monthlyTrialOfferId,
      PremiumPlan.annual => product.offerId == null,
      PremiumPlan.free => false,
    };
  }

  /// A loja pode não retornar a oferta de teste para uma conta inelegível.
  /// Nesse caso, o plano mensal sem oferta continua sendo uma opção válida.
  /// Qualquer item desconhecido, duplicado ou anual com oferta invalida o
  /// catálogo inteiro em vez de abrir uma combinação errada.
  List<PremiumStoreProduct> selectDisplayProducts(
    Iterable<PremiumStoreProduct> products,
  ) {
    if (!hasConfiguredProducts) return const <PremiumStoreProduct>[];
    final List<PremiumStoreProduct> values = products.toList(growable: false);
    if (values.isEmpty ||
        values.any((PremiumStoreProduct item) => !accepts(item))) {
      return const <PremiumStoreProduct>[];
    }

    final Map<String, PremiumStoreProduct> bySelection =
        <String, PremiumStoreProduct>{};
    for (final PremiumStoreProduct item in values) {
      final String key = '${item.basePlanId}\u0000${item.offerId ?? ''}';
      if (bySelection.containsKey(key)) return const <PremiumStoreProduct>[];
      bySelection[key] = item;
    }

    final PremiumStoreProduct? monthlyTrial =
        bySelection['$monthlyBasePlanId\u0000$monthlyTrialOfferId'];
    final PremiumStoreProduct? monthlyBase =
        bySelection['$monthlyBasePlanId\u0000'];
    final PremiumStoreProduct? selectedMonthly = monthlyTrial ?? monthlyBase;
    final PremiumStoreProduct? annualBase =
        bySelection['$annualBasePlanId\u0000'];
    if (selectedMonthly == null || annualBase == null) {
      return const <PremiumStoreProduct>[];
    }
    return <PremiumStoreProduct>[selectedMonthly, annualBase];
  }

  static bool _isValidProductId(String value) =>
      RegExp(r'^[a-z0-9][a-z0-9_.]{2,127}$').hasMatch(value);

  static bool _isValidBasePlanId(String value) =>
      RegExp(r'^[a-z0-9][a-z0-9-]{1,62}$').hasMatch(value);

  static bool _isValidOfferId(String value) =>
      RegExp(r'^[a-z0-9][a-z0-9-]{1,62}$').hasMatch(value);

  bool get hasValidAndroidPackage => RegExp(
    r'^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z][a-zA-Z0-9_]*)+$',
  ).hasMatch(androidPackageName);
}

/// Uma seleção real de base plan/oferta devolvida pela Google Play.
///
/// [offerToken] só permanece em memória para abrir o fluxo nativo. Não é
/// persistido, enviado ao backend, exibido ou incluído em mensagens de erro.
final class PremiumStoreProduct {
  PremiumStoreProduct({
    required this.plan,
    required this.subscriptionId,
    required this.basePlanId,
    required this.offerToken,
    required this.title,
    required this.description,
    required this.localizedPrice,
    required this.currencyCode,
    this.offerId,
    this.offerLabel,
  }) {
    if (!plan.isPremium ||
        !_isValidProductId(subscriptionId) ||
        !_isValidPlanId(basePlanId) ||
        !_isValidOfferToken(offerToken) ||
        (offerId != null && !_isValidPlanId(offerId!)) ||
        (plan == PremiumPlan.annual && offerId != null) ||
        title.trim().isEmpty ||
        localizedPrice.trim().isEmpty ||
        !RegExp(r'^[A-Z]{3}$').hasMatch(currencyCode)) {
      throw ArgumentError.value(
        subscriptionId,
        'subscriptionId',
        'Produto inválido.',
      );
    }
  }

  final PremiumPlan plan;
  final String subscriptionId;
  final String basePlanId;
  final String? offerId;
  final String offerToken;
  final String title;
  final String description;

  /// Texto de preço devolvido pela loja para esta seleção; não é usado para
  /// autorizar compra ou acesso Premium.
  final String localizedPrice;
  final String currencyCode;
  final String? offerLabel;

  String get periodLabel => plan == PremiumPlan.monthly ? 'Mensal' : 'Anual';

  bool get isTrialOffer => offerId != null;

  static bool _isValidProductId(String value) =>
      RegExp(r'^[a-z0-9][a-z0-9_.]{2,127}$').hasMatch(value);

  static bool _isValidPlanId(String value) =>
      RegExp(r'^[a-z0-9][a-z0-9-]{1,62}$').hasMatch(value);

  static bool _isValidOfferToken(String value) =>
      value.trim().isNotEmpty && value.length <= 2048;
}

enum PremiumPurchaseUpdateStatus {
  pending,
  purchased,
  restored,
  cancelled,
  error,
}

/// Evidência transitória da Play. O payload só segue em memória até a
/// verificação do servidor e nunca integra estado visual, logs ou persistência.
final class PremiumPurchaseUpdate {
  const PremiumPurchaseUpdate({
    required this.subscriptionId,
    required this.status,
    required this.verificationPayload,
  });

  final String subscriptionId;
  final PremiumPurchaseUpdateStatus status;
  final String verificationPayload;
}

enum PremiumPurchaseVerificationOrigin { purchase, restoration }

/// Pedido não autoritativo ao servidor. O backend deve confrontar a evidência
/// com a Google Play Developer API e RTDN; nunca confia neste contexto do app.
final class PremiumPurchaseVerificationRequest {
  PremiumPurchaseVerificationRequest({
    required this.subscriptionId,
    required this.origin,
    required this.verificationPayload,
    this.requestedBasePlanId,
    this.requestedOfferId,
  }) {
    if (!_isValidSubscriptionId(subscriptionId) ||
        verificationPayload.isEmpty ||
        (requestedBasePlanId != null && requestedBasePlanId!.trim().isEmpty) ||
        (requestedOfferId != null && requestedOfferId!.trim().isEmpty)) {
      throw ArgumentError('Solicitação de verificação inválida.');
    }
  }

  final String subscriptionId;
  final PremiumPurchaseVerificationOrigin origin;
  final String verificationPayload;
  final String? requestedBasePlanId;
  final String? requestedOfferId;

  static bool _isValidSubscriptionId(String value) =>
      RegExp(r'^[a-z0-9][a-z0-9_.]{2,127}$').hasMatch(value);
}

enum PremiumPurchaseVerificationResult { confirmed, denied, unavailable }

final class PremiumBillingAvailability {
  const PremiumBillingAvailability({
    required this.storeAvailable,
    required this.productsConfigured,
    required this.backendVerificationAvailable,
    required this.identityAvailable,
    required this.appCheckPrepared,
    required this.environmentValid,
    required this.eligibleUser,
  });

  final bool storeAvailable;
  final bool productsConfigured;
  final bool backendVerificationAvailable;
  final bool identityAvailable;
  final bool appCheckPrepared;
  final bool environmentValid;
  final bool eligibleUser;

  bool get hasVerificationPrerequisites =>
      productsConfigured &&
      backendVerificationAvailable &&
      identityAvailable &&
      appCheckPrepared &&
      environmentValid &&
      eligibleUser;

  bool get canStartPurchase => storeAvailable && hasVerificationPrerequisites;

  bool get canRestorePurchase => storeAvailable && hasVerificationPrerequisites;

  String get safeMessage {
    if (!productsConfigured ||
        !backendVerificationAvailable ||
        !identityAvailable) {
      return 'Assinaturas em preparação. Nenhuma cobrança pode ser iniciada agora.';
    }
    if (!eligibleUser) {
      return 'Confirme sua sessão, e-mail e perfil antes de assinar.';
    }
    if (!storeAvailable) {
      return 'A Google Play está indisponível no momento.';
    }
    if (!environmentValid || !appCheckPrepared) {
      return 'A assinatura ainda não está disponível neste ambiente.';
    }
    return 'Assinatura disponível.';
  }
}
