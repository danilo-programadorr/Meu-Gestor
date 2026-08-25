import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:meu_gestor_financeiro/app/routing/app_routes.dart';
import 'package:meu_gestor_financeiro/app/routing/safe_back_navigation.dart';
import 'package:meu_gestor_financeiro/app/theme/app_radius.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
import 'package:meu_gestor_financeiro/core/dates/sao_paulo_civil_date.dart';
import 'package:meu_gestor_financeiro/core/privacy/financial_privacy_controller.dart';
import 'package:meu_gestor_financeiro/features/investments/data/investment_providers.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_failure.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_operation.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_position.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/scaled_investment_value.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/tracked_investment_asset.dart';
import 'package:meu_gestor_financeiro/features/investments/presentation/controllers/investment_action_controller.dart';
import 'package:meu_gestor_financeiro/features/investments/presentation/controllers/investments_controller.dart';
import 'package:meu_gestor_financeiro/features/investments/presentation/widgets/investment_view_support.dart';

class InvestmentOperationFormPage extends ConsumerStatefulWidget {
  const InvestmentOperationFormPage({
    required this.assetId,
    required this.initialKind,
    super.key,
  });

  final String assetId;
  final InvestmentOperationKind initialKind;

  @override
  ConsumerState<InvestmentOperationFormPage> createState() =>
      _InvestmentOperationFormPageState();
}

