import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_gestor_financeiro/app/routing/app_routes.dart';
import 'package:meu_gestor_financeiro/app/routing/safe_back_navigation.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
import 'package:meu_gestor_financeiro/core/dates/sao_paulo_civil_date.dart';
import 'package:meu_gestor_financeiro/features/categories/domain/financial_category.dart';
import 'package:meu_gestor_financeiro/features/categories/presentation/controllers/financial_categories_controller.dart';
import 'package:meu_gestor_financeiro/features/commitments/domain/financial_commitment.dart';
import 'package:meu_gestor_financeiro/features/commitments/domain/financial_commitment_failure.dart';
import 'package:meu_gestor_financeiro/features/commitments/presentation/controllers/financial_commitment_action_controller.dart';
import 'package:meu_gestor_financeiro/features/commitments/presentation/controllers/financial_commitments_controller.dart';
import 'package:meu_gestor_financeiro/features/commitments/presentation/widgets/commitment_view_support.dart';
import 'package:meu_gestor_financeiro/features/transactions/data/financial_transaction_providers.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_transaction_failure.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/positive_money_input_parser.dart';
import 'package:meu_gestor_financeiro/features/transactions/presentation/widgets/positive_money_input_field.dart';

class CommitmentFormPage extends ConsumerStatefulWidget {
  const CommitmentFormPage({required this.kind, this.commitmentId, super.key});

  final FinancialCommitmentKind kind;
  final String? commitmentId;

  @override
  ConsumerState<CommitmentFormPage> createState() => _CommitmentFormPageState();
}

