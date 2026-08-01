import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_gestor_financeiro/app/routing/app_routes.dart';
import 'package:meu_gestor_financeiro/app/routing/safe_back_navigation.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
import 'package:meu_gestor_financeiro/features/accounts/domain/financial_account.dart';
import 'package:meu_gestor_financeiro/features/categories/domain/financial_category.dart';
import 'package:meu_gestor_financeiro/features/transactions/data/financial_transaction_providers.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_transaction.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_transaction_date.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_transaction_failure.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/financial_transaction_text.dart';
import 'package:meu_gestor_financeiro/features/transactions/domain/positive_money_input_parser.dart';
import 'package:meu_gestor_financeiro/features/transactions/presentation/controllers/financial_transaction_action_controller.dart';
import 'package:meu_gestor_financeiro/features/transactions/presentation/controllers/financial_transactions_controller.dart';
import 'package:meu_gestor_financeiro/features/transactions/presentation/widgets/movement_date_field.dart';
import 'package:meu_gestor_financeiro/features/transactions/presentation/widgets/positive_money_input_field.dart';
import 'package:meu_gestor_financeiro/features/transactions/presentation/widgets/transaction_kind_selector.dart';
import 'package:meu_gestor_financeiro/features/transactions/presentation/widgets/transaction_view_support.dart';

class TransactionFormPage extends ConsumerStatefulWidget {
  const TransactionFormPage({this.transactionId, super.key});

  final String? transactionId;

  @override
  ConsumerState<TransactionFormPage> createState() =>
      _TransactionFormPageState();
}