class _InvestmentOperationFormPageState
    extends ConsumerState<InvestmentOperationFormPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _feesController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  late InvestmentOperationKind _kind = widget.initialKind;
  DateTime? _selectedDate;

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    _feesController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final InvestmentsState? workspace = ref
        .watch(investmentsControllerProvider)
        .value;
    final TrackedInvestmentAsset? asset = workspace?.assetById(widget.assetId);
    final InvestmentActionState action = ref.watch(
      investmentActionControllerProvider,
    );
    final bool valuesVisible = ref.watch(financialPrivacyControllerProvider);
    if (workspace == null || asset == null) {
      return _error('Este ativo não está disponível.');
    }
    final portfolio = workspace.portfolioById(asset.portfolioId);
    if (portfolio == null || portfolio.isArchived) {
      return _error('Esta carteira não está disponível para operações.');
    }
    if (asset.isArchived) {
      return _error('Restaure este ativo antes de registrar uma operação.');
    }
    final InvestmentPosition position = workspace
        .projectionForPortfolio(asset.portfolioId)
        .positions
        .firstWhere((InvestmentPosition value) => value.asset.id == asset.id);
    final DateTime clockNow = ref.watch(investmentClockProvider)();
    final DateTime today = SaoPauloCivilDate.fromInstant(
      clockNow,
    ).toUtcCalendarDate();
    _selectedDate ??= today;
    final _OperationPreview? preview = _buildPreview(
      asset: asset,
      position: position,
      now: clockNow,
    );
    return SafeBackScope(
      fallbackLocation: AppRoutes.investmentAssetDetails(widget.assetId),
      child: Scaffold(
        appBar: AppBar(
          leading: SafeBackButton(
            fallbackLocation: AppRoutes.investmentAssetDetails(widget.assetId),
          ),
          title: const Text('Registrar operação'),
          actions: <Widget>[
            InvestmentPrivacyButton(
              valuesVisible: valuesVisible,
              onPressed: () => ref
                  .read(financialPrivacyControllerProvider.notifier)
                  .toggle(),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            key: const ValueKey<String>('investment-operation-form-scroll'),
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
                        'Dados da operação',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      SegmentedButton<InvestmentOperationKind>(
                        segments: InvestmentOperationKind.values
                            .map(
                              (InvestmentOperationKind kind) =>
                                  ButtonSegment<InvestmentOperationKind>(
                                    value: kind,
                                    label: Text(kind.label),
                                    icon: Icon(
                                      kind == InvestmentOperationKind.buy
                                          ? Icons.south_east_rounded
                                          : Icons.north_east_rounded,
                                    ),
                                  ),
                            )
                            .toList(growable: false),
                        selected: <InvestmentOperationKind>{_kind},
                        onSelectionChanged: action.isLoading
                            ? null
                            : (Set<InvestmentOperationKind> values) =>
                                  setState(() => _kind = values.single),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _ReadOnlySelection(
                        icon: Icons.account_balance_wallet_outlined,
                        label: 'Carteira',
                        value: portfolio.name,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _ReadOnlySelection(
                        icon: asset.type == TrackedInvestmentAssetType.stock
                            ? Icons.candlestick_chart_outlined
                            : Icons.apartment_rounded,
                        label: 'Ativo',
                        value: '${asset.ticker} · ${asset.name}',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Semantics(
                        button: true,
                        label:
                            'Data da operação ${DateFormat('dd/MM/yyyy', 'pt_BR').format(_selectedDate!)}',
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.medium,
                            side: BorderSide(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                          leading: const Icon(Icons.calendar_today_outlined),
                          title: const Text('Data da operação'),
                          subtitle: Text(
                            DateFormat(
                              'dd/MM/yyyy',
                              'pt_BR',
                            ).format(_selectedDate!),
                          ),
                          onTap: action.isLoading
                              ? null
                              : () => _pickDate(today, asset.lastOperationAt),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _quantityController,
                        enabled: !action.isLoading,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.allow(RegExp('[0-9.,]')),
                        ],
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Quantidade',
                          hintText: 'Ex.: 10 ou 0,50000000',
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (String? value) =>
                            _validateQuantity(value, asset),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _priceController,
                        enabled: !action.isLoading,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.allow(RegExp('[0-9.,]')),
                        ],
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Preço unitário',
                          prefixText: 'R\$ ',
                          hintText: 'Ex.: 32,450000',
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (String? value) => _validatePrice(value),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _feesController,
                        enabled: !action.isLoading,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.allow(RegExp('[0-9.,]')),
                        ],
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Taxas',
                          prefixText: 'R\$ ',
                          hintText: 'Opcional',
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (String? value) => _validateFees(value),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _notesController,
                        enabled: !action.isLoading,
                        maxLength: InvestmentOperation.maximumNotesLength,
                        minLines: 2,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Observação',
                          hintText: 'Opcional',
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (String? value) => _validateNotes(value),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _OperationPreviewCard(
                        preview: preview,
                        kind: _kind,
                        valuesVisible: valuesVisible,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              const Icon(Icons.info_outline_rounded),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  'Acompanhamento manual: esta operação não altera contas, saldo, receitas ou despesas. Registre operações em ordem cronológica.',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      FilledButton.icon(
                        onPressed: action.isLoading
                            ? null
                            : () => _submit(
                                asset: asset,
                                position: position,
                                now: clockNow,
                                valuesVisible: valuesVisible,
                              ),
                        icon: action.isLoading
                            ? const SizedBox.square(
                                dimension: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  semanticsLabel: 'Registrando operação',
                                ),
                              )
                            : const Icon(Icons.check_rounded),
                        label: Text(
                          action.isLoading
                              ? 'Registrando...'
                              : 'Revisar e confirmar ${_kind.label.toLowerCase()}',
                        ),
                      ),
                      if (action.status == InvestmentActionStatus.failure &&
                          action.message != null) ...<Widget>[
                        const SizedBox(height: AppSpacing.md),
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

  _OperationPreview? _buildPreview({
    required TrackedInvestmentAsset asset,
    required InvestmentPosition position,
    required DateTime now,
  }) {
    if (_quantityController.text.trim().isEmpty ||
        _priceController.text.trim().isEmpty) {
      return null;
    }
    try {
      final int quantity = InvestmentQuantity.parsePtBr(
        _quantityController.text,
      ).scaled;
      final int price = InvestmentUnitPrice.parsePtBr(
        _priceController.text,
      ).scaled;
      final int fees = InvestmentMoneyInput.parseNonNegativeCents(
        _feesController.text,
      );
      _validateQuantityValue(quantity, asset);
      final InvestmentOperationDraft normalized = InvestmentOperationDraft(
        portfolioId: asset.portfolioId,
        assetId: asset.id,
        kind: _kind,
        occurredAt: InvestmentOperation.fromCalendarDate(_selectedDate!),
        quantityScaled: quantity,
        unitPriceScaled: price,
        feesCents: fees,
        notes: _notesController.text,
      ).normalized(now: now);
      final int gross = InvestmentArithmetic.grossAmountCents(
        quantityScaled: normalized.quantityScaled,
        unitPriceScaled: normalized.unitPriceScaled,
      );
      final int finalAmount = _kind == InvestmentOperationKind.buy
          ? InvestmentArithmetic.checkedInt64(
              BigInt.from(gross) + BigInt.from(fees),
            )
          : InvestmentArithmetic.checkedInt64(
              BigInt.from(gross) - BigInt.from(fees),
            );
      final int newQuantity = _kind == InvestmentOperationKind.buy
          ? position.quantityScaled + quantity
          : position.quantityScaled - quantity;
      final int? newAverage = _kind == InvestmentOperationKind.buy
          ? InvestmentArithmetic.averageUnitPriceScaled(
              costCents: InvestmentArithmetic.checkedInt64(
                BigInt.from(position.totalCostCents) + BigInt.from(finalAmount),
              ),
              quantityScaled: newQuantity,
            )
          : null;
      return _OperationPreview(
        grossCents: gross,
        feesCents: fees,
        finalCents: finalAmount,
        newQuantityScaled: newQuantity,
        newAverageUnitPriceScaled: newAverage,
      );
    } on InvestmentFailure {
      return null;
    }
  }

  Future<void> _pickDate(DateTime today, DateTime? lastOperationAt) async {
    final DateTime firstDate = lastOperationAt == null
        ? DateTime(1900)
        : SaoPauloCivilDate.fromInstant(lastOperationAt).toUtcCalendarDate();
    final DateTime? selected = await showDatePicker(
      context: context,
      initialDate: _selectedDate!,
      firstDate: firstDate,
      lastDate: DateTime(today.year, today.month, today.day),
      helpText: 'Data da operação',
    );
    if (selected != null && mounted) {
      setState(() => _selectedDate = selected);
    }
  }

  Future<void> _submit({
    required TrackedInvestmentAsset asset,
    required InvestmentPosition position,
    required DateTime now,
    required bool valuesVisible,
  }) async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final _OperationPreview? preview = _buildPreview(
      asset: asset,
      position: position,
      now: now,
    );
    if (preview == null) {
      return;
    }
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: Text('Confirmar ${_kind.label.toLowerCase()}?'),
            content: _OperationConfirmation(
              asset: asset,
              kind: _kind,
              date: _selectedDate!,
              preview: preview,
              valuesVisible: valuesVisible,
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Voltar e revisar'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Confirmar operação'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) {
      return;
    }
    final InvestmentOperationDraft draft = InvestmentOperationDraft(
      portfolioId: asset.portfolioId,
      assetId: asset.id,
      kind: _kind,
      occurredAt: InvestmentOperation.fromCalendarDate(_selectedDate!),
      quantityScaled: InvestmentQuantity.parsePtBr(
        _quantityController.text,
      ).scaled,
      unitPriceScaled: InvestmentUnitPrice.parsePtBr(
        _priceController.text,
      ).scaled,
      feesCents: InvestmentMoneyInput.parseNonNegativeCents(
        _feesController.text,
      ),
      notes: _notesController.text,
    );
    final bool success = await ref
        .read(investmentActionControllerProvider.notifier)
        .createOperation(draft);
    if (success && mounted) {
      Navigator.of(context).pop();
    }
  }

  String? _validateQuantity(String? value, TrackedInvestmentAsset asset) =>
      _validate(() {
        final int quantity = InvestmentQuantity.parsePtBr(value ?? '').scaled;
        _validateQuantityValue(quantity, asset);
        return quantity;
      });

  void _validateQuantityValue(int quantity, TrackedInvestmentAsset asset) {
    if (_kind == InvestmentOperationKind.sell &&
        quantity > asset.currentQuantityScaled) {
      throw const InvestmentFailure(
        kind: InvestmentFailureKind.insufficientPosition,
        safeMessage: 'A venda supera a quantidade disponível.',
        code: 'investment_sell_exceeds_position',
      );
    }
    if (_kind == InvestmentOperationKind.buy &&
        quantity + asset.currentQuantityScaled >
            InvestmentScale.maximumQuantityScaled) {
      throw const InvestmentFailure(
        kind: InvestmentFailureKind.overflow,
        safeMessage: 'A quantidade ultrapassa o limite seguro.',
        code: 'investment_quantity_projection_overflow',
      );
    }
  }

  String? _validatePrice(String? value) =>
      _validate(() => InvestmentUnitPrice.parsePtBr(value ?? ''));

  String? _validateFees(String? value) =>
      _validate(() => InvestmentMoneyInput.parseNonNegativeCents(value ?? ''));

  String? _validateNotes(String? value) =>
      _validate(() => InvestmentOperation.normalizeNotes(value ?? ''));

  String? _validate(Object Function() operation) {
    try {
      operation();
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
        title: const Text('Registrar operação'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(message, textAlign: TextAlign.center),
        ),
      ),
    ),
  );
}

final class _OperationPreview {
  const _OperationPreview({
    required this.grossCents,
    required this.feesCents,
    required this.finalCents,
    required this.newQuantityScaled,
    required this.newAverageUnitPriceScaled,
  });

  final int grossCents;
  final int feesCents;
  final int finalCents;
  final int newQuantityScaled;
  final int? newAverageUnitPriceScaled;
}

class _ReadOnlySelection extends StatelessWidget {
  const _ReadOnlySelection({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 64),
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    ),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: AppRadius.medium,
      border: Border.all(color: Theme.of(context).colorScheme.outline),
    ),
    child: Row(
      children: <Widget>[
        Icon(icon),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              Text(value, style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
        ),
      ],
    ),
  );
}

class _OperationPreviewCard extends StatelessWidget {
  const _OperationPreviewCard({
    required this.preview,
    required this.kind,
    required this.valuesVisible,
  });

  final _OperationPreview? preview;
  final InvestmentOperationKind kind;
  final bool valuesVisible;

  @override
  Widget build(BuildContext context) => Card(
    key: const ValueKey<String>('investment-operation-preview'),
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.calculate_outlined),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Prévia da operação',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (preview == null)
            const Text(
              'Informe uma quantidade e um preço válidos para visualizar a prévia.',
            )
          else
            _PreviewValues(
              preview: preview!,
              kind: kind,
              valuesVisible: valuesVisible,
            ),
        ],
      ),
    ),
  );
}

