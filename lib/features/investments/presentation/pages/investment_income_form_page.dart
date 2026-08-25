import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_gestor_financeiro/app/routing/app_routes.dart';
import 'package:meu_gestor_financeiro/app/routing/safe_back_navigation.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
import 'package:meu_gestor_financeiro/core/privacy/financial_privacy_controller.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_failure.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_income_event.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/scaled_investment_value.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/tracked_investment_asset.dart';
import 'package:meu_gestor_financeiro/features/investments/presentation/controllers/investment_action_controller.dart';
import 'package:meu_gestor_financeiro/features/investments/presentation/controllers/investments_controller.dart';
import 'package:meu_gestor_financeiro/features/investments/presentation/widgets/investment_view_support.dart';

class InvestmentIncomeFormPage extends ConsumerStatefulWidget {
  const InvestmentIncomeFormPage({this.portfolioId, this.eventId, super.key});

  final String? portfolioId;
  final String? eventId;

  @override
  ConsumerState<InvestmentIncomeFormPage> createState() =>
      _InvestmentIncomeFormPageState();
}

class _InvestmentIncomeFormPageState
    extends ConsumerState<InvestmentIncomeFormPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _grossController = TextEditingController();
  final TextEditingController _taxController = TextEditingController(
    text: '0,00',
  );
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _unitController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String? _assetId;
  InvestmentIncomeType? _type;
  InvestmentIncomeInputMode _inputMode = InvestmentIncomeInputMode.total;
  DateTime? _exDate;
  DateTime _expectedPaymentDate = DateTime.now();
  String? _initializedEventId;

  bool get _editing => widget.eventId != null;

  @override
  void dispose() {
    _grossController.dispose();
    _taxController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<InvestmentsState> workspace = ref.watch(
      investmentsControllerProvider,
    );
    final InvestmentActionState action = ref.watch(
      investmentActionControllerProvider,
    );
    final bool valuesVisible = ref.watch(financialPrivacyControllerProvider);
    return SafeBackScope(
      fallbackLocation: AppRoutes.investments,
      child: Scaffold(
        appBar: AppBar(
          leading: const SafeBackButton(
            fallbackLocation: AppRoutes.investments,
          ),
          title: Text(_editing ? 'Editar provento previsto' : 'Novo provento'),
        ),
        body: SafeArea(
          child: workspace.when(
            loading: () => const Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Carregando formulário de provento',
              ),
            ),
            error: (Object error, StackTrace stackTrace) => Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  safeInvestmentErrorMessage(error),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            data: (InvestmentsState data) =>
                _buildForm(data, action: action, valuesVisible: valuesVisible),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(
    InvestmentsState data, {
    required InvestmentActionState action,
    required bool valuesVisible,
  }) {
    final InvestmentIncomeEvent? event = widget.eventId == null
        ? null
        : data.incomeEventById(widget.eventId!);
    if (_editing && event == null) {
      return const Center(child: Text('Este provento não foi encontrado.'));
    }
    if (event != null && !event.isExpected) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Text(
            'Somente proventos previstos podem ser editados.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final String portfolioId = event?.portfolioId ?? widget.portfolioId ?? '';
    final List<TrackedInvestmentAsset> assets = data
        .assetsForPortfolio(portfolioId)
        .where(
          (TrackedInvestmentAsset asset) =>
              !asset.isArchived || asset.id == event?.assetId,
        )
        .toList(growable: false);
    if (assets.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Text(
            'Cadastre ou restaure um ativo nesta carteira antes de registrar proventos.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    _initialize(event, assets);
    final TrackedInvestmentAsset selected = assets.firstWhere(
      (TrackedInvestmentAsset asset) => asset.id == _assetId,
      orElse: () => assets.first,
    );
    _assetId = selected.id;
    final List<InvestmentIncomeType> compatibleTypes = InvestmentIncomeType
        .values
        .where(
          (InvestmentIncomeType type) => type.isCompatibleWith(selected.type),
        )
        .toList(growable: false);
    if (_type == null || !_type!.isCompatibleWith(selected.type)) {
      _type = compatibleTypes.first;
    }
    final _IncomePreview? preview = _tryPreview();
    return Form(
      key: _formKey,
      child: ListView(
        key: const ValueKey<String>('investment-income-form-scroll'),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.xxl,
        ),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(Icons.info_outline_rounded),
                  const SizedBox(width: AppSpacing.sm),
                  const Expanded(
                    child: Text(
                      'Este registro acompanha a carteira. Ele não cria receita, não movimenta conta e não altera o saldo.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String>(
            initialValue: selected.id,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Ativo'),
            items: assets
                .map(
                  (TrackedInvestmentAsset asset) => DropdownMenuItem<String>(
                    value: asset.id,
                    child: Text(
                      '${asset.ticker} · ${asset.name}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(growable: false),
            onChanged: _editing || action.isLoading
                ? null
                : (String? value) {
                    if (value != null) {
                      setState(() {
                        _assetId = value;
                        final TrackedInvestmentAsset asset = assets.firstWhere(
                          (TrackedInvestmentAsset item) => item.id == value,
                        );
                        _type = InvestmentIncomeType.values.firstWhere(
                          (InvestmentIncomeType type) =>
                              type.isCompatibleWith(asset.type),
                        );
                      });
                    }
                  },
          ),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<InvestmentIncomeType>(
            initialValue: _type,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Tipo de provento'),
            items: compatibleTypes
                .map(
                  (InvestmentIncomeType type) =>
                      DropdownMenuItem(value: type, child: Text(type.label)),
                )
                .toList(growable: false),
            onChanged: action.isLoading
                ? null
                : (InvestmentIncomeType? value) =>
                      setState(() => _type = value),
          ),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<InvestmentIncomeInputMode>(
            initialValue: _inputMode,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Modo de preenchimento',
            ),
            items: InvestmentIncomeInputMode.values
                .map(
                  (InvestmentIncomeInputMode mode) =>
                      DropdownMenuItem(value: mode, child: Text(mode.label)),
                )
                .toList(growable: false),
            onChanged: action.isLoading
                ? null
                : (InvestmentIncomeInputMode? value) {
                    if (value != null) {
                      setState(() => _inputMode = value);
                    }
                  },
          ),
          const SizedBox(height: AppSpacing.md),
          if (_inputMode == InvestmentIncomeInputMode.total)
            _moneyField(
              controller: _grossController,
              label: 'Valor bruto total',
              valuesVisible: valuesVisible,
            )
          else ...<Widget>[
            TextFormField(
              controller: _quantityController,
              obscureText: !valuesVisible,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Quantidade elegível',
              ),
              validator: (String? value) =>
                  value == null || value.trim().isEmpty
                  ? 'Informe a quantidade.'
                  : null,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _unitController,
              obscureText: !valuesVisible,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Valor bruto por unidade',
                prefixText: r'R$ ',
              ),
              validator: (String? value) =>
                  value == null || value.trim().isEmpty
                  ? 'Informe o valor por unidade.'
                  : null,
              onChanged: (_) => setState(() {}),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          _moneyField(
            controller: _taxController,
            label: 'Imposto retido',
            valuesVisible: valuesVisible,
            requiredValue: false,
          ),
          const SizedBox(height: AppSpacing.md),
          _DateField(
            label: 'Data prevista de pagamento',
            value: _expectedPaymentDate,
            onTap: action.isLoading
                ? null
                : () => _pickDate(
                    initial: _expectedPaymentDate,
                    onSelected: (DateTime value) =>
                        setState(() => _expectedPaymentDate = value),
                  ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _DateField(
            label: 'Data-com (opcional)',
            value: _exDate,
            onTap: action.isLoading
                ? null
                : () => _pickDate(
                    initial: _exDate ?? _expectedPaymentDate,
                    onSelected: (DateTime value) =>
                        setState(() => _exDate = value),
                  ),
            onClear: _exDate == null || action.isLoading
                ? null
                : () => setState(() => _exDate = null),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _notesController,
            minLines: 2,
            maxLines: 4,
            maxLength: InvestmentIncomeEvent.maximumNotesLength,
            decoration: const InputDecoration(
              labelText: 'Observações (opcional)',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _IncomePreviewCard(preview: preview, valuesVisible: valuesVisible),
          if (action.status == InvestmentActionStatus.failure &&
              action.message != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              action.message!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: action.isLoading
                ? null
                : () => _submit(
                    event: event,
                    asset: selected,
                    preview: preview,
                    valuesVisible: valuesVisible,
                  ),
            icon: action.isLoading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded),
            label: Text(_editing ? 'Salvar previsão' : 'Criar previsão'),
          ),
        ],
      ),
    );
  }

  Widget _moneyField({
    required TextEditingController controller,
    required String label,
    required bool valuesVisible,
    bool requiredValue = true,
  }) => TextFormField(
    controller: controller,
    obscureText: !valuesVisible,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: <TextInputFormatter>[
      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
    ],
    decoration: InputDecoration(labelText: label, prefixText: r'R$ '),
    validator: requiredValue
        ? (String? value) =>
              value == null || value.trim().isEmpty ? 'Informe o valor.' : null
        : null,
    onChanged: (_) => setState(() {}),
  );

  void _initialize(
    InvestmentIncomeEvent? event,
    List<TrackedInvestmentAsset> assets,
  ) {
    if (event == null) {
      _assetId ??= assets.first.id;
      return;
    }
    if (_initializedEventId == event.id) {
      return;
    }
    _initializedEventId = event.id;
    _assetId = event.assetId;
    _type = event.type;
    _inputMode = event.inputMode;
    _exDate = event.exDate;
    _expectedPaymentDate = event.expectedPaymentDate;
    _grossController.text = InvestmentMoneyInput.formatEditable(
      event.grossAmountCents,
    );
    _taxController.text = InvestmentMoneyInput.formatEditable(
      event.withholdingTaxCents,
    );
    _quantityController.text = event.eligibleQuantityScaled == null
        ? ''
        : InvestmentQuantity.fromScaled(
            event.eligibleQuantityScaled!,
          ).formatPtBr();
    _unitController.text = event.unitAmountScaled == null
        ? ''
        : InvestmentUnitPrice.fromScaled(event.unitAmountScaled!).formatPtBr();
    _notesController.text = event.notes;
  }

  _IncomePreview? _tryPreview() {
    try {
      final int tax = InvestmentMoneyInput.parseNonNegativeCents(
        _taxController.text,
      );
      if (_inputMode == InvestmentIncomeInputMode.total) {
        final int gross = InvestmentMoneyInput.parseNonNegativeCents(
          _grossController.text,
        );
        if (gross <= 0 || tax > gross) {
          return null;
        }
        return _IncomePreview(grossCents: gross, taxCents: tax);
      }
      final int quantity = InvestmentQuantity.parsePtBr(
        _quantityController.text,
      ).scaled;
      final int unit = InvestmentUnitPrice.parsePtBr(
        _unitController.text,
      ).scaled;
      final int gross = InvestmentIncomeEvent.grossFromUnit(
        quantityScaled: quantity,
        unitAmountScaled: unit,
      );
      if (gross <= 0 || tax > gross) {
        return null;
      }
      return _IncomePreview(
        grossCents: gross,
        taxCents: tax,
        quantityScaled: quantity,
        unitAmountScaled: unit,
      );
    } on Object {
      return null;
    }
  }

  InvestmentIncomeDraft _draft(TrackedInvestmentAsset asset) {
    final _IncomePreview preview =
        _tryPreview() ??
        (throw const InvestmentFailure(
          kind: InvestmentFailureKind.validation,
          safeMessage: 'Revise os valores informados.',
          code: 'invalid_investment_income_preview',
        ));
    return InvestmentIncomeDraft(
      portfolioId: asset.portfolioId,
      assetId: asset.id,
      type: _type!,
      inputMode: _inputMode,
      exDate: _exDate,
      expectedPaymentDate: _expectedPaymentDate,
      eligibleQuantityScaled: preview.quantityScaled,
      unitAmountScaled: preview.unitAmountScaled,
      grossAmountCents: preview.grossCents,
      withholdingTaxCents: preview.taxCents,
      notes: _notesController.text,
    ).normalized(assetType: asset.type);
  }

  Future<void> _submit({
    required InvestmentIncomeEvent? event,
    required TrackedInvestmentAsset asset,
    required _IncomePreview? preview,
    required bool valuesVisible,
  }) async {
    if (!(_formKey.currentState?.validate() ?? false) || preview == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Revise os campos e a prévia do provento.'),
        ),
      );
      return;
    }
    try {
      final InvestmentIncomeDraft draft = _draft(asset);
      final bool confirmed =
          await showDialog<bool>(
            context: context,
            builder: (BuildContext dialogContext) => AlertDialog(
              title: Text(
                _editing ? 'Salvar esta previsão?' : 'Criar esta previsão?',
              ),
              content: _IncomeConfirmation(
                draft: draft,
                asset: asset,
                valuesVisible: valuesVisible,
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Voltar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Confirmar'),
                ),
              ],
            ),
          ) ??
          false;
      if (!confirmed || !mounted) {
        return;
      }
      final InvestmentActionController controller = ref.read(
        investmentActionControllerProvider.notifier,
      );
      final bool success = event == null
          ? await controller.createIncomeEvent(draft)
          : await controller.updateExpectedIncomeEvent(
              event: event,
              draft: draft,
            );
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              event == null
                  ? 'Provento previsto criado.'
                  : 'Previsão atualizada.',
            ),
          ),
        );
        Navigator.of(context).pop();
      }
    } on InvestmentFailure catch (failure) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.safeMessage)));
      }
    }
  }

  Future<void> _pickDate({
    required DateTime initial,
    required ValueChanged<DateTime> onSelected,
  }) async {
    final DateTime? selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200),
    );
    if (selected != null && mounted) {
      onSelected(selected);
    }
  }
}

