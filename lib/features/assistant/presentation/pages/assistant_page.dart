import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_gestor_financeiro/app/routing/app_routes.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
import 'package:meu_gestor_financeiro/core/money/money.dart';
import 'package:meu_gestor_financeiro/core/money/money_formatter.dart';
import 'package:meu_gestor_financeiro/core/privacy/financial_privacy_controller.dart';
import 'package:meu_gestor_financeiro/features/assistant/domain/assistant_context.dart';
import 'package:meu_gestor_financeiro/features/assistant/domain/assistant_summary.dart';
import 'package:meu_gestor_financeiro/features/assistant/presentation/controllers/assistant_summary_provider.dart';
import 'package:meu_gestor_financeiro/features/profile/presentation/controllers/profile_gate_controller.dart';

class AssistantPage extends ConsumerWidget {
  const AssistantPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ProfileGateState? gate = ref
        .watch(profileGateControllerProvider)
        .value;
    final bool? consentEnabled = gate is ProfileGateValid
        ? gate.profile.aiConsentEnabled
        : null;
    final bool valuesVisible = ref.watch(financialPrivacyControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assistente financeiro'),
        actions: <Widget>[
          IconButton(
            tooltip: valuesVisible ? 'Ocultar valores' : 'Mostrar valores',
            onPressed: () =>
                ref.read(financialPrivacyControllerProvider.notifier).toggle(),
            icon: Icon(
              valuesVisible
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
          ),
        ],
      ),
      body: consentEnabled == null
          ? const Center(child: CircularProgressIndicator())
          : AssistantConsentContent(
              consentEnabled: consentEnabled,
              valuesVisible: valuesVisible,
              onManageConsent: () => context.push(AppRoutes.privacyConsents),
              enabledContent: consentEnabled
                  ? const AssistantDataExperience()
                  : null,
            ),
    );
  }
}

class AssistantConsentContent extends StatelessWidget {
  const AssistantConsentContent({
    required this.consentEnabled,
    required this.valuesVisible,
    required this.onManageConsent,
    this.enabledContent,
    super.key,
  });

  final bool consentEnabled;
  final bool valuesVisible;
  final VoidCallback onManageConsent;
  final Widget? enabledContent;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      final double horizontal = constraints.maxWidth <= 360
          ? AppSpacing.compactPageHorizontal
          : AppSpacing.pageHorizontal;
      return ListView(
        key: const ValueKey<String>('assistant-page-scroll'),
        padding: EdgeInsets.fromLTRB(
          horizontal,
          AppSpacing.md,
          horizontal,
          AppSpacing.xxl,
        ),
        children: <Widget>[
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const _AssistantHero(),
                  const SizedBox(height: AppSpacing.md),
                  const _AssistantScopeCard(),
                  const SizedBox(height: AppSpacing.md),
                  _AssistantConsentCard(
                    enabled: consentEnabled,
                    onManage: onManageConsent,
                  ),
                  if (consentEnabled && enabledContent != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.lg),
                    enabledContent!,
                  ],
                  if (!consentEnabled) ...<Widget>[
                    const SizedBox(height: AppSpacing.lg),
                    const _ConsentRequiredCard(),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  const _ReadOnlyNotice(),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
}

class AssistantDataExperience extends ConsumerStatefulWidget {
  const AssistantDataExperience({this.valuesVisibleOverride, super.key});

  final bool? valuesVisibleOverride;

  @override
  ConsumerState<AssistantDataExperience> createState() =>
      _AssistantDataExperienceState();
}

class _AssistantDataExperienceState
    extends ConsumerState<AssistantDataExperience> {
  AssistantGuidedQuestion _question = AssistantGuidedQuestion.monthlyOverview;

  @override
  Widget build(BuildContext context) {
    final AssistantReadModel model = ref.watch(assistantReadModelProvider);
    final AssistantDeterministicSummary summary =
        AssistantDeterministicSummaryBuilder.build(
          question: _question,
          snapshot: model.snapshot,
        );
    final bool valuesVisible =
        widget.valuesVisibleOverride ??
        ref.watch(financialPrivacyControllerProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'O que você quer consultar?',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Escolha uma pergunta. A resposta usa somente regras matemáticas e dados confirmados.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        _GuidedQuestions(
          selected: _question,
          onSelected: (AssistantGuidedQuestion value) {
            setState(() => _question = value);
          },
        ),
        const SizedBox(height: AppSpacing.md),
        if (model.isLoading)
          const LinearProgressIndicator(
            key: ValueKey<String>('assistant-loading'),
          ),
        _SummaryCard(summary: summary, valuesVisible: valuesVisible),
      ],
    );
  }
}

class _AssistantHero extends StatelessWidget {
  const _AssistantHero();

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: 'Assistente financeiro em modo local e sem inteligência artificial',
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.auto_awesome_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'Entenda seus números com clareza',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Faça perguntas guiadas e veja resumos objetivos, sem alterar nenhum dado.',
            ),
            const SizedBox(height: AppSpacing.sm),
            const _StatusChip(label: 'Modo local • sem IA conectada'),
          ],
        ),
      ),
    ),
  );
}

