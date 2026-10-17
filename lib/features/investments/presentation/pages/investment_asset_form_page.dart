import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:meu_gestor_financeiro/app/routing/app_routes.dart';
import 'package:meu_gestor_financeiro/app/routing/safe_back_navigation.dart';
import 'package:meu_gestor_financeiro/app/theme/app_radius.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
import 'package:meu_gestor_financeiro/core/dates/sao_paulo_civil_date.dart';
import 'package:meu_gestor_financeiro/features/investments/data/investment_providers.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_asset_directory.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_failure.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_operation.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/scaled_investment_value.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/tracked_investment_asset.dart';
import 'package:meu_gestor_financeiro/features/investments/presentation/controllers/investment_action_controller.dart';
import 'package:meu_gestor_financeiro/features/investments/presentation/controllers/investments_controller.dart';
import 'package:meu_gestor_financeiro/features/investments/presentation/widgets/investment_view_support.dart';

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
  final TextEditingController _assetSearchController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _feesController = TextEditingController();
  TrackedInvestmentAssetType _editingType = TrackedInvestmentAssetType.stock;
  InvestmentAssetDirectoryEntry? _selectedEntry;
  List<InvestmentAssetDirectoryEntry> _suggestions =
      const <InvestmentAssetDirectoryEntry>[];
  DateTime? _selectedDate;
  Timer? _searchDebounce;
  int _searchGeneration = 0;
  bool _searching = false;
  String? _searchError;
  String? _initializedAssetId;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _assetSearchController.dispose();
    _nameController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _feesController.dispose();
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
      _assetSearchController.text = asset.ticker;
      _nameController.text = asset.name;
      _editingType = asset.type;
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
    final DateTime clockNow = ref.watch(investmentClockProvider)();
    final DateTime today = SaoPauloCivilDate.fromInstant(
      clockNow,
    ).toUtcCalendarDate();
    _selectedDate ??= today;
    final int? totalCents = editing ? null : _totalCents();

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
            key: const ValueKey<String>('investment-asset-form-scroll'),
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Form(
                  key: _formKey,
                  child: editing
                      ? _editingFields(asset!, action)
                      : _creationFields(
                          portfolioName: portfolio.name,
                          action: action,
                          today: today,
                          now: clockNow,
                          totalCents: totalCents,
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _creationFields({
    required String portfolioName,
    required InvestmentActionState action,
    required DateTime today,
    required DateTime now,
    required int? totalCents,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      Text(portfolioName, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: AppSpacing.md),
      SegmentedButton<InvestmentOperationKind>(
        segments: const <ButtonSegment<InvestmentOperationKind>>[
          ButtonSegment<InvestmentOperationKind>(
            value: InvestmentOperationKind.buy,
            icon: Icon(Icons.south_east_rounded),
            label: Text('Compra'),
          ),
          ButtonSegment<InvestmentOperationKind>(
            value: InvestmentOperationKind.sell,
            icon: Icon(Icons.north_east_rounded),
            label: Text('Venda'),
            enabled: false,
          ),
        ],
        selected: const <InvestmentOperationKind>{InvestmentOperationKind.buy},
        onSelectionChanged: (_) {},
      ),
      const SizedBox(height: AppSpacing.xs),
      Text(
        'A primeira operação precisa ser uma compra. Depois você poderá registrar vendas no ativo.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: AppSpacing.md),
      TextFormField(
        key: const ValueKey<String>('investment-asset-search'),
        controller: _assetSearchController,
        enabled: !action.isLoading,
        textCapitalization: TextCapitalization.characters,
        maxLength: 32,
        decoration: InputDecoration(
          labelText: 'Ativo',
          hintText: 'Digite o ticker ou o nome',
          helperText: _selectedEntry == null
              ? 'Digite ao menos 2 caracteres e selecione uma opção.'
              : '${_selectedEntry!.type.label} selecionada',
          suffixIcon: _searching
              ? const Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : _selectedEntry == null
              ? const Icon(Icons.search_rounded)
              : const Icon(Icons.check_circle_outline_rounded),
        ),
        onChanged: _scheduleSearch,
        validator: (_) => _selectedEntry == null
            ? 'Selecione um ativo válido na lista.'
            : null,
      ),
      if (_searchError != null)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Text(
            _searchError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      if (_suggestions.isNotEmpty)
        Card(
          key: const ValueKey<String>('investment-asset-suggestions'),
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Column(
            children: _suggestions
                .map(
                  (InvestmentAssetDirectoryEntry entry) => ListTile(
                    key: ValueKey<String>('investment-asset-${entry.ticker}'),
                    leading: Icon(
                      entry.type == TrackedInvestmentAssetType.stock
                          ? Icons.candlestick_chart_outlined
                          : Icons.apartment_rounded,
                    ),
                    title: Text(entry.ticker),
                    subtitle: Text(entry.name),
                    trailing: Text(entry.type.label),
                    onTap: action.isLoading ? null : () => _selectEntry(entry),
                  ),
                )
                .toList(growable: false),
          ),
        ),
      if (_selectedEntry != null) ...<Widget>[
        _SelectedAssetCard(entry: _selectedEntry!),
        const SizedBox(height: AppSpacing.md),
      ],
      _dateField(today, action.isLoading),
      const SizedBox(height: AppSpacing.md),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: _numberField(
              key: 'investment-initial-quantity',
              controller: _quantityController,
              label: 'Quantidade',
              hint: 'Ex.: 10',
              enabled: !action.isLoading,
              validator: _validateQuantity,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _numberField(
              key: 'investment-initial-price',
              controller: _priceController,
              label: 'Preço em R\$',
              hint: '0,00',
              enabled: !action.isLoading,
              validator: _validatePrice,
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      _numberField(
        key: 'investment-initial-fees',
        controller: _feesController,
        label: 'Outros custos',
        hint: '0,00',
        enabled: !action.isLoading,
        validator: _validateFees,
      ),
      const SizedBox(height: AppSpacing.md),
      Container(
        key: const ValueKey<String>('investment-initial-total'),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: AppRadius.medium,
        ),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final Text label = Text(
              'Valor total',
              style: Theme.of(context).textTheme.titleMedium,
            );
            final Text value = Text(
              totalCents == null
                  ? 'R\$ 0,00'
                  : InvestmentViewSupport.money(totalCents, visible: true),
              style: Theme.of(context).textTheme.titleLarge,
            );
            final bool stackVertically =
                constraints.maxWidth < 320 ||
                MediaQuery.textScalerOf(context).scale(1) > 1.3;
            if (stackVertically) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  label,
                  const SizedBox(height: AppSpacing.xs),
                  value,
                ],
              );
            }
            return Row(
              children: <Widget>[
                Expanded(child: label),
                const SizedBox(width: AppSpacing.md),
                value,
              ],
            );
          },
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      FilledButton.icon(
        onPressed: action.isLoading ? null : () => _submitCreation(now),
        icon: action.isLoading
            ? const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add_rounded),
        label: Text(action.isLoading ? 'Adicionando...' : 'Adicionar ativo'),
      ),
      _actionFailure(action),
    ],
  );

  Widget _editingFields(
    TrackedInvestmentAsset asset,
    InvestmentActionState action,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
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
        selected: <TrackedInvestmentAssetType>{_editingType},
        onSelectionChanged: action.isLoading || asset.hasHistory
            ? null
            : (Set<TrackedInvestmentAssetType> values) =>
                  setState(() => _editingType = values.single),
      ),
      const SizedBox(height: AppSpacing.md),
      TextFormField(
        controller: _assetSearchController,
        enabled: false,
        decoration: const InputDecoration(labelText: 'Ticker'),
      ),
      const SizedBox(height: AppSpacing.md),
      TextFormField(
        controller: _nameController,
        enabled: !action.isLoading,
        maxLength: 80,
        decoration: const InputDecoration(labelText: 'Nome do ativo'),
        validator: _validateName,
      ),
      const SizedBox(height: AppSpacing.lg),
      FilledButton.icon(
        onPressed: action.isLoading ? null : () => _submitEditing(asset),
        icon: const Icon(Icons.save_outlined),
        label: const Text('Salvar correção'),
      ),
      const SizedBox(height: AppSpacing.md),
      Text(
        asset.hasHistory
            ? 'O ticker e o tipo ficam bloqueados porque este ativo possui operações ou proventos. O nome pode ser corrigido sem alterar o histórico.'
            : 'O ticker identifica o documento e não pode ser alterado. Como ainda não há histórico, nome e tipo podem ser corrigidos.',
        textAlign: TextAlign.center,
      ),
      _actionFailure(action),
    ],
  );

  Widget _dateField(DateTime today, bool disabled) => Semantics(
    button: true,
    label:
        'Data da compra ${DateFormat('dd/MM/yyyy', 'pt_BR').format(_selectedDate!)}',
    child: ListTile(
      key: const ValueKey<String>('investment-initial-date'),
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.medium,
        side: BorderSide(color: Theme.of(context).colorScheme.outline),
      ),
      leading: const Icon(Icons.calendar_today_outlined),
      title: const Text('Data da compra'),
      subtitle: Text(DateFormat('dd/MM/yyyy', 'pt_BR').format(_selectedDate!)),
      onTap: disabled ? null : () => _pickDate(today),
    ),
  );

  Widget _numberField({
    required String key,
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool enabled,
    required String? Function(String?) validator,
  }) => TextFormField(
    key: ValueKey<String>(key),
    controller: controller,
    enabled: enabled,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: <TextInputFormatter>[
      FilteringTextInputFormatter.allow(RegExp('[0-9.,]')),
    ],
    decoration: InputDecoration(labelText: label, hintText: hint),
    onChanged: (_) => setState(() {}),
    validator: validator,
  );

  void _scheduleSearch(String rawValue) {
    _searchDebounce?.cancel();
    final int generation = ++_searchGeneration;
    if (_selectedEntry != null &&
        rawValue.trim().toUpperCase() != _selectedEntry!.ticker) {
      _selectedEntry = null;
    }
    final String query = rawValue.trim();
    if (query.length < 2) {
      setState(() {
        _suggestions = const <InvestmentAssetDirectoryEntry>[];
        _searchError = null;
        _searching = false;
      });
      return;
    }
    setState(() {
      _searching = true;
      _searchError = null;
    });
    _searchDebounce = Timer(const Duration(milliseconds: 450), () async {
      try {
        final List<InvestmentAssetDirectoryEntry> results = await ref
            .read(investmentAssetDirectoryProvider)
            .search(query);
        if (!mounted || generation != _searchGeneration) return;
        setState(() {
          _suggestions = results;
          _searching = false;
          _searchError = results.isEmpty
              ? 'Nenhum ativo compatível foi encontrado.'
              : null;
        });
      } on InvestmentFailure catch (failure) {
        if (!mounted || generation != _searchGeneration) return;
        setState(() {
          _suggestions = const <InvestmentAssetDirectoryEntry>[];
          _searching = false;
          _searchError = failure.safeMessage;
        });
      }
    });
  }

  void _selectEntry(InvestmentAssetDirectoryEntry entry) {
    _searchDebounce?.cancel();
    _searchGeneration += 1;
    setState(() {
      _selectedEntry = entry;
      _assetSearchController.text = entry.ticker;
      _assetSearchController.selection = TextSelection.collapsed(
        offset: entry.ticker.length,
      );
      _suggestions = const <InvestmentAssetDirectoryEntry>[];
      _searching = false;
      _searchError = null;
    });
  }

  int? _totalCents() {
    try {
      final int gross = InvestmentArithmetic.grossAmountCents(
        quantityScaled: InvestmentQuantity.parsePtBr(
          _quantityController.text,
        ).scaled,
        unitPriceScaled: InvestmentUnitPrice.parsePtBr(
          _priceController.text,
        ).scaled,
      );
      final int fees = InvestmentMoneyInput.parseNonNegativeCents(
        _feesController.text,
      );
      return InvestmentArithmetic.checkedInt64(
        BigInt.from(gross) + BigInt.from(fees),
      );
    } on InvestmentFailure {
      return null;
    }
  }

  Future<void> _pickDate(DateTime today) async {
    final DateTime? selected = await showDatePicker(
      context: context,
      initialDate: _selectedDate!,
      firstDate: DateTime(1900),
      lastDate: today,
      helpText: 'Data da compra',
    );
    if (selected != null && mounted) setState(() => _selectedDate = selected);
  }

  Future<void> _submitCreation(DateTime now) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final InvestmentAssetDirectoryEntry entry = _selectedEntry!;
    final TrackedInvestmentAssetDraft assetDraft = TrackedInvestmentAssetDraft(
      portfolioId: widget.portfolioId ?? '',
      ticker: entry.ticker,
      name: entry.name,
      type: entry.type,
    );
    final String assetId = TrackedInvestmentAsset.documentId(
      portfolioId: assetDraft.portfolioId,
      ticker: assetDraft.ticker,
    );
    final InvestmentOperationDraft operationDraft = InvestmentOperationDraft(
      portfolioId: assetDraft.portfolioId,
      assetId: assetId,
      kind: InvestmentOperationKind.buy,
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
      notes: '',
    ).normalized(now: now);
    final bool success = await ref
        .read(investmentActionControllerProvider.notifier)
        .createAssetWithInitialBuy(
          assetDraft: assetDraft,
          operationDraft: operationDraft,
        );
    if (success && mounted) Navigator.of(context).pop();
  }

  Future<void> _submitEditing(TrackedInvestmentAsset asset) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final bool success = await ref
        .read(investmentActionControllerProvider.notifier)
        .updateAsset(
          asset: asset,
          update: TrackedInvestmentAssetUpdate(
            name: _nameController.text,
            type: _editingType,
          ),
        );
    if (success && mounted) Navigator.of(context).pop();
  }

  String? _validateQuantity(String? value) =>
      _validate(() => InvestmentQuantity.parsePtBr(value ?? '').scaled);

  String? _validatePrice(String? value) =>
      _validate(() => InvestmentUnitPrice.parsePtBr(value ?? '').scaled);

  String? _validateFees(String? value) =>
      _validate(() => InvestmentMoneyInput.parseNonNegativeCents(value ?? ''));

  String? _validateName(String? value) =>
      _validate(() => TrackedInvestmentAsset.requireName(value ?? ''));

  String? _validate(Object Function() operation) {
    try {
      operation();
      return null;
    } on InvestmentFailure catch (failure) {
      return failure.safeMessage;
    }
  }

  Widget _actionFailure(InvestmentActionState action) =>
      action.status == InvestmentActionStatus.failure && action.message != null
      ? Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md),
          child: Text(
            action.message!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        )
      : const SizedBox.shrink();

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

final class _SelectedAssetCard extends StatelessWidget {
  const _SelectedAssetCard({required this.entry});

  final InvestmentAssetDirectoryEntry entry;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey<String>('investment-selected-asset'),
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.secondaryContainer,
      borderRadius: AppRadius.medium,
    ),
    child: Row(
      children: <Widget>[
        Icon(
          entry.type == TrackedInvestmentAssetType.stock
              ? Icons.candlestick_chart_outlined
              : Icons.apartment_rounded,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                entry.ticker,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(entry.name),
            ],
          ),
        ),
        Text(entry.type.label),
      ],
    ),
  );
}