final class _IncomePreview {
  const _IncomePreview({
    required this.grossCents,
    required this.taxCents,
    this.quantityScaled,
    this.unitAmountScaled,
  });

  final int grossCents;
  final int taxCents;
  final int? quantityScaled;
  final int? unitAmountScaled;

  int get netCents => grossCents - taxCents;
}

class _IncomePreviewCard extends StatelessWidget {
  const _IncomePreviewCard({
    required this.preview,
    required this.valuesVisible,
  });

  final _IncomePreview? preview;
  final bool valuesVisible;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('Prévia', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          if (preview == null)
            const Text('Preencha valores válidos para conferir o resultado.')
          else ...<Widget>[
            _PreviewRow(
              label: 'Valor bruto',
              value: InvestmentViewSupport.money(
                preview!.grossCents,
                visible: valuesVisible,
              ),
            ),
            _PreviewRow(
              label: 'Imposto retido',
              value: InvestmentViewSupport.money(
                preview!.taxCents,
                visible: valuesVisible,
              ),
            ),
            _PreviewRow(
              label: 'Valor líquido',
              value: InvestmentViewSupport.money(
                preview!.netCents,
                visible: valuesVisible,
              ),
            ),
            if (preview!.quantityScaled != null)
              _PreviewRow(
                label: 'Quantidade elegível',
                value: InvestmentViewSupport.quantity(
                  preview!.quantityScaled!,
                  visible: valuesVisible,
                ),
              ),
            if (preview!.unitAmountScaled != null)
              _PreviewRow(
                label: 'Valor por unidade',
                value: InvestmentViewSupport.unitPrice(
                  preview!.unitAmountScaled!,
                  visible: valuesVisible,
                ),
              ),
          ],
        ],
      ),
    ),
  );
}

