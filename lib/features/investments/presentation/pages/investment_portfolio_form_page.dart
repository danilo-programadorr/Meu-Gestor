import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_gestor_financeiro/app/routing/app_routes.dart';
import 'package:meu_gestor_financeiro/app/routing/safe_back_navigation.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_failure.dart';
import 'package:meu_gestor_financeiro/features/investments/domain/investment_portfolio.dart';
import 'package:meu_gestor_financeiro/features/investments/presentation/controllers/investment_action_controller.dart';
import 'package:meu_gestor_financeiro/features/investments/presentation/controllers/investments_controller.dart';

class InvestmentPortfolioFormPage extends ConsumerStatefulWidget {
  const InvestmentPortfolioFormPage({this.portfolioId, super.key});

  final String? portfolioId;

  @override
  ConsumerState<InvestmentPortfolioFormPage> createState() =>
      _InvestmentPortfolioFormPageState();
}

class _InvestmentPortfolioFormPageState
    extends ConsumerState<InvestmentPortfolioFormPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _initialized = false;

  bool get _editing => widget.portfolioId != null;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
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
    final InvestmentPortfolio? portfolio = _editing
        ? workspace.value?.portfolioById(widget.portfolioId!)
        : null;
    if (_editing && workspace.isLoading) {
      return _loading();
    }
    if (_editing && (workspace.hasError || portfolio == null)) {
      return _error(
        workspace.hasError
            ? safeInvestmentErrorMessage(workspace.error!)
            : 'Esta carteira não foi encontrada.',
      );
    }
    if (!_initialized) {
      _initialized = true;
      if (portfolio != null) {
        _nameController.text = portfolio.name;
        _descriptionController.text = portfolio.description;
      }
    }
    return SafeBackScope(
      fallbackLocation: AppRoutes.investments,
      child: Scaffold(
        appBar: AppBar(
          leading: const SafeBackButton(
            fallbackLocation: AppRoutes.investments,
          ),
          title: Text(_editing ? 'Editar carteira' : 'Nova carteira'),
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
                      TextFormField(
                        controller: _nameController,
                        enabled: !action.isLoading,
                        textInputAction: TextInputAction.next,
                        maxLength: InvestmentPortfolio.maximumNameLength,
                        decoration: const InputDecoration(
                          labelText: 'Nome da carteira ou corretora',
                          hintText: 'Ex.: Carteira principal',
                        ),
                        validator: (String? value) => _validateName(value),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _descriptionController,
                        enabled: !action.isLoading,
                        maxLength: InvestmentPortfolio.maximumDescriptionLength,
                        minLines: 2,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Descrição opcional',
                        ),
                        validator: (String? value) =>
                            _validateDescription(value),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      FilledButton(
                        onPressed: action.isLoading
                            ? null
                            : () => _submit(portfolio),
                        child: action.isLoading
                            ? const SizedBox.square(
                                dimension: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  semanticsLabel: 'Salvando carteira',
                                ),
                              )
                            : Text(
                                _editing
                                    ? 'Salvar alterações'
                                    : 'Criar carteira',
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

  Future<void> _submit(InvestmentPortfolio? portfolio) async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final InvestmentPortfolioDraft draft = InvestmentPortfolioDraft(
      name: _nameController.text,
      description: _descriptionController.text,
    );
    final InvestmentActionController controller = ref.read(
      investmentActionControllerProvider.notifier,
    );
    final bool success = portfolio == null
        ? await controller.createPortfolio(draft)
        : await controller.updatePortfolio(portfolio: portfolio, draft: draft);
    if (success && mounted) {
      Navigator.of(context).pop();
    }
  }

  String? _validateName(String? value) {
    try {
      InvestmentPortfolio.normalizeName(value ?? '');
      return null;
    } on InvestmentFailure catch (failure) {
      return failure.safeMessage;
    }
  }

  String? _validateDescription(String? value) {
    try {
      InvestmentPortfolio.normalizeDescription(value ?? '');
      return null;
    } on InvestmentFailure catch (failure) {
      return failure.safeMessage;
    }
  }

  Widget _loading() => const Scaffold(
    body: Center(
      child: CircularProgressIndicator(semanticsLabel: 'Carregando carteira'),
    ),
  );

  Widget _error(String message) => SafeBackScope(
    fallbackLocation: AppRoutes.investments,
    child: Scaffold(
      appBar: AppBar(
        leading: const SafeBackButton(fallbackLocation: AppRoutes.investments),
        title: const Text('Editar carteira'),
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
