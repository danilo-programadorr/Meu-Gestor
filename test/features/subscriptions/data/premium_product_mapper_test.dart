import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/data/premium_product_mapper.dart';
import 'package:meu_gestor_financeiro/features/subscriptions/domain/premium_plan.dart';

void main() {
  ProductDetails details({
    String id = 'premium.monthly',
    String title = 'Premium mensal',
    String price = 'R\$ 9,90',
    String currency = 'BRL',
  }) => ProductDetails(
    id: id,
    title: title,
    description: 'Descrição vinda da loja',
    price: price,
    rawPrice: 9.9,
    currencyCode: currency,
  );

  test('mapeia preço e moeda localizados recebidos da loja', () {
    final product = PremiumProductMapper.map(
      details: details(),
      plan: PremiumPlan.monthly,
    );
    expect(product.localizedPrice, 'R\$ 9,90');
    expect(product.currencyCode, 'BRL');
    expect(product.periodLabel, 'Mensal');
  });

  test('recusa produto incompleto, moeda inválida e ID ausente', () {
    for (final ProductDetails value in <ProductDetails>[
      details(title: ''),
      details(price: ''),
      details(currency: 'BR'),
      details(id: ''),
    ]) {
      expect(
        () =>
            PremiumProductMapper.map(details: value, plan: PremiumPlan.monthly),
        throwsFormatException,
      );
    }
  });
}
