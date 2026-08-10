import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_gestor_financeiro/app/routing/app_routes.dart';
import 'package:meu_gestor_financeiro/app/routing/safe_back_navigation.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_failure.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/tracked_investment_asset.dart';
import 'package:meu_gestor_financeiro/features/investments/presentation/controllers/investment_action_controller.dart';
import 'package:meu_gestor_financeiro/features/investments/presentation/controllers/investments_controller.dart';

class InvestmentAssetFormPage extends ConsumerStatefulWidget {
  const InvestmentAssetFormPage({required this.portfolioId, super.key});

  final String portfolioId;

  @override
  ConsumerState<InvestmentAssetFormPage> createState() =>
      _InvestmentAssetFormPageState();
}

class _InvestmentAssetFormPageState
    extends ConsumerState<InvestmentAssetFormPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _tickerController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  TrackedInvestmentAssetType _type = TrackedInvestmentAssetType.stock;

  @override
  void dispose() {
    _tickerController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final InvestmentsState? workspace = ref
        .watch(investmentsControllerProvider)
        .value;
    final InvestmentActionState action = ref.watch(
      investmentActionControllerProvider,
    );
    final portfolio = workspace?.portfolioById(widget.portfolioId);
    if (workspace == null || portfolio == null || portfolio.isArchived) {
      return _error('Esta carteira não está disponível para novos ativos.');
    }
    return SafeBackScope(
      fallbackLocation: AppRoutes.investments,
      child: Scaffold(
        appBar: AppBar(
          leading: const SafeBackButton(
            fallbackLocation: AppRoutes.investments,
          ),
          title: const Text('Adicionar ativo'),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        portfolio.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      SegmentedButton<TrackedInvestmentAssetType>(
                        segments: TrackedInvestmentAssetType.values
                            .map(
                              (TrackedInvestmentAssetType type) =>
                                  ButtonSegment<TrackedInvestmentAssetType>(
                                    value: type,
                                    label: Text(type.label),
                                  ),
                            )
                            .toList(growable: false),
                        selected: <TrackedInvestmentAssetType>{_type},
                        onSelectionChanged: action.isLoading
                            ? null
                            : (Set<TrackedInvestmentAssetType> values) =>
                                  setState(() => _type = values.single),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _tickerController,
                        enabled: !action.isLoading,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.allow(
                            RegExp('[A-Za-z0-9]'),
                          ),
                          LengthLimitingTextInputFormatter(6),
                        ],
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Ticker',
                          hintText: 'PETR4 ou HGLG11',
                          helperText: 'Será salvo em letras maiúsculas.',
                        ),
                        validator: (String? value) => _validateTicker(value),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _nameController,
                        enabled: !action.isLoading,
                        maxLength: 80,
                        decoration: const InputDecoration(
                          labelText: 'Nome do ativo',
                        ),
                        validator: (String? value) => _validateName(value),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      FilledButton(
                        onPressed: action.isLoading ? null : _submit,
                        child: action.isLoading
                            ? const SizedBox.square(
                                dimension: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  semanticsLabel: 'Adicionando ativo',
                                ),
                              )
                            : const Text('Adicionar ativo'),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const Text(
                        'Este cadastro é manual. Nenhum catálogo, cotação ou corretora será consultado.',
                        textAlign: TextAlign.center,
                      ),
                      if (action.status == InvestmentActionStatus.failure &&
                          action.message != null) ...<Widget>[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          action.message!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
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

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final bool success = await ref
        .read(investmentActionControllerProvider.notifier)
        .createAsset(
          TrackedInvestmentAssetDraft(
            portfolioId: widget.portfolioId,
            ticker: _tickerController.text,
            name: _nameController.text,
            type: _type,
          ),
        );
    if (success && mounted) {
      Navigator.of(context).pop();
    }
  }

  String? _validateTicker(String? value) {
    try {
      TrackedInvestmentAsset.requireTicker(value ?? '');
      return null;
    } on InvestmentFailure catch (failure) {
      return failure.safeMessage;
    }
  }

  String? _validateName(String? value) {
    try {
      TrackedInvestmentAsset.requireName(value ?? '');
      return null;
    } on InvestmentFailure catch (failure) {
      return failure.safeMessage;
    }
  }

  Widget _error(String message) => SafeBackScope(
    fallbackLocation: AppRoutes.investments,
    child: Scaffold(
      appBar: AppBar(
        leading: const SafeBackButton(fallbackLocation: AppRoutes.investments),
        title: const Text('Adicionar ativo'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(message),
        ),
      ),
    ),
  );
}