class _AssistantScopeCard extends StatelessWidget {
  const _AssistantScopeCard();

  @override
  Widget build(BuildContext context) => Card(
    child: ExpansionTile(
      key: const ValueKey<String>('assistant-visible-scope'),
      initiallyExpanded: true,
      leading: const Icon(Icons.shield_outlined),
      title: const Text('Dados usados e protegidos'),
      subtitle: const Text('Veja exatamente o escopo desta versão'),
      childrenPadding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.md,
      ),
      children: const <Widget>[
        _ScopeLine(
          icon: Icons.check_circle_outline,
          title: 'Pode consultar',
          text:
              'contas, categorias, lançamentos, compromissos, investimentos, operações e proventos do próprio usuário.',
        ),
        _ScopeLine(
          icon: Icons.block_outlined,
          title: 'Não consulta',
          text:
              'e-mail, UID, senhas, tokens, dados de terceiros, acesso owner, assinatura ou operações de privacidade.',
        ),
        _ScopeLine(
          icon: Icons.cloud_off_outlined,
          title: 'Não envia',
          text:
              'nenhum dado a serviço de IA. Cotações também não são usadas nestes resumos.',
        ),
      ],
    ),
  );
}

class _ScopeLine extends StatelessWidget {
  const _ScopeLine({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.sm),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 20),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: <InlineSpan>[
                TextSpan(
                  text: '$title: ',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: text),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _AssistantConsentCard extends StatelessWidget {
  const _AssistantConsentCard({required this.enabled, required this.onManage});

  final bool enabled;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(enabled ? Icons.verified_user_outlined : Icons.lock_outline),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  enabled ? 'Consentimento ativo' : 'Consentimento necessário',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            enabled
                ? 'Você permitiu o uso local dos seus dados para estes resumos. Pode revisar essa escolha a qualquer momento.'
                : 'Ative a preferência opcional para que o Assistente leia seus dados confirmados. Sem consentimento, nenhuma fonte financeira é carregada por esta tela.',
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: onManage,
            icon: const Icon(Icons.tune_outlined),
            label: Text(
              enabled ? 'Revisar consentimento' : 'Configurar consentimento',
            ),
          ),
        ],
      ),
    ),
  );
}

class _ConsentRequiredCard extends StatelessWidget {
  const _ConsentRequiredCard();

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey<String>('assistant-consent-required'),
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
    ),
    child: const Text(
      'As perguntas guiadas aparecerão aqui depois que você ativar o consentimento.',
      textAlign: TextAlign.center,
    ),
  );
}

class _GuidedQuestions extends StatelessWidget {
  const _GuidedQuestions({required this.selected, required this.onSelected});

