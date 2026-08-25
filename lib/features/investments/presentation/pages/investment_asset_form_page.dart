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
  const InvestmentAssetFormPage({this.portfolioId, this.assetId, super.key})
    : assert((portfolioId == null) != (assetId == null));

  final String? portfolioId;
  final String? assetId;

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
  String? _initializedAssetId;

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
    final TrackedInvestmentAsset? asset = widget.assetId == null
        ? null
        : workspace?.assetById(widget.assetId!);
    if (asset != null && _initializedAssetId != asset.id) {
      _initializedAssetId = asset.id;
      _tickerController.text = asset.ticker;
      _nameController.text = asset.name;
      _type = asset.type;
    }
    final String portfolioId = asset?.portfolioId ?? widget.portfolioId ?? '';
    final portfolio = workspace?.portfolioById(portfolioId);
    final bool editing = widget.assetId != null;
    if (workspace == null || portfolio == null || portfolio.isArchived) {
      return _error(
        editing
            ? 'Este ativo não está disponível para correção.'
            : 'Esta carteira não está disponível para novos ativos.',
        editing: editing,
      );
    }
    if (editing && asset == null) {
      return _error('Este ativo não está mais disponível.', editing: true);
    }
    return SafeBackScope(
      fallbackLocation: AppRoutes.investments,
      child: Scaffold(
        appBar: AppBar(
          leading: const SafeBackButton(
            fallbackLocation: AppRoutes.investments,
          ),
          title: Text(editing ? 'Corrigir ativo' : 'Adicionar ativo'),
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
                        onSelectionChanged:
                            action.isLoading || (asset?.hasHistory ?? false)
                            ? null
                            : (Set<TrackedInvestmentAssetType> values) =>
                                  setState(() => _type = values.single),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _tickerController,
                        enabled: !action.isLoading && !editing,
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
                      FilledButton.icon(
                        onPressed: action.isLoading ? null : _submit,
                        icon: Icon(
                          editing ? Icons.save_outlined : Icons.add_rounded,
                        ),
                        label: action.isLoading
                            ? const SizedBox.square(
                                dimension: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  semanticsLabel: 'Adicionando ativo',
                                ),
                              )
                            : Text(
                                editing ? 'Salvar correção' : 'Adicionar ativo',
                              ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        editing && asset!.hasHistory
                            ? 'O ticker e o tipo ficam bloqueados porque este ativo possui operações ou proventos. O nome pode ser corrigido sem alterar o histórico.'
                            : editing
                            ? 'O ticker identifica o documento e não pode ser alterado. Como ainda não há histórico, nome e tipo podem ser corrigidos.'
                            : 'Este cadastro é manual. Nenhum catálogo, cotação ou corretora será consultado.',
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
    final InvestmentsState? workspace = ref
        .read(investmentsControllerProvider)
        .value;
    final TrackedInvestmentAsset? asset = widget.assetId == null
        ? null
        : workspace?.assetById(widget.assetId!);
    final controller = ref.read(investmentActionControllerProvider.notifier);
    final bool success = asset == null
        ? await controller.createAsset(
            TrackedInvestmentAssetDraft(
              portfolioId: widget.portfolioId ?? '',
              ticker: _tickerController.text,
              name: _nameController.text,
              type: _type,
            ),
          )
        : await controller.updateAsset(
            asset: asset,
            update: TrackedInvestmentAssetUpdate(
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

  Widget _error(String message, {bool editing = false}) => SafeBackScope(
    fallbackLocation: AppRoutes.investments,
    child: Scaffold(
      appBar: AppBar(
        leading: const SafeBackButton(fallbackLocation: AppRoutes.investments),
        title: Text(editing ? 'Corrigir ativo' : 'Adicionar ativo'),
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
