import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_gestor_financeiro/app/routing/app_routes.dart';
import 'package:meu_gestor_financeiro/app/routing/safe_back_navigation.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
import 'package:meu_gestor_financeiro/core/privacy/financial_privacy_controller.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_tools.dart';
import 'package:meu_gestor_financeiro/features/investments/presentation/widgets/investment_view_support.dart';

class InvestmentToolsPage extends ConsumerStatefulWidget {
  const InvestmentToolsPage({super.key});
  @override
  ConsumerState<InvestmentToolsPage> createState() =>
      _InvestmentToolsPageState();
}

class _InvestmentToolsPageState extends ConsumerState<InvestmentToolsPage> {
  final Map<String, TextEditingController> _fields =
      <String, TextEditingController>{
        for (final String name in <String>[
          'principal',
          'rate',
          'periods',
          'contribution',
          'eps',
          'vpa',
          'dividend',
          'yield',
          'base',
          'percentage',
          'firstAsset',
          'secondAsset',
        ])
          name: TextEditingController(),
      };
  PercentageOperation _percentageOperation = PercentageOperation.increase;
  ManualAssetKind _assetKind = ManualAssetKind.stock;
  bool _positive = false;
  bool _attention = false;
  int _checked = 0;
  int _firstComparisonItems = 0;
  int _secondComparisonItems = 0;

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  int? _number(String name) => int.tryParse(_fields[name]!.text.trim());
  int? _money(String name) {
    final String raw = _fields[name]!.text
        .trim()
        .replaceAll('.', '')
        .replaceAll(',', '.');
    final match = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(raw);
    if (match == null) return null;
    return int.parse(match.group(1)!) * 100 +
        int.parse((match.group(2) ?? '').padRight(2, '0'));
  }

  String _moneyText(int cents, bool visible) =>
      InvestmentViewSupport.money(cents, visible: visible);

