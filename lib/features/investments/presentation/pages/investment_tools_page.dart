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
                  _resultButton('Primeiro milhão', () {
                    final p = _money('principal');
                    final c = _money('contribution');
                    final r = _number('rate');
                    if (p == null || c == null || r == null) return null;
                    final v = InvestmentTools.firstMillion(
                      initialCents: p,
                      monthlyContributionCents: c,
                      monthlyRateBasisPoints: r,
                    );
                    final int years = v.periods ~/ 12;
                    final int remainingMonths = v.periods % 12;
                    return _ToolCalculationResult(
                      title: 'Resultado — primeiro milhão',
                      summary: v.periods >= 1200 && v.amountCents < 100000000
                          ? 'A meta não foi atingida no limite de 100 anos da simulação.'
                          : 'Meta estimada em ${v.periods} meses.',
                      details: <_ToolResultDetail>[
                        _ToolResultDetail(
                          'Valor inicial',
                          _moneyText(p, visible),
                        ),
                        _ToolResultDetail(
                          'Aporte mensal',
                          _moneyText(c, visible),
                        ),
                        _ToolResultDetail('Taxa mensal', _basisPoints(r)),
                        _ToolResultDetail(
                          'Prazo',
                          '$years anos e $remainingMonths meses',
                        ),
                        _ToolResultDetail(
                          'Saldo estimado',
                          _moneyText(v.amountCents, visible),
                        ),
                      ],
                      explanation:
                          'A simulação aplica a taxa ao saldo e depois soma o aporte a cada mês. Não considera impostos, inflação, taxas ou variação de mercado.',
                    );
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
                  _resultButton('Juros simples e compostos', () {
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
                    final int contribution = _money('contribution') ?? 0;
                    return _ToolCalculationResult(
                      title: 'Resultado — juros',
                      summary:
                          'Comparação matemática com a mesma taxa informada em duas periodicidades distintas.',
                      details: <_ToolResultDetail>[
                        _ToolResultDetail(
                          'Capital inicial',
                          _moneyText(p, visible),
                        ),
                        _ToolResultDetail('Taxa informada', _basisPoints(r)),
                        _ToolResultDetail(
                          'Juros simples',
                          _moneyText(simple.interestCents, visible),
                        ),
                        _ToolResultDetail(
                          'Total simples',
                          _moneyText(simple.totalCents, visible),
                        ),
                        _ToolResultDetail(
                          'Aporte mensal',
                          _moneyText(contribution, visible),
                        ),
                        _ToolResultDetail(
                          'Juros compostos',
                          _moneyText(compound.interestCents, visible),
                        ),
                        _ToolResultDetail(
                          'Total composto',
                          _moneyText(compound.totalCents, visible),
                        ),
                      ],
                      explanation:
                          'No cálculo simples, a taxa é anual e o número informado representa dias. No composto, a taxa é mensal e o mesmo número representa meses; os aportes entram ao fim de cada mês.',
                    );
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
                  _resultButton('Porcentagem', () {
                    final b = _money('base');
                    final r = _number('percentage');
                    if (b == null || r == null) return null;
                    final v = InvestmentTools.percentage(
                      baseCents: b,
                      rateBasisPoints: r,
                      operation: _percentageOperation,
                    );
                    final String operation =
                        _percentageOperation == PercentageOperation.increase
                        ? 'Aumento'
                        : 'Desconto';
                    return _ToolCalculationResult(
                      title: 'Resultado — porcentagem',
                      summary:
                          '$operation de ${_basisPoints(r)} sobre o valor-base.',
                      details: <_ToolResultDetail>[
                        _ToolResultDetail('Valor-base', _moneyText(b, visible)),
                        _ToolResultDetail('Operação', operation),
                        _ToolResultDetail('Percentual', _basisPoints(r)),
                        _ToolResultDetail(
                          'Variação',
                          _moneyText(v.deltaCents, visible),
                        ),
                        _ToolResultDetail(
                          'Resultado',
                          _moneyText(v.resultCents, visible),
                        ),
                      ],
                      explanation:
                          'O percentual é aplicado diretamente sobre o valor-base informado. Descontos nunca produzem resultado monetário negativo.',
                    );
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
                  _resultButton('Graham e Bazin', () {
                    final eps = _money('eps');
                    final vpa = _money('vpa');
                    final d = _money('dividend');
                    final y = _number('yield');
                    final List<_ToolResultDetail> values =
                        <_ToolResultDetail>[];
                    if (eps != null && vpa != null && eps > 0 && vpa > 0) {
                      values.add(
                        _ToolResultDetail(
                          'Preço justo de Graham',
                          _moneyText(
                            InvestmentTools.grahamFairPriceCents(
                              earningsPerShareCents: eps,
                              bookValuePerShareCents: vpa,
                            ),
                            visible,
                          ),
                        ),
                      );
                    }
                    if (d != null && y != null && d > 0 && y > 0) {
                      values.add(
                        _ToolResultDetail(
                          'Preço-teto de Bazin',
                          _moneyText(
                            InvestmentTools.bazinCeilingPriceCents(
                              annualDividendPerShareCents: d,
                              desiredYieldBasisPoints: y,
                            ),
                            visible,
                          ),
                        ),
                      );
                    }
                    if (values.isEmpty) return null;
                    return _ToolCalculationResult(
                      title: 'Resultado — Graham e Bazin',
                      summary:
                          'Referências matemáticas calculadas apenas com os dados manuais válidos.',
                      details: values,
                      explanation:
                          'Graham usa √(22,5 × LPA × VPA). Bazin divide o dividendo anual por cota pelo yield desejado. As fórmulas não avaliam qualidade, risco, liquidez ou preço de mercado e não constituem recomendação.',
                    );
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
                  _resultButton('Análise manual', () {
                    final analysis = ManualAssetAnalysis(
                      kind: _assetKind,
                      positive: _positive,
                      attention: _attention,
                      completedChecklistItems: _checked,
                      totalChecklistItems: 5,
                    );
                    return _ToolCalculationResult(
                      title: 'Resultado — análise manual',
                      summary:
                          '${_assetKind == ManualAssetKind.stock ? 'Ação' : 'FII'} com $_checked de 5 itens do checklist preenchidos.',
                      details: analysis.findings
                          .map(
                            (InvestmentFinding finding) => _ToolResultDetail(
                              _findingLabel(finding.kind),
                              finding.message,
                            ),
                          )
                          .toList(growable: false),
                      explanation:
                          'O resultado organiza somente as marcações informadas. Ele não atribui nota, não consulta mercado e não recomenda comprar, vender ou manter.',
                    );
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
                  _resultButton('Comparação de ativos', () {
                    final ManualAssetComparison comparison =
                        ManualAssetComparison(
                          firstName: _fields['firstAsset']!.text,
                          firstChecklistItems: _firstComparisonItems,
                          secondName: _fields['secondAsset']!.text,
                          secondChecklistItems: _secondComparisonItems,
                        );
                    final InvestmentFinding finding = comparison.finding;
                    return _ToolCalculationResult(
                      title: 'Resultado — comparação manual',
                      summary: finding.message,
                      details: <_ToolResultDetail>[
                        _ToolResultDetail(
                          comparison.firstName.trim().isEmpty
                              ? 'Primeiro ativo'
                              : comparison.firstName.trim(),
                          '$_firstComparisonItems de 5 itens',
                        ),
                        _ToolResultDetail(
                          comparison.secondName.trim().isEmpty
                              ? 'Segundo ativo'
                              : comparison.secondName.trim(),
                          '$_secondComparisonItems de 5 itens',
                        ),
                        _ToolResultDetail(
                          _findingLabel(finding.kind),
                          finding.message,
                        ),
                      ],
                      explanation:
                          'A comparação considera apenas a quantidade de critérios manuais preenchidos. Mais itens não significam melhor investimento e não constituem recomendação.',
                    );
                  }),
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
      key: ValueKey<String>('investment-tool-field-$label'),
      controller: _fields[name],
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, hintText: '0,00'),
    ),
  );

  Widget _textField(String label, String name) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: TextField(
      key: ValueKey<String>('investment-tool-field-$label'),
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
      key: ValueKey<String>('investment-tool-field-$label'),
      controller: _fields[name],
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label, helperText: suffix),
    ),
  );
  String _basisPoints(int value) {
    final String percentage = (value / 100).toStringAsFixed(2);
    return '${percentage.replaceAll('.', ',')}%';
  }

  String _findingLabel(InvestmentFindingKind kind) => switch (kind) {
    InvestmentFindingKind.positive => 'Ponto positivo',
    InvestmentFindingKind.attention => 'Ponto de atenção',
    InvestmentFindingKind.insufficient => 'Dados insuficientes',
  };

  Widget _resultButton(
    String title,
    _ToolCalculationResult? Function() calculation,
  ) => Align(
    alignment: Alignment.centerLeft,
    child: FilledButton.tonalIcon(
      onPressed: () async {
        _ToolCalculationResult? result;
        try {
          result = calculation();
        } on ArgumentError {
          result = null;
        }
        await _showResultDialog(
          result ??
              _ToolCalculationResult(
                title: 'Não foi possível calcular',
                summary: 'Revise os campos de $title.',
                details: const <_ToolResultDetail>[
                  _ToolResultDetail(
                    'Dados necessários',
                    'Preencha valores válidos e compatíveis antes de calcular.',
                  ),
                ],
                explanation:
                    'Nenhum resultado foi estimado e nenhum dado foi salvo.',
              ),
        );
      },
      icon: const Icon(Icons.calculate_outlined),
      label: const Text('Calcular'),
    ),
  );

  Future<void> _showResultDialog(_ToolCalculationResult result) =>
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) => PopScope(
          canPop: false,
          child: Semantics(
            scopesRoute: true,
            namesRoute: true,
            explicitChildNodes: true,
            label: result.title,
            child: AlertDialog(
              titlePadding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.xs,
                0,
              ),
              title: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(child: Text(result.title)),
                  IconButton(
                    key: const ValueKey<String>('investment-result-close'),
                    tooltip: 'Fechar resultado',
                    autofocus: true,
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        result.summary,
                        style: Theme.of(dialogContext).textTheme.titleSmall,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      for (final _ToolResultDetail detail in result.details)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Semantics(
                            label: '${detail.label}: ${detail.value}',
                            child: ExcludeSemantics(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    detail.label,
                                    style: Theme.of(
                                      dialogContext,
                                    ).textTheme.labelLarge,
                                  ),
                                  const SizedBox(height: AppSpacing.xxs),
                                  SelectableText(detail.value),
                                ],
                              ),
                            ),
                          ),
                        ),
                      const Divider(),
                      Text(
                        result.explanation,
                        style: Theme.of(dialogContext).textTheme.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Resultado informativo. Não é recomendação financeira.',
                        style: Theme.of(dialogContext).textTheme.labelMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

final class _ToolCalculationResult {
  const _ToolCalculationResult({
    required this.title,
    required this.summary,
    required this.details,
    required this.explanation,
  });

  final String title;
  final String summary;
  final List<_ToolResultDetail> details;
  final String explanation;
}

final class _ToolResultDetail {
  const _ToolResultDetail(this.label, this.value);

  final String label;
  final String value;
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
