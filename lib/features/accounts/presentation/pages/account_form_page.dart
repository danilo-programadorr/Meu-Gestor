import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_gestor_financeiro/app/routing/app_routes.dart';
import 'package:meu_gestor_financeiro/app/routing/safe_back_navigation.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
import 'package:meu_gestor_financeiro/features/accounts/domain/account_name.dart';
import 'package:meu_gestor_financeiro/features/accounts/domain/financial_account.dart';
import 'package:meu_gestor_financeiro/features/accounts/domain/financial_account_failure.dart';
import 'package:meu_gestor_financeiro/features/accounts/domain/money_input_parser.dart';
import 'package:meu_gestor_financeiro/features/accounts/presentation/controllers/financial_account_action_controller.dart';
import 'package:meu_gestor_financeiro/features/accounts/presentation/controllers/financial_accounts_controller.dart';
import 'package:meu_gestor_financeiro/features/accounts/presentation/widgets/account_type_selector.dart';
import 'package:meu_gestor_financeiro/features/accounts/presentation/widgets/account_view_support.dart';
import 'package:meu_gestor_financeiro/features/accounts/presentation/widgets/money_input_field.dart';

class AccountFormPage extends ConsumerStatefulWidget {
  const AccountFormPage({
    this.accountId,
    this.returnToPrevious = false,
    super.key,
  });

  final String? accountId;
  final bool returnToPrevious;

  @override
  ConsumerState<AccountFormPage> createState() => _AccountFormPageState();
}

class _AccountFormPageState extends ConsumerState<AccountFormPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _balanceController = TextEditingController(
    text: '0,00',
  );
  FinancialAccountType _type = FinancialAccountType.checking;
  bool _includeInTotal = true;
  bool _initialized = false;

  bool get _isEditing => widget.accountId != null;

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<FinancialAccountActionState>(
      financialAccountActionControllerProvider,
      (
        FinancialAccountActionState? previous,
        FinancialAccountActionState next,
      ) {
        if (next.status == FinancialAccountActionStatus.success &&
            previous?.status != FinancialAccountActionStatus.success &&
            next.account != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              if (_isEditing || widget.returnToPrevious) {
                popOrGoToFallback(
                  context,
                  _isEditing
                      ? AppRoutes.accountDetails(next.account!.id)
                      : AppRoutes.accounts,
                );
              } else {
                context.go(AppRoutes.accountDetails(next.account!.id));
              }
            }
          });
        }
      },
    );

    if (_isEditing) {
      final AsyncValue<FinancialAccount> accountState = ref.watch(
        financialAccountDetailsProvider(widget.accountId!),
      );
      return accountState.when(
        loading: () => _loadingScaffold('Carregando conta'),
        error: (Object error, StackTrace stackTrace) =>
            _errorScaffold(safeAccountsErrorMessage(error)),
        data: (FinancialAccount account) {
          _initializeFrom(account);
          return _buildForm();
        },
      );
    }
    _initialized = true;
    return _buildForm();
  }

  void _initializeFrom(FinancialAccount account) {
    if (_initialized) {
      return;
    }
    _initialized = true;
    _nameController.text = account.name;
    _balanceController.text = MoneyInputParser.formatEditable(
      account.openingBalanceCents,
    );
    _type = account.type;
    _includeInTotal = account.includeInTotal;
  }

  Widget _buildForm() {
    final FinancialAccountActionState action = ref.watch(
      financialAccountActionControllerProvider,
    );
    return _withSafeBack(
      Scaffold(
        appBar: AppBar(
          leading: SafeBackButton(fallbackLocation: _fallbackLocation),
          title: Text(_isEditing ? 'Editar conta' : 'Nova conta'),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.sentences,
                        maxLength: AccountName.maximumLength,
                        decoration: const InputDecoration(
                          labelText: 'Nome da conta',
                          hintText: 'Ex.: Conta principal',
                          helperText: 'Use um nome fácil de reconhecer.',
                        ),
                        validator: (String? value) =>
                            AccountName.validate(value ?? ''),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AccountTypeSelector(
                        value: _type,
                        onChanged: (FinancialAccountType value) {
                          setState(() => _type = value);
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      MoneyInputField(controller: _balanceController),
                      const SizedBox(height: AppSpacing.md),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Incluir no total geral'),
                        subtitle: const Text(
                          'Desative para manter a conta visível sem somá-la ao total.',
                        ),
                        value: _includeInTotal,
                        onChanged: action.isLoading
                            ? null
                            : (bool value) {
                                setState(() => _includeInTotal = value);
                              },
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
                                      FinancialAccountActionStatus.failure
                                  ? Theme.of(context).colorScheme.error
                                  : null,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      FilledButton(
                        onPressed: action.isLoading ? null : _submit,
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
                                    : 'Criar conta',
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

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final int cents;
    try {
      cents = MoneyInputParser.parseBrlCents(_balanceController.text);
    } on FinancialAccountFailure {
      _formKey.currentState?.validate();
      return;
    }
    final FinancialAccountDraft draft = FinancialAccountDraft(
      name: _nameController.text,
      type: _type,
      openingBalanceCents: cents,
      includeInTotal: _includeInTotal,
    );
    final FinancialAccountActionController controller = ref.read(
      financialAccountActionControllerProvider.notifier,
    );
    if (_isEditing) {
      controller.updateAccount(accountId: widget.accountId!, draft: draft);
    } else {
      controller.create(draft);
    }
  }

  Widget _loadingScaffold(String label) => _withSafeBack(
    Scaffold(
      appBar: AppBar(
        leading: SafeBackButton(fallbackLocation: _fallbackLocation),
        title: Text(_isEditing ? 'Editar conta' : 'Nova conta'),
      ),
      body: Center(child: CircularProgressIndicator(semanticsLabel: label)),
    ),
  );

  Widget _errorScaffold(String message) => _withSafeBack(
    Scaffold(
      appBar: AppBar(
        leading: SafeBackButton(fallbackLocation: _fallbackLocation),
        title: Text(_isEditing ? 'Editar conta' : 'Nova conta'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(message, textAlign: TextAlign.center),
        ),
      ),
    ),
  );

  String get _fallbackLocation => _isEditing
      ? AppRoutes.accountDetails(widget.accountId!)
      : AppRoutes.accounts;

  Widget _withSafeBack(Widget child) =>
      SafeBackScope(fallbackLocation: _fallbackLocation, child: child);
}
