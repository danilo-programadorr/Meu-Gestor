abstract interface class PremiumPurchaseIdentityGateway {
  /// Disponível somente quando o backend emite um identificador opaco por ambiente.
  bool get isAvailable;

  Future<String?> currentObfuscatedAccountId();
}