  @override
  Widget build(BuildContext context) {
    final bool visible = ref.watch(financialPrivacyControllerProvider);
    return SafeBackScope(
      fallbackLocation: AppRoutes.investments,
      child: Scaffold(
        appBar: AppBar(
          leading: const SafeBackButton(
            fallbackLocation: AppRoutes.investments,
          ),
          title: const Text('Calculadoras e análises'),
          actions: <Widget>[
            InvestmentPrivacyButton(
              valuesVisible: visible,
              onPressed: () => ref
                  .read(financialPrivacyControllerProvider.notifier)
                  .toggle(),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.compactPageHorizontal,
              AppSpacing.md,
              AppSpacing.compactPageHorizontal,
              AppSpacing.xxl,
            ),
            children: <Widget>[
              const _Notice(),
              const SizedBox(height: AppSpacing.md),
              _ToolCard(
                title: 'Primeiro milhão',
                subtitle: 'Simula aportes mensais até R\$ 1.000.000,00.',
                children: <Widget>[
                  _moneyField('Valor inicial', 'principal'),
                  _moneyField('Aporte mensal', 'contribution'),
                  _integerField(
                    'Rentabilidade mensal (%)',
                    'rate',
                    suffix: 'Use pontos-base: 100 = 1%',
                  ),
                  _resultButton(() {
                    final p = _money('principal');
                    final c = _money('contribution');
                    final r = _number('rate');
                    if (p == null || c == null || r == null) return null;
                    final v = InvestmentTools.firstMillion(
                      initialCents: p,
                      monthlyContributionCents: c,
                      monthlyRateBasisPoints: r,
                    );
                    return 'Estimativa: ${v.periods} meses; saldo ${_moneyText(v.amountCents, visible)}.';
                  }),
                ],
              ),
              _ToolCard(
                title: 'Juros simples e compostos',
                subtitle:
                    'Cálculo determinístico por períodos. Juros compostos usam taxa mensal.',
                children: <Widget>[
                  _moneyField('Capital inicial', 'principal'),
                  _integerField(
                    'Taxa (pontos-base)',
                    'rate',
                    suffix: '100 = 1%',
                  ),
                  _integerField('Períodos', 'periods'),
                  _moneyField('Aporte mensal (opcional)', 'contribution'),
                  _resultButton(() {
                    final p = _money('principal');
                    final r = _number('rate');
                    final n = _number('periods');
                    if (p == null || r == null || n == null || n <= 0) {
                      return null;
                    }
                    final simple = InvestmentTools.simpleInterest(
                      principalCents: p,
                      annualRateBasisPoints: r,
                      days: n,
                    );
                    final compound = InvestmentTools.compoundInterest(
                      principalCents: p,
                      monthlyRateBasisPoints: r,
                      months: n,
                      monthlyContributionCents: _money('contribution') ?? 0,
                    );
                    return 'Simples: ${_moneyText(simple.totalCents, visible)}. Compostos: ${_moneyText(compound.totalCents, visible)}.';
                  }),
                ],
              ),
              _ToolCard(
                title: 'Porcentagem',
                subtitle: 'Aumento, desconto e variação sobre um valor manual.',
                children: <Widget>[
                  _moneyField('Valor-base', 'base'),
                  _integerField(
                    'Percentual (pontos-base)',
                    'percentage',
                    suffix: '100 = 1%',
                  ),
                  DropdownButtonFormField<PercentageOperation>(
                    initialValue: _percentageOperation,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Operação'),
                    items: const <DropdownMenuItem<PercentageOperation>>[
                      DropdownMenuItem(
                        value: PercentageOperation.increase,
                        child: Text('Aumento'),
                      ),
                      DropdownMenuItem(
                        value: PercentageOperation.discount,
                        child: Text('Desconto'),
                      ),
                    ],
                    onChanged: (v) => setState(() => _percentageOperation = v!),
                  ),
                  _resultButton(() {
                    final b = _money('base');
                    final r = _number('percentage');
                    if (b == null || r == null) return null;
                    final v = InvestmentTools.percentage(
                      baseCents: b,
                      rateBasisPoints: r,
                      operation: _percentageOperation,
                    );
                    return 'Variação: ${_moneyText(v.deltaCents, visible)}. Resultado: ${_moneyText(v.resultCents, visible)}.';
                  }),
                ],
              ),
              _ToolCard(
                title: 'Preço justo de Graham e preço-teto de Bazin',
                subtitle:
                    'Fórmulas de referência, não recomendação ou cotação.',
                children: <Widget>[
                  _moneyField('LPA — lucro por ação', 'eps'),
                  _moneyField('VPA — valor patrimonial por ação', 'vpa'),
                  _moneyField('Dividendo anual por cota', 'dividend'),
                  _integerField(
                    'Yield desejado (pontos-base)',
                    'yield',
                    suffix: '600 = 6%',
                  ),
                  _resultButton(() {
                    final eps = _money('eps');
                    final vpa = _money('vpa');
                    final d = _money('dividend');
                    final y = _number('yield');
                    final List<String> values = <String>[];
                    if (eps != null && vpa != null && eps > 0 && vpa > 0) {
                      values.add(
                        'Graham: ${_moneyText(InvestmentTools.grahamFairPriceCents(earningsPerShareCents: eps, bookValuePerShareCents: vpa), visible)}',
                      );
                    }
                    if (d != null && y != null && d > 0 && y > 0) {
                      values.add(
                        'Bazin: ${_moneyText(InvestmentTools.bazinCeilingPriceCents(annualDividendPerShareCents: d, desiredYieldBasisPoints: y), visible)}',
                      );
                    }
                    return values.isEmpty ? null : values.join(' · ');
                  }),
                ],
              ),
              _ToolCard(
                title: 'Análise manual de ações e FIIs',
                subtitle:
                    'Checklist pessoal, sem dados de mercado, nota, recomendação ou ordem.',
                children: <Widget>[
                  DropdownButtonFormField<ManualAssetKind>(
                    initialValue: _assetKind,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de ativo',
                    ),
                    items: const <DropdownMenuItem<ManualAssetKind>>[
                      DropdownMenuItem(
                        value: ManualAssetKind.stock,
                        child: Text('Ação'),
                      ),
                      DropdownMenuItem(
                        value: ManualAssetKind.fii,
                        child: Text('FII'),
                      ),
                    ],
                    onChanged: (v) => setState(() => _assetKind = v!),
                  ),
                  CheckboxListTile(
                    value: _positive,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) => setState(() => _positive = v ?? false),
                    title: const Text('Marcar um ponto positivo documentado'),
                  ),
                  CheckboxListTile(
                    value: _attention,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) => setState(() => _attention = v ?? false),
                    title: const Text('Marcar um ponto de atenção'),
                  ),
                  DropdownButtonFormField<int>(
                    initialValue: _checked,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Itens concluídos do checklist Buy and Hold',
                    ),
                    items: List<DropdownMenuItem<int>>.generate(
                      6,
                      (i) => DropdownMenuItem(
                        value: i,
                        child: Text('$i de 5 itens'),
                      ),
                    ),
                    onChanged: (v) => setState(() => _checked = v!),
                  ),
                  _resultButton(() {
                    final analysis = ManualAssetAnalysis(
                      kind: _assetKind,
                      positive: _positive,
                      attention: _attention,
                      completedChecklistItems: _checked,
                      totalChecklistItems: 5,
                    );
                    return analysis.findings
                        .map((f) => '${f.kind.name}: ${f.message}')
                        .join('\n');
                  }),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _ToolCard(
                title: 'Comparação de ativos',
                subtitle:
                    'Compare somente itens do seu checklist, sem cotação ou recomendação.',
                children: <Widget>[
                  _textField('Primeiro ativo', 'firstAsset'),
                  _comparisonItems(
                    'Itens do checklist — primeiro ativo',
                    _firstComparisonItems,
                    (value) => setState(() => _firstComparisonItems = value),
                  ),
                  _textField('Segundo ativo', 'secondAsset'),
                  _comparisonItems(
                    'Itens do checklist — segundo ativo',
                    _secondComparisonItems,
                    (value) => setState(() => _secondComparisonItems = value),
                  ),
                  _resultButton(
                    () => ManualAssetComparison(
                      firstName: _fields['firstAsset']!.text,
                      firstChecklistItems: _firstComparisonItems,
                      secondName: _fields['secondAsset']!.text,
                      secondChecklistItems: _secondComparisonItems,
                    ).finding.message,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _moneyField(String label, String name) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: TextField(
      controller: _fields[name],
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, hintText: '0,00'),
    ),
  );

  Widget _textField(String label, String name) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: TextField(
      controller: _fields[name],
      textCapitalization: TextCapitalization.characters,
      decoration: InputDecoration(labelText: label),
    ),
  );

  Widget _comparisonItems(
    String label,
    int value,
    ValueChanged<int> onChanged,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: DropdownButtonFormField<int>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: List<DropdownMenuItem<int>>.generate(
        6,
        (int item) =>
            DropdownMenuItem<int>(value: item, child: Text('$item de 5 itens')),
      ),
      onChanged: (int? next) {
        if (next != null) onChanged(next);
      },
    ),
  );
  Widget _integerField(String label, String name, {String? suffix}) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: TextField(
      controller: _fields[name],
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label, helperText: suffix),
    ),
  );
  Widget _resultButton(String? Function() calculation) => Align(
    alignment: Alignment.centerLeft,
    child: FilledButton.tonalIcon(
      onPressed: () {
        final message = calculation();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message ?? 'Preencha valores válidos para calcular.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      icon: const Icon(Icons.calculate_outlined),
      label: const Text('Calcular'),
    ),
  );
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.title,
    required this.subtitle,
    required this.children,
  });
  final String title;
  final String subtitle;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xxs),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: AppSpacing.md),
          ...children,
        ],
      ),
    ),
  );
}

class _Notice extends StatelessWidget {
  const _Notice();
  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: 'Aviso sobre cálculos financeiros',
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.info_outline),
            SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Resultados são matemáticos e usam apenas o que você informar. Não são recomendação de compra, venda ou manutenção. Nenhum dado é salvo, enviado ou altera sua carteira, saldo ou lançamentos.',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