class _CommitmentFormPageState extends ConsumerState<CommitmentFormPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  String? _categoryId;
  SaoPauloCivilDate? _dueDate;
  bool _initialized = false;
  bool _navigating = false;

  bool get _isEditing => widget.commitmentId != null;

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<FinancialCategoriesState> categories = ref.watch(
      financialCategoriesControllerProvider,
    );
    final AsyncValue<FinancialCommitment>? commitment = _commitment();
    final FinancialCommitmentActionState action = ref.watch(
      financialCommitmentActionControllerProvider,
    );
    if (categories.isLoading || commitment?.isLoading == true) {
      return _loadingScaffold();
    }
    if (categories.hasError || commitment?.hasError == true) {
      return _messageScaffold(
        safeFinancialCommitmentErrorMessage(
          categories.error ?? commitment!.error!,
        ),
      );
    }
    final FinancialCommitment? current = commitment?.requireValue;
    if (current != null && !current.isPending) {
      return _messageScaffold(
        'Somente compromissos pendentes podem ser editados.',
      );
    }
    _initialize(current);
    final FinancialCategoryKind categoryKind =
        widget.kind == FinancialCommitmentKind.payable
        ? FinancialCategoryKind.expense
        : FinancialCategoryKind.income;
    final List<FinancialCategory> compatible = categories.requireValue
        .activeByKind(categoryKind);
    final bool selectedExists = compatible.any(
      (FinancialCategory item) => item.id == _categoryId,
    );
    if (!selectedExists) {
      _categoryId = null;
    }
    return SafeBackScope(
      fallbackLocation: _fallbackLocation,
      child: Scaffold(
        appBar: AppBar(
          leading: SafeBackButton(fallbackLocation: _fallbackLocation),
          title: Text(_isEditing ? 'Editar compromisso' : widget.kind.singular),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        _isEditing
                            ? 'Altere os dados do compromisso pendente.'
                            : 'Cadastre um compromisso futuro ou já vencido. Ele não altera o saldo até a liquidação.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      TextFormField(
                        controller: _descriptionController,
                        enabled: !action.isLoading,
                        textCapitalization: TextCapitalization.sentences,
                        maxLength: 120,
                        decoration: const InputDecoration(
                          labelText: 'Descrição',
                        ),
                        validator: _validateDescription,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (compatible.isEmpty)
                        _MissingReferenceCard(
                          message:
                              'Cadastre uma categoria ${categoryKind.label.toLowerCase()} ativa antes de continuar.',
                          onPressed: () =>
                              context.push(AppRoutes.newCategoryReturning),
                        )
                      else
                        DropdownButtonFormField<String>(
                          initialValue: _categoryId,
                          decoration: const InputDecoration(
                            labelText: 'Categoria',
                          ),
                          items: compatible
                              .map(
                                (FinancialCategory category) =>
                                    DropdownMenuItem<String>(
                                      value: category.id,
                                      child: Text(category.name),
                                    ),
                              )
                              .toList(growable: false),
                          onChanged: action.isLoading
                              ? null
                              : (String? value) {
                                  setState(() => _categoryId = value);
                                },
                          validator: (String? value) => value == null
                              ? 'Escolha uma categoria compatível.'
                              : null,
                        ),
                      const SizedBox(height: AppSpacing.md),
                      PositiveMoneyInputField(
                        controller: _amountController,
                        enabled: !action.isLoading,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      FormField<SaoPauloCivilDate>(
                        key: ValueKey<String>('due-${_dueDate.toString()}'),
                        initialValue: _dueDate,
                        validator: (SaoPauloCivilDate? value) => value == null
                            ? 'Escolha a data de vencimento.'
                            : null,
                        builder: (FormFieldState<SaoPauloCivilDate> field) =>
                            CivilDateField(
                              label: 'Data de vencimento',
                              selectedDate: _dueDate,
                              enabled: !action.isLoading,
                              errorText: field.errorText,
                              helperText:
                                  'Dia previsto para pagar ou receber; pode estar no passado, hoje ou futuro.',
                              onPressed: () => _chooseDueDate(field),
                            ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _notesController,
                        enabled: !action.isLoading,
                        textCapitalization: TextCapitalization.sentences,
                        minLines: 3,
                        maxLines: 5,
                        maxLength: 500,
                        decoration: const InputDecoration(
                          labelText: 'Observações (opcional)',
                        ),
                        validator: _validateNotes,
                      ),
                      if (action.message case final String message) ...<Widget>[
                        const SizedBox(height: AppSpacing.md),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            message,
                            style: TextStyle(
                              color:
                                  action.status ==
                                      FinancialCommitmentActionStatus.failure
                                  ? Theme.of(context).colorScheme.error
                                  : null,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      FilledButton(
                        onPressed:
                            action.isLoading ||
                                compatible.isEmpty ||
                                _navigating
                            ? null
                            : () => _submit(current),
                        child: action.isLoading
                            ? const SizedBox.square(
                                dimension: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                _isEditing
                                    ? 'Salvar alterações'
                                    : 'Salvar compromisso',
                              ),
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

  AsyncValue<FinancialCommitment>? _commitment() {
    final String? id = widget.commitmentId;
    if (id == null) {
      return null;
    }
    return widget.kind == FinancialCommitmentKind.payable
        ? ref.watch(payableDetailsProvider(id))
        : ref.watch(receivableDetailsProvider(id));
  }

  void _initialize(FinancialCommitment? commitment) {
    if (_initialized) {
      return;
    }
    _initialized = true;
    if (commitment == null) {
      _dueDate = SaoPauloCivilDate.fromInstant(
        ref.read(financialClockProvider)().toUtc(),
      );
      return;
    }
    _descriptionController.text = commitment.description;
    _amountController.text = PositiveMoneyInputParser.formatEditable(
      commitment.amountCents,
    );
    _notesController.text = commitment.notes;
    _categoryId = commitment.categoryId;
    _dueDate = commitment.dueDate;
  }

  Future<void> _chooseDueDate(FormFieldState<SaoPauloCivilDate> field) async {
    final SaoPauloCivilDate? selected = await showCivilDatePicker(
      context: context,
      selectedDate:
          _dueDate ??
          SaoPauloCivilDate.fromInstant(
            ref.read(financialClockProvider)().toUtc(),
          ),
      helpText: 'Data de vencimento',
    );
    if (selected != null && mounted) {
      setState(() => _dueDate = selected);
      field.didChange(selected);
    }
  }

  Future<void> _submit(FinancialCommitment? current) async {
    if (!(_formKey.currentState?.validate() ?? false) ||
        _categoryId == null ||
        _dueDate == null ||
        _navigating) {
      return;
    }
    final int amountCents;
    try {
      amountCents = PositiveMoneyInputParser.parseBrlCents(
        _amountController.text,
      );
    } on FinancialTransactionFailure {
      _formKey.currentState?.validate();
      return;
    }
    final FinancialCommitmentActionController controller = ref.read(
      financialCommitmentActionControllerProvider.notifier,
    );
    final bool success;
    if (current == null) {
      final FinancialCommitmentDraft draft = FinancialCommitmentDraft(
        description: _descriptionController.text,
        categoryId: _categoryId!,
        amountCents: amountCents,
        dueDate: _dueDate!,
        notes: _notesController.text,
      );
      success = widget.kind == FinancialCommitmentKind.payable
          ? await controller.createPayable(draft)
          : await controller.createReceivable(draft);
    } else {
      success = await controller.updatePending(
        commitment: current,
        update: FinancialCommitmentUpdate(
          description: _descriptionController.text,
          categoryId: _categoryId!,
          amountCents: amountCents,
          dueDate: _dueDate!,
          notes: _notesController.text,
          expectedRevision: current.revision,
        ),
      );
    }
    if (!success || !mounted || _navigating) {
      return;
    }
    _navigating = true;
    final FinancialCommitment? saved = ref
        .read(financialCommitmentActionControllerProvider)
        .commitment;
    final String location = saved == null
        ? AppRoutes.commitments(widget.kind)
        : AppRoutes.commitmentDetails(widget.kind, saved.id);
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(location);
    }
  }

  String? _validateDescription(String? value) {
    try {
      FinancialCommitmentDraft(
        description: value ?? '',
        categoryId: _categoryId ?? 'pending-category',
        amountCents: 1,
        dueDate: _dueDate ?? SaoPauloCivilDate(year: 2000, month: 1, day: 1),
        notes: '',
      ).normalized();
      return null;
    } on FinancialCommitmentFailure catch (failure) {
      return failure.safeMessage;
    }
  }

  String? _validateNotes(String? value) {
    try {
      FinancialCommitmentDraft(
        description: 'Validação',
        categoryId: 'pending-category',
        amountCents: 1,
        dueDate: SaoPauloCivilDate(year: 2000, month: 1, day: 1),
        notes: value ?? '',
      ).normalized();
      return null;
    } on FinancialCommitmentFailure catch (failure) {
      return failure.safeMessage;
    }
  }

  String get _fallbackLocation => _isEditing
      ? AppRoutes.commitmentDetails(widget.kind, widget.commitmentId!)
      : AppRoutes.commitments(widget.kind);

  Widget _loadingScaffold() => SafeBackScope(
    fallbackLocation: _fallbackLocation,
    child: Scaffold(
      appBar: AppBar(
        leading: SafeBackButton(fallbackLocation: _fallbackLocation),
        title: const Text('Compromisso financeiro'),
      ),
      body: const Center(
        child: CircularProgressIndicator(
          semanticsLabel: 'Carregando compromisso financeiro',
        ),
      ),
    ),
  );

  Widget _messageScaffold(String message) => SafeBackScope(
    fallbackLocation: _fallbackLocation,
    child: Scaffold(
      appBar: AppBar(
        leading: SafeBackButton(fallbackLocation: _fallbackLocation),
        title: const Text('Compromisso financeiro'),
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

class _MissingReferenceCard extends StatelessWidget {
  const _MissingReferenceCard({required this.message, required this.onPressed});

  final String message;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: <Widget>[
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            onPressed: onPressed,
            child: const Text('Cadastrar categoria'),
          ),
        ],
      ),
    ),
  );
}
