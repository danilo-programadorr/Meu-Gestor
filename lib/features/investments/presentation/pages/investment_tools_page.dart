import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_gestor_financeiro/app/navigation/global_quick_navigation.dart';
import 'package:meu_gestor_financeiro/app/routing/app_routes.dart';
import 'package:meu_gestor_financeiro/app/routing/safe_back_navigation.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
import 'package:meu_gestor_financeiro/core/privacy/financial_privacy_controller.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_tools.dart';
import 'package:meu_gestor_financeiro/features/investments/presentation/widgets/investment_view_support.dart';

enum _FirstMillionMode { discoverTerm, discoverContribution }

class InvestmentToolsPage extends ConsumerStatefulWidget {
  const InvestmentToolsPage({super.key});
  @override
  ConsumerState<InvestmentToolsPage> createState() =>
      _InvestmentToolsPageState();
}

class _InvestmentToolsPageState extends ConsumerState<InvestmentToolsPage> {
  static const String _firstMillionExplanation =
      'A taxa mensal é aplicada ao saldo e o aporte entra ao fim de cada mês. O cálculo é uma simulação matemática: não garante rentabilidade e não considera inflação, impostos, taxas, perdas ou mudanças no aporte.';
  final Map<String, TextEditingController> _fields =
      <String, TextEditingController>{
        for (final String name in <String>[
          'firstMillionInitial',
          'firstMillionContribution',
          'firstMillionRate',
          'firstMillionYears',
          'firstMillionMonths',
          'simplePrincipal',
          'simpleRate',
          'simpleDays',
          'compoundPrincipal',
          'compoundRate',
          'compoundMonths',
          'compoundContribution',
          'eps',
          'vpa',
          'dividend',
          'yield',
          'percentageBase',
          'percentageRate',
          'variationInitial',
          'variationFinal',
          'firstAsset',
          'secondAsset',
        ])
          name: TextEditingController(),
      };
  PercentageOperation _percentageOperation = PercentageOperation.increase;
  _FirstMillionMode _firstMillionMode = _FirstMillionMode.discoverTerm;
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