class _IncomeConfirmation extends StatelessWidget {
  const _IncomeConfirmation({
    required this.draft,
    required this.asset,
    required this.valuesVisible,
  });

  final InvestmentIncomeDraft draft;
  final TrackedInvestmentAsset asset;
  final bool valuesVisible;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text('${asset.ticker} · ${draft.type.label}'),
        const SizedBox(height: AppSpacing.sm),
        _PreviewRow(
          label: 'Bruto',
          value: InvestmentViewSupport.money(
            draft.grossAmountCents,
            visible: valuesVisible,
          ),
        ),
        _PreviewRow(
          label: 'Imposto',
          value: InvestmentViewSupport.money(
            draft.withholdingTaxCents,
            visible: valuesVisible,
          ),
        ),
        _PreviewRow(
          label: 'Líquido',
          value: InvestmentViewSupport.money(
            draft.netAmountCents,
            visible: valuesVisible,
          ),
        ),
        _PreviewRow(
          label: 'Pagamento previsto',
          value: InvestmentViewSupport.date(draft.expectedPaymentDate),
        ),
        if (draft.eligibleQuantityScaled != null)
          _PreviewRow(
            label: 'Quantidade',
            value: InvestmentViewSupport.quantity(
              draft.eligibleQuantityScaled!,
              visible: valuesVisible,
            ),
          ),
        if (draft.unitAmountScaled != null)
          _PreviewRow(
            label: 'Valor por unidade',
            value: InvestmentViewSupport.unitPrice(
              draft.unitAmountScaled!,
              visible: valuesVisible,
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'A confirmação cria somente uma previsão na carteira de investimentos.',
        ),
      ],
    ),
  );
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(child: Text(label)),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
      ],
    ),
  );
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final DateTime? value;
  final VoidCallback? onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (onClear != null)
              IconButton(
                tooltip: 'Limpar $label',
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded),
              ),
            const Icon(Icons.calendar_month_outlined),
            const SizedBox(width: AppSpacing.sm),
          ],
        ),
      ),
      child: Text(
        value == null ? 'Não informada' : InvestmentViewSupport.date(value!),
      ),
    ),
  );
}