  final AssistantGuidedQuestion selected;
  final ValueChanged<AssistantGuidedQuestion> onSelected;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppSpacing.xs,
    runSpacing: AppSpacing.xs,
    children: <Widget>[
      for (final AssistantGuidedQuestion question
          in AssistantGuidedQuestion.values)
        ChoiceChip(
          key: ValueKey<String>('assistant-question-${question.name}'),
          label: Text(_questionLabel(question)),
          selected: selected == question,
          onSelected: (_) => onSelected(question),
        ),
    ],
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary, required this.valuesVisible});

  final AssistantDeterministicSummary summary;
  final bool valuesVisible;

  @override
  Widget build(BuildContext context) => Card(
    key: const ValueKey<String>('assistant-summary-card'),
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(summary.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            summary.periodLabel,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(summary.observation),
          if (summary.metrics.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double width = constraints.maxWidth < 440
                    ? constraints.maxWidth
                    : (constraints.maxWidth - AppSpacing.sm) / 2;
                return Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: <Widget>[
                    for (final AssistantSummaryMetric metric in summary.metrics)
                      SizedBox(
                        width: width,
                        child: _MetricTile(
                          metric: metric,
                          valuesVisible: valuesVisible,
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Text('Fontes', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          for (final AssistantContextSource source in summary.sources)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    summary.isAvailable
                        ? Icons.verified_outlined
                        : Icons.info_outline,
                    size: 18,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      '${_sourceLabel(source)} • '
                      '${summary.isAvailable ? 'leitura confirmada' : 'indisponível'}',
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.metric, required this.valuesVisible});

  final AssistantSummaryMetric metric;
  final bool valuesVisible;

  @override
  Widget build(BuildContext context) {
    final int? moneyCents = metric.moneyCents;
    final String value = !valuesVisible
        ? 'Valor oculto'
        : moneyCents != null
        ? MoneyFormatter.format(Money.fromCents(moneyCents))
        : '${metric.count ?? 0}';
    return Semantics(
      label: '${metric.label}: $value',
      child: Container(
        constraints: const BoxConstraints(minHeight: 76),
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(metric.label, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: AppSpacing.xxs),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}

class _ReadOnlyNotice extends StatelessWidget {
  const _ReadOnlyNotice();

  @override
  Widget build(BuildContext context) => const _ScopeLine(
    icon: Icons.info_outline,
    title: 'Somente leitura',
    text:
        'os resumos não executam ações, não alteram dados e não representam recomendação financeira.',
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs,
        ),
        child: Text(label, style: Theme.of(context).textTheme.labelMedium),
      ),
    ),
  );
}

String _questionLabel(AssistantGuidedQuestion question) => switch (question) {
  AssistantGuidedQuestion.monthlyOverview => 'Como foi meu mês?',
  AssistantGuidedQuestion.currentBalance => 'Qual é meu saldo?',
  AssistantGuidedQuestion.commitmentStatus => 'Quais são minhas pendências?',
  AssistantGuidedQuestion.investmentOverview =>
    'Como estão meus investimentos?',
};

String _sourceLabel(AssistantContextSource source) => switch (source) {
  AssistantContextSource.accounts => 'Contas',
  AssistantContextSource.categories => 'Categorias',
  AssistantContextSource.transactions => 'Lançamentos',
  AssistantContextSource.payables => 'Contas a pagar',
  AssistantContextSource.receivables => 'Contas a receber',
  AssistantContextSource.investmentPortfolios => 'Carteiras de investimentos',
  AssistantContextSource.investmentAssets => 'Ativos acompanhados',
  AssistantContextSource.investmentOperations => 'Operações de investimentos',
  AssistantContextSource.investmentIncome => 'Proventos',
  AssistantContextSource.dashboardSummary => 'Resumo financeiro derivado',
  AssistantContextSource.investmentPerformance =>
    'Projeção do histórico de investimentos',
  _ => 'Fonte indisponível nesta versão',
};