class _PreviewValues extends StatelessWidget {
  const _PreviewValues({
    required this.preview,
    required this.kind,
    required this.valuesVisible,
  });

  final _OperationPreview preview;
  final InvestmentOperationKind kind;
  final bool valuesVisible;

  @override
  Widget build(BuildContext context) => Column(
    children: <Widget>[
      _PreviewRow(
        label: 'Valor bruto',
        value: InvestmentViewSupport.money(
          preview.grossCents,
          visible: valuesVisible,
        ),
      ),
      _PreviewRow(
        label: 'Taxas',
        value: InvestmentViewSupport.money(
          preview.feesCents,
          visible: valuesVisible,
        ),
      ),
      const Divider(height: AppSpacing.lg),
      _PreviewRow(
        label: kind == InvestmentOperationKind.buy
            ? 'Valor final da compra'
            : 'Valor final da venda',
        value: InvestmentViewSupport.money(
          preview.finalCents,
          visible: valuesVisible,
        ),
        emphasized: true,
      ),
      _PreviewRow(
        label: 'Quantidade estimada após a operação',
        value: InvestmentViewSupport.quantity(
          preview.newQuantityScaled,
          visible: valuesVisible,
        ),
      ),
      if (preview.newAverageUnitPriceScaled != null)
        _PreviewRow(
          label: 'Possível novo preço médio',
          value: InvestmentViewSupport.unitPrice(
            preview.newAverageUnitPriceScaled!,
            visible: valuesVisible,
          ),
        ),
    ],
  );
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(child: Text(label)),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: emphasized
                ? Theme.of(context).textTheme.titleSmall
                : Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    ),
  );
}

class _OperationConfirmation extends StatelessWidget {
  const _OperationConfirmation({
    required this.asset,
    required this.kind,
    required this.date,
    required this.preview,
    required this.valuesVisible,
  });

  final TrackedInvestmentAsset asset;
  final InvestmentOperationKind kind;
  final DateTime date;
  final _OperationPreview preview;
  final bool valuesVisible;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text('${asset.ticker} · ${asset.name}'),
        const SizedBox(height: AppSpacing.xs),
        Text('Data: ${DateFormat('dd/MM/yyyy', 'pt_BR').format(date)}'),
        const SizedBox(height: AppSpacing.md),
        _PreviewValues(
          preview: preview,
          kind: kind,
          valuesVisible: valuesVisible,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Confira os dados antes de registrar. A operação ficará no histórico.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}