class _TransactionFormPageState extends ConsumerState<TransactionFormPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  FinancialTransactionKind _kind = FinancialTransactionKind.expense;
  String? _accountId;
  String? _categoryId;
  DateTime? _selectedDate;
  bool _initialized = false;

  bool get _isEditing => widget.transactionId != null;

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<FinancialTransactionActionState>(
      financialTransactionActionControllerProvider,
      (
        FinancialTransactionActionState? previous,
        FinancialTransactionActionState next,
      ) {
        if (next.status == FinancialTransactionActionStatus.success &&
            previous?.status != FinancialTransactionActionStatus.success &&
            next.transaction != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) {
              return;
            }
            final String detailsLocation = AppRoutes.transactionDetails(
              next.transaction!.id,
            );
            if (_isEditing) {
              popOrGoToFallback(context, detailsLocation);
            } else if (context.canPop()) {
              context.pushReplacement(detailsLocation);
            } else {
              context.go(detailsLocation);
            }
          });
        }
      },
    );
    final AsyncValue<FinancialWorkspace> workspace = ref.watch(
      financialWorkspaceProvider,
    );
    return workspace.when(
      loading: () => _loadingScaffold('Carregando dados financeiros'),
      error: (Object error, StackTrace stackTrace) =>
          _errorScaffold(safeTransactionsErrorMessage(error)),
      data: (FinancialWorkspace value) {
        if (_isEditing) {
          final AsyncValue<FinancialTransaction> transaction = ref.watch(
            financialTransactionDetailsProvider(widget.transactionId!),
          );
          return transaction.when(
            loading: () => _loadingScaffold('Carregando lançamento'),
            error: (Object error, StackTrace stackTrace) =>
                _errorScaffold(safeTransactionsErrorMessage(error)),
            data: (FinancialTransaction current) {
              final FinancialTransaction effective =
                  value.transactions.findById(current.id) ?? current;
              if (effective.isVoided) {
                return _voidedEditScaffold();
              }
              _initialize(value, effective);
              return _buildForm(value, effective);
            },
          );
        }
        _initialize(value, null);
        return _buildForm(value, null);
      },
    );
  }

  void _initialize(
    FinancialWorkspace workspace,
    FinancialTransaction? transaction,
  ) {
    if (_initialized) {
      return;
    }
    _initialized = true;
    if (transaction != null) {
      _kind = transaction.kind;
      _accountId = transaction.accountId;
      _categoryId = transaction.categoryId;
      _descriptionController.text = transaction.description;
      _amountController.text = PositiveMoneyInputParser.formatEditable(
        transaction.amountCents,
      );
      _notesController.text = transaction.notes;
      _selectedDate = FinancialTransactionDate.saoPauloCalendarDate(
        transaction.occurredAt,
      );
      return;
    }
    final List<FinancialAccount> accounts = workspace.accounts.activeAccounts;
    final List<FinancialCategory> categories = workspace.categories
        .activeByKind(_kind.categoryKind);
    _accountId = accounts.isEmpty ? null : accounts.first.id;
    _categoryId = categories.isEmpty ? null : categories.first.id;
    _selectedDate = FinancialTransactionDate.todayInSaoPaulo(
      ref.read(financialClockProvider)(),
    );
  }

  Widget _buildForm(
    FinancialWorkspace workspace,
    FinancialTransaction? current,
  ) {
    final FinancialTransactionActionState action = ref.watch(
      financialTransactionActionControllerProvider,
    );
    final List<FinancialAccount> activeAccounts =
        workspace.accounts.activeAccounts;
    final List<FinancialAccount> accountOptions = _isEditing
        ? workspace.accounts.accounts
        : activeAccounts;
    final List<FinancialCategory> activeCategories = workspace.categories
        .activeByKind(_kind.categoryKind);
    final String? categoryValue =
        activeCategories.any(
          (FinancialCategory category) => category.id == _categoryId,
        )
        ? _categoryId
        : null;
    final bool canSubmit = _isEditing
        ? current?.isVoided == false && activeCategories.isNotEmpty
        : activeAccounts.isNotEmpty && activeCategories.isNotEmpty;
    return _withSafeBack(
      Scaffold(
        appBar: AppBar(
          leading: SafeBackButton(fallbackLocation: _fallbackLocation),
          title: Text(_isEditing ? 'Editar lançamento' : 'Novo lançamento'),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      TransactionKindSelector(
                        value: _kind,
                        enabled: !_isEditing && !action.isLoading,
                        onChanged: (FinancialTransactionKind value) {
                          final List<FinancialCategory> compatible = workspace
                              .categories
                              .activeByKind(value.categoryKind);
                          setState(() {
                            _kind = value;
                            _categoryId = compatible.isEmpty
                                ? null
                                : compatible.first.id;
                          });
                        },
                      ),
                      if (_isEditing) ...<Widget>[
                        const SizedBox(height: AppSpacing.xs),
                        const Text(
                          'Tipo, conta e valor são protegidos. Para corrigi-los, cancele este lançamento e registre outro.',
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _descriptionController,
                        textCapitalization: TextCapitalization.sentences,
                        maxLength:
                            FinancialTransactionText.maximumDescriptionLength,
                        decoration: const InputDecoration(
                          labelText: 'Descrição',
                          helperText: 'Informe o que entrou ou saiu.',
                        ),
                        validator: (String? value) =>
                            FinancialTransactionText.validateDescription(
                              value ?? '',
                            ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      PositiveMoneyInputField(
                        controller: _amountController,
                        enabled: !_isEditing && !action.isLoading,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (activeAccounts.isEmpty && !_isEditing)
                        _MissingReferenceCard(
                          message:
                              'Crie uma conta ativa antes de registrar um lançamento.',
                          buttonLabel: 'Criar conta',
                          onPressed: () =>
                              context.push(AppRoutes.newAccountReturning),
                        )
                      else
                        DropdownButtonFormField<String>(
                          initialValue: _accountId,
                          decoration: const InputDecoration(labelText: 'Conta'),
                          items: accountOptions
                              .map(
                                (FinancialAccount account) => DropdownMenuItem(
                                  value: account.id,
                                  child: Text(account.name),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: _isEditing || action.isLoading
                              ? null
                              : (String? value) {
                                  setState(() => _accountId = value);
                                },
                          validator: (String? value) =>
                              value == null ? 'Escolha uma conta.' : null,
                        ),
                      const SizedBox(height: AppSpacing.md),
                      if (activeCategories.isEmpty)
                        _MissingReferenceCard(
                          message:
                              'Crie ou restaure uma categoria de ${_kind.label.toLowerCase()} antes de continuar.',
                          buttonLabel: 'Criar categoria',
                          onPressed: () =>
                              context.push(AppRoutes.newCategoryReturning),
                        )
                      else
                        DropdownButtonFormField<String>(
                          initialValue: categoryValue,
                          decoration: const InputDecoration(
                            labelText: 'Categoria',
                          ),
                          items: activeCategories
                              .map(
                                (FinancialCategory category) =>
                                    DropdownMenuItem(
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
                      FormField<DateTime>(
                        initialValue: _selectedDate,
                        validator: (DateTime? value) {
                          if (value == null) {
                            return 'Escolha a data do lançamento.';
                          }
                          try {
                            FinancialTransactionDate.validateNotFuture(
                              FinancialTransactionDate.fromCalendarDate(value),
                              ref.read(financialClockProvider)(),
                            );
                            return null;
                          } on FinancialTransactionFailure catch (failure) {
                            return failure.safeMessage;
                          }
                        },
                        builder: (FormFieldState<DateTime> field) =>
                            MovementDateField(
                              selectedDate: _selectedDate,
                              enabled: !action.isLoading,
                              errorText: field.errorText,
                              onPressed: () => _chooseDate(field),
                            ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _notesController,
                        textCapitalization: TextCapitalization.sentences,
                        minLines: 3,
                        maxLines: 5,
                        maxLength: FinancialTransactionText.maximumNotesLength,
                        decoration: const InputDecoration(
                          labelText: 'Observações (opcional)',
                        ),
                        validator: (String? value) =>
                            FinancialTransactionText.validateNotes(value ?? ''),
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
                                      FinancialTransactionActionStatus.failure
                                  ? Theme.of(context).colorScheme.error
                                  : null,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      FilledButton(
                        onPressed: action.isLoading || !canSubmit
                            ? null
                            : _submit,
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
                                    : _kind == FinancialTransactionKind.income
                                    ? 'Registrar receita'
                                    : 'Registrar despesa',
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

  Future<void> _chooseDate(FormFieldState<DateTime> field) async {
    final DateTime today = FinancialTransactionDate.todayInSaoPaulo(
      ref.read(financialClockProvider)(),
    );
    final DateTime? selected = await showMovementDatePicker(
      context: context,
      selectedDate: _selectedDate ?? today,
      today: today,
    );
    if (selected != null) {
      setState(() => _selectedDate = selected);
      field.didChange(selected);
    }
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false) ||
        _selectedDate == null ||
        _categoryId == null) {
      return;
    }
    final FinancialTransactionActionController controller = ref.read(
      financialTransactionActionControllerProvider.notifier,
    );
    final DateTime occurredAt = FinancialTransactionDate.fromCalendarDate(
      _selectedDate!,
    );
    if (_isEditing) {
      controller.updateTransaction(
        transactionId: widget.transactionId!,
        edit: FinancialTransactionEdit(
          categoryId: _categoryId!,
          description: _descriptionController.text,
          occurredAt: occurredAt,
          notes: _notesController.text,
        ),
      );
      return;
    }
    if (_accountId == null) {
      return;
    }
    try {
      controller.create(
        FinancialTransactionDraft(
          accountId: _accountId!,
          categoryId: _categoryId!,
          kind: _kind,
          description: _descriptionController.text,
          amountCents: PositiveMoneyInputParser.parseBrlCents(
            _amountController.text,
          ),
          occurredAt: occurredAt,
          notes: _notesController.text,
        ),
      );
    } on FinancialTransactionFailure {
      _formKey.currentState?.validate();
    }
  }

  Widget _loadingScaffold(String label) => _withSafeBack(
    Scaffold(
      appBar: AppBar(
        leading: SafeBackButton(fallbackLocation: _fallbackLocation),
        title: Text(_isEditing ? 'Editar lançamento' : 'Novo lançamento'),
      ),
      body: Center(child: CircularProgressIndicator(semanticsLabel: label)),
    ),
  );

  Widget _errorScaffold(String message) => _withSafeBack(
    Scaffold(
      appBar: AppBar(
        leading: SafeBackButton(fallbackLocation: _fallbackLocation),
        title: Text(_isEditing ? 'Editar lançamento' : 'Novo lançamento'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(message, textAlign: TextAlign.center),
        ),
      ),
    ),
  );

  Widget _voidedEditScaffold() => _withSafeBack(
    Scaffold(
      appBar: AppBar(
        leading: SafeBackButton(fallbackLocation: _fallbackLocation),
        title: const Text('Editar lançamento'),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Text(
            'Este lançamento foi cancelado e não pode ser editado.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ),
  );

  String get _fallbackLocation => _isEditing
      ? AppRoutes.transactionDetails(widget.transactionId!)
      : AppRoutes.transactions;

  Widget _withSafeBack(Widget child) =>
      SafeBackScope(fallbackLocation: _fallbackLocation, child: child);
}

class _MissingReferenceCard extends StatelessWidget {
  const _MissingReferenceCard({
    required this.message,
    required this.buttonLabel,
    required this.onPressed,
  });

  final String message;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: <Widget>[
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(onPressed: onPressed, child: Text(buttonLabel)),
        ],
      ),
    ),
  );
}