  int? _percentageBasisPoints(String name) {
    final String raw = _fields[name]!.text.trim().replaceAll(',', '.');
    final RegExpMatch? match = RegExp(
      r'^(\d+)(?:\.(\d{1,2}))?$',
    ).firstMatch(raw);
    if (match == null) return null;
    return int.parse(match.group(1)!) * 100 +
        int.parse((match.group(2) ?? '').padRight(2, '0'));
  }

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
              Card(
                child: ListTile(
                  leading: const Icon(Icons.auto_graph_outlined),
                  title: const Text('Preço justo'),
                  subtitle: const Text(
                    'Referências fundamentais e patrimoniais',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.fairValue),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const _Notice(),
              const SizedBox(height: AppSpacing.md),
              _ToolCard(
                title: 'Primeiro milhão',
                subtitle:
                    'Descubra o prazo ou o aporte mensal necessário para alcançar R\$ 1.000.000,00.',
                children: <Widget>[
                  SegmentedButton<_FirstMillionMode>(
                    segments: const <ButtonSegment<_FirstMillionMode>>[
                      ButtonSegment<_FirstMillionMode>(
                        value: _FirstMillionMode.discoverTerm,
                        icon: Icon(Icons.schedule_outlined),
                        label: Text('Descobrir prazo'),
                      ),
                      ButtonSegment<_FirstMillionMode>(
                        value: _FirstMillionMode.discoverContribution,
                        icon: Icon(Icons.savings_outlined),
                        label: Text('Descobrir aporte'),
                      ),
                    ],
                    selected: <_FirstMillionMode>{_firstMillionMode},
                    onSelectionChanged: (Set<_FirstMillionMode> values) =>
                        setState(() => _firstMillionMode = values.single),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _moneyField(
                    'Valor inicial (R\$)',
                    'firstMillionInitial',
                    helper: 'Valor já disponível no início da simulação.',
                  ),
                  if (_firstMillionMode == _FirstMillionMode.discoverTerm)
                    _moneyField(
                      'Aporte mensal (R\$)',
                      'firstMillionContribution',
                      helper: 'Aporte realizado ao fim de cada mês.',
                    ),
                  _percentageField(
                    'Rentabilidade mensal estimada (%)',
                    'firstMillionRate',
                    helper: 'Ex.: 0,80 significa 0,80% ao mês.',
                  ),
                  if (_firstMillionMode ==
                      _FirstMillionMode.discoverContribution) ...<Widget>[
                    _integerField(
                      'Prazo desejado — anos',
                      'firstMillionYears',
                      suffix: 'Informe zero se o prazo tiver menos de um ano.',
                    ),
                    _integerField(
                      'Prazo adicional — meses',
                      'firstMillionMonths',
                      suffix: 'De 0 a 11 meses.',
                    ),
                  ],
                  _resultButton('Primeiro milhão', () {
                    final int? initial = _money('firstMillionInitial');
                    final int? rate = _percentageBasisPoints(
                      'firstMillionRate',
                    );
                    if (initial == null || rate == null) return null;
                    if (_firstMillionMode == _FirstMillionMode.discoverTerm) {
                      final int? contribution = _money(
                        'firstMillionContribution',
                      );
                      if (contribution == null ||
                          (initial == 0 && contribution == 0)) {
                        return null;
                      }
                      final InvestmentProjection result =
                          InvestmentTools.firstMillion(
                            initialCents: initial,
                            monthlyContributionCents: contribution,
                            monthlyRateBasisPoints: rate,
                          );
                      final int contributed =
                          initial + contribution * result.periods;
                      final int earnings = result.amountCents - contributed;
                      final bool reached = result.amountCents >= 100000000;
                      return _ToolCalculationResult(
                        title: 'Resultado — prazo para o primeiro milhão',
                        summary: reached
                            ? 'Com os valores informados, a meta é alcançada em ${_duration(result.periods)}.'
                            : 'A meta não foi alcançada no limite de 100 anos da simulação.',
                        details: <_ToolResultDetail>[
                          const _ToolResultDetail('Meta', 'R\$ 1.000.000,00'),
                          _ToolResultDetail(
                            'Valor inicial',
                            _moneyText(initial, visible),
                          ),
                          _ToolResultDetail(
                            'Aporte ao fim de cada mês',
                            _moneyText(contribution, visible),
                          ),
                          _ToolResultDetail(
                            'Rentabilidade mensal estimada',
                            _basisPoints(rate),
                          ),
                          _ToolResultDetail(
                            'Prazo estimado',
                            _duration(result.periods),
                          ),
                          _ToolResultDetail(
                            'Total colocado por você',
                            _moneyText(contributed, visible),
                          ),
                          _ToolResultDetail(
                            'Rendimento matemático estimado',
                            _moneyText(earnings < 0 ? 0 : earnings, visible),
                          ),
                          _ToolResultDetail(
                            'Saldo final estimado',
                            _moneyText(result.amountCents, visible),
                          ),
                        ],
                        explanation: _firstMillionExplanation,
                      );
                    }
                    final int? years = _number('firstMillionYears');
                    final int? additionalMonths = _number('firstMillionMonths');
                    if (years == null ||
                        additionalMonths == null ||
                        years < 0 ||
                        additionalMonths < 0 ||
                        additionalMonths > 11) {
                      return null;
                    }
                    final int months = years * 12 + additionalMonths;
                    if (months <= 0) return null;
                    final RequiredContributionResult result =
                        InvestmentTools.firstMillionRequiredContribution(
                          initialCents: initial,
                          monthlyRateBasisPoints: rate,
                          months: months,
                        );
                    final int contributed =
                        initial + result.monthlyContributionCents * months;
                    final int earnings = result.amountCents - contributed;
                    return _ToolCalculationResult(
                      title: 'Resultado — aporte para o primeiro milhão',
                      summary:
                          'Para buscar a meta em ${_duration(months)}, o aporte mínimo estimado é ${_moneyText(result.monthlyContributionCents, visible)} por mês.',
                      details: <_ToolResultDetail>[
                        const _ToolResultDetail('Meta', 'R\$ 1.000.000,00'),
                        _ToolResultDetail(
                          'Valor inicial',
                          _moneyText(initial, visible),
                        ),
                        _ToolResultDetail('Prazo desejado', _duration(months)),
                        _ToolResultDetail(
                          'Rentabilidade mensal estimada',
                          _basisPoints(rate),
                        ),
                        _ToolResultDetail(
                          'Aporte mínimo ao fim de cada mês',
                          _moneyText(result.monthlyContributionCents, visible),
                        ),
                        _ToolResultDetail(
                          'Total colocado por você',
                          _moneyText(contributed, visible),
                        ),
                        _ToolResultDetail(
                          'Rendimento matemático estimado',
                          _moneyText(earnings < 0 ? 0 : earnings, visible),
                        ),
                        _ToolResultDetail(
                          'Saldo final estimado',
                          _moneyText(result.amountCents, visible),
                        ),
                      ],
                      explanation: _firstMillionExplanation,
                    );
                  }),
                ],
              ),
              _ToolCard(
                title: 'Juros simples',
                subtitle: 'Taxa anual proporcional ao número exato de dias.',
                children: <Widget>[
                  _moneyField('Capital inicial (R\$)', 'simplePrincipal'),
                  _percentageField(
                    'Taxa anual (%)',
                    'simpleRate',
                    helper: 'Ex.: 12,00 significa 12% ao ano.',
                  ),
                  _integerField(
                    'Prazo (dias)',
                    'simpleDays',
                    suffix: 'Base de cálculo: 365 dias por ano.',
                  ),
                  _resultButton('Juros simples', () {
                    final int? principal = _money('simplePrincipal');
                    final int? rate = _percentageBasisPoints('simpleRate');
                    final int? days = _number('simpleDays');
                    if (principal == null ||
                        rate == null ||
                        days == null ||
                        days <= 0) {
                      return null;
                    }
                    final InterestResult result =
                        InvestmentTools.simpleInterest(
                          principalCents: principal,
                          annualRateBasisPoints: rate,
                          days: days,
                        );
                    return _ToolCalculationResult(
                      title: 'Resultado — juros simples',
                      summary:
                          'Juros proporcionais de ${_basisPoints(rate)} ao ano durante $days dias.',
                      details: <_ToolResultDetail>[
                        _ToolResultDetail(
                          'Capital inicial',
                          _moneyText(principal, visible),
                        ),
                        _ToolResultDetail('Taxa anual', _basisPoints(rate)),
                        _ToolResultDetail('Prazo', '$days dias'),
                        _ToolResultDetail(
                          'Juros estimados',
                          _moneyText(result.interestCents, visible),
                        ),
                        _ToolResultDetail(
                          'Montante final',
                          _moneyText(result.totalCents, visible),
                        ),
                      ],
                      explanation:
                          'Fórmula: capital × taxa anual × dias ÷ 365. Não há capitalização nem aportes.',
                    );
                  }),
                ],
              ),
              _ToolCard(
                title: 'Juros compostos',
                subtitle:
                    'Capitalização mensal com aporte opcional ao fim de cada mês.',
                children: <Widget>[
                  _moneyField('Capital inicial (R\$)', 'compoundPrincipal'),
                  _percentageField(
                    'Taxa mensal (%)',
                    'compoundRate',
                    helper: 'Ex.: 0,80 significa 0,80% ao mês.',
                  ),
                  _integerField('Prazo (meses)', 'compoundMonths'),
                  _moneyField(
                    'Aporte mensal opcional (R\$)',
                    'compoundContribution',
                    helper: 'Deixe vazio para considerar R\$ 0,00.',
                  ),
                  _resultButton('Juros compostos', () {
                    final int? principal = _money('compoundPrincipal');
                    final int? rate = _percentageBasisPoints('compoundRate');
                    final int? months = _number('compoundMonths');
                    final int contribution =
                        _money('compoundContribution') ?? 0;
                    if (principal == null ||
                        rate == null ||
                        months == null ||
                        months <= 0) {
                      return null;
                    }
                    final InterestResult result =
                        InvestmentTools.compoundInterest(
                          principalCents: principal,
                          monthlyRateBasisPoints: rate,
                          months: months,
                          monthlyContributionCents: contribution,
                        );
                    return _ToolCalculationResult(
                      title: 'Resultado — juros compostos',
                      summary:
                          'Capitalização de ${_basisPoints(rate)} ao mês por ${_duration(months)}.',
                      details: <_ToolResultDetail>[
                        _ToolResultDetail(
                          'Capital inicial',
                          _moneyText(principal, visible),
                        ),
                        _ToolResultDetail('Taxa mensal', _basisPoints(rate)),
                        _ToolResultDetail('Prazo', _duration(months)),
                        _ToolResultDetail(
                          'Aporte ao fim de cada mês',
                          _moneyText(contribution, visible),
                        ),
                        _ToolResultDetail(
                          'Total aportado',
                          _moneyText(contribution * months, visible),
                        ),
                        _ToolResultDetail(
                          'Juros estimados',
                          _moneyText(result.interestCents, visible),
                        ),
                        _ToolResultDetail(
                          'Montante final',
                          _moneyText(result.totalCents, visible),
                        ),
                      ],
                      explanation:
                          'A taxa é aplicada ao saldo acumulado e o aporte entra ao fim de cada mês. Impostos, inflação e custos não são considerados.',
                    );
                  }),
                ],
              ),
              _ToolCard(
                title: 'Porcentagem',
                subtitle: 'Aumento, desconto e variação sobre um valor manual.',
                children: <Widget>[
                  _moneyField('Valor-base (R\$)', 'percentageBase'),
                  _percentageField(
                    'Percentual (%)',
                    'percentageRate',
                    helper: 'Ex.: 10,50 significa 10,50%.',
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
                    final b = _money('percentageBase');
                    final r = _percentageBasisPoints('percentageRate');
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
                title: 'Variação percentual',
                subtitle:
                    'Compara um valor inicial com um valor final, indicando alta, queda ou estabilidade.',
                children: <Widget>[
                  _moneyField('Valor inicial (R\$)', 'variationInitial'),
                  _moneyField('Valor final (R\$)', 'variationFinal'),
                  _resultButton('Variação percentual', () {
                    final int? initial = _money('variationInitial');
                    final int? finalValue = _money('variationFinal');
                    if (initial == null || finalValue == null || initial <= 0) {
                      return null;
                    }
                    final PercentageVariationResult result =
                        InvestmentTools.percentageVariation(
                          initialCents: initial,
                          finalCents: finalValue,
                        );
                    final String direction = result.differenceCents > 0
                        ? 'Aumento'
                        : result.differenceCents < 0
                        ? 'Redução'
                        : 'Sem variação';
                    return _ToolCalculationResult(
                      title: 'Resultado — variação percentual',
                      summary:
                          '$direction de ${_signedBasisPoints(result.variationBasisPoints)} entre os valores informados.',
                      details: <_ToolResultDetail>[
                        _ToolResultDetail(
                          'Valor inicial',
                          _moneyText(initial, visible),
                        ),
                        _ToolResultDetail(
                          'Valor final',
                          _moneyText(finalValue, visible),
                        ),
                        _ToolResultDetail('Direção', direction),
                        _ToolResultDetail(
                          'Diferença nominal',
                          _signedMoney(result.differenceCents, visible),
                        ),
                        _ToolResultDetail(
                          'Variação sobre o valor inicial',
                          _signedBasisPoints(result.variationBasisPoints),
                        ),
                      ],
                      explanation:
                          'Fórmula: (valor final − valor inicial) ÷ valor inicial × 100. O valor inicial precisa ser maior que zero.',
                    );
                  }),
                ],
              ),
              _ToolCard(
                title: 'Preço justo de Graham',
                subtitle:
                    'Referência matemática para ações com LPA e VPA positivos; não é cotação nem recomendação.',
                children: <Widget>[
                  _moneyField(
                    'LPA — lucro por ação (R\$)',
                    'eps',
                    helper: 'Lucro líquido por ação do período analisado.',
                  ),
                  _moneyField(
                    'VPA — valor patrimonial por ação (R\$)',
                    'vpa',
                    helper: 'Patrimônio líquido por ação.',
                  ),
                  _resultButton('Preço justo de Graham', () {
                    final eps = _money('eps');
                    final vpa = _money('vpa');
                    if (eps == null || vpa == null || eps <= 0 || vpa <= 0) {
                      return null;
                    }
                    final int result = InvestmentTools.grahamFairPriceCents(
                      earningsPerShareCents: eps,
                      bookValuePerShareCents: vpa,
                    );
                    return _ToolCalculationResult(
                      title: 'Resultado — fórmula de Graham',
                      summary:
                          'Preço de referência calculado somente pelos dados manuais informados.',
                      details: <_ToolResultDetail>[
                        _ToolResultDetail(
                          'LPA informado',
                          _moneyText(eps, visible),
                        ),
                        _ToolResultDetail(
                          'VPA informado',
                          _moneyText(vpa, visible),
                        ),
                        _ToolResultDetail(
                          'Resultado da fórmula',
                          _moneyText(result, visible),
                        ),
                      ],
                      explanation:
                          'Fórmula: √(22,5 × LPA × VPA). Exige LPA e VPA positivos e não considera qualidade, dívida, risco, liquidez ou preço de mercado.',
                    );
                  }),
                ],
              ),
              _ToolCard(
                title: 'Preço-teto de Bazin',
                subtitle:
                    'Referência matemática baseada em provento anual e retorno desejado; não é cotação nem recomendação.',
                children: <Widget>[
                  _moneyField(
                    'Provento anual por ação ou cota (R\$)',
                    'dividend',
                    helper: 'Soma anual por unidade, informada manualmente.',
                  ),
                  _percentageField(
                    'Retorno anual desejado (%)',
                    'yield',
                    helper: 'Ex.: 6,00 significa 6% ao ano.',
                  ),
                  _resultButton('Preço-teto de Bazin', () {
                    final int? dividend = _money('dividend');
                    final int? desiredYield = _percentageBasisPoints('yield');
                    if (dividend == null ||
                        desiredYield == null ||
                        dividend <= 0 ||
                        desiredYield <= 0) {
                      return null;
                    }
                    final int result = InvestmentTools.bazinCeilingPriceCents(
                      annualDividendPerShareCents: dividend,
                      desiredYieldBasisPoints: desiredYield,
                    );
                    return _ToolCalculationResult(
                      title: 'Resultado — fórmula de Bazin',
                      summary:
                          'Preço de referência para o retorno anual desejado informado.',
                      details: <_ToolResultDetail>[
                        _ToolResultDetail(
                          'Provento anual por unidade',
                          _moneyText(dividend, visible),
                        ),
                        _ToolResultDetail(
                          'Retorno anual desejado',
                          _basisPoints(desiredYield),
                        ),
                        _ToolResultDetail(
                          'Resultado da fórmula',
                          _moneyText(result, visible),
                        ),
                      ],
                      explanation:
                          'Fórmula: provento anual por unidade ÷ retorno anual desejado. Não avalia sustentabilidade dos proventos, risco, crescimento ou preço de mercado.',
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

  Widget _moneyField(String label, String name, {String? helper}) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: TextField(
      key: ValueKey<String>('investment-tool-field-$label'),
      controller: _fields[name],
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        hintText: '0,00',
        helperText: helper,
      ),
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

  Widget _percentageField(
    String label,
    String name, {
    required String helper,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: TextField(
      key: ValueKey<String>('investment-tool-field-$label'),
      controller: _fields[name],
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        hintText: '0,00',
        helperText: helper,
        suffixText: '%',
      ),
    ),
  );

  String _duration(int months) {
    final int years = months ~/ 12;
    final int remaining = months % 12;
    final List<String> parts = <String>[
      if (years > 0) '$years ${years == 1 ? 'ano' : 'anos'}',
      if (remaining > 0 || years == 0)
        '$remaining ${remaining == 1 ? 'mês' : 'meses'}',
    ];
    return parts.join(' e ');
  }

  String _basisPoints(int value) {
    final int absolute = value.abs();
    final String whole = '${absolute ~/ 100}';
    final String decimal = '${absolute % 100}'.padLeft(2, '0');
    return '${value < 0 ? '-' : ''}$whole,$decimal%';
  }

  String _signedBasisPoints(int value) =>
      value > 0 ? '+${_basisPoints(value)}' : _basisPoints(value);

  String _signedMoney(int cents, bool visible) {
    if (!visible) return InvestmentViewSupport.money(0, visible: false);
    final String amount = _moneyText(cents.abs(), true);
    return cents > 0
        ? '+$amount'
        : cents < 0
        ? '-$amount'
        : amount;
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
      key: ValueKey<String>('investment-tool-calculate-$title'),
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

  Future<void> _showResultDialog(
    _ToolCalculationResult result,
  ) => GlobalQuickNavigationModalVisibility.whileModalIsOpen(
    () => showDialog<void>(
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
