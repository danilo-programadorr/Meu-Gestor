import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_gestor_financeiro/app/routing/app_routes.dart';
import 'package:meu_gestor_financeiro/app/routing/safe_back_navigation.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
import 'package:meu_gestor_financeiro/features/categories/domain/financial_category.dart';
import 'package:meu_gestor_financeiro/features/categories/presentation/controllers/financial_categories_controller.dart';
import 'package:meu_gestor_financeiro/features/categories/presentation/controllers/financial_category_action_controller.dart';
import 'package:meu_gestor_financeiro/features/categories/presentation/widgets/category_selectors.dart';
import 'package:meu_gestor_financeiro/features/categories/presentation/widgets/category_visuals.dart';

class CategoryFormPage extends ConsumerStatefulWidget {
  const CategoryFormPage({
    this.categoryId,
    this.returnToPrevious = false,
    super.key,
  });

  final String? categoryId;
  final bool returnToPrevious;

  @override
  ConsumerState<CategoryFormPage> createState() => _CategoryFormPageState();
}

class _CategoryFormPageState extends ConsumerState<CategoryFormPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  FinancialCategoryKind _kind = FinancialCategoryKind.expense;
  FinancialCategoryIcon _icon = FinancialCategoryIcon.other;
  FinancialCategoryColor _color = FinancialCategoryColor.blue;
  bool _initialized = false;

  bool get _isEditing => widget.categoryId != null;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<FinancialCategoryActionState>(
      financialCategoryActionControllerProvider,
      (
        FinancialCategoryActionState? previous,
        FinancialCategoryActionState next,
      ) {
        if (next.status == FinancialCategoryActionStatus.success &&
            previous?.status != FinancialCategoryActionStatus.success) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              if (_isEditing || widget.returnToPrevious) {
                popOrGoToFallback(context, AppRoutes.categories);
              } else {
                context.go(AppRoutes.categories);
              }
            }
          });
        }
      },
    );
    if (_isEditing) {
      final AsyncValue<FinancialCategory> state = ref.watch(
        financialCategoryDetailsProvider(widget.categoryId!),
      );
      return state.when(
        loading: () => _loadingScaffold(),
        error: (Object error, StackTrace stackTrace) =>
            _errorScaffold(safeCategoriesErrorMessage(error)),
        data: (FinancialCategory category) {
          _initialize(category);
          return _buildForm();
        },
      );
    }
    _initialized = true;
    return _buildForm();
  }

  void _initialize(FinancialCategory category) {
    if (_initialized) {
      return;
    }
    _initialized = true;
    _nameController.text = category.name;
    _kind = category.kind;
    _icon = category.icon;
    _color = category.color;
  }

  Widget _buildForm() {
    final FinancialCategoryActionState action = ref.watch(
      financialCategoryActionControllerProvider,
    );
    return _withSafeBack(
      Scaffold(
        appBar: AppBar(
          leading: const SafeBackButton(fallbackLocation: AppRoutes.categories),
          title: Text(_isEditing ? 'Editar categoria' : 'Nova categoria'),
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
                        maxLength: FinancialCategoryName.maximumLength,
                        decoration: const InputDecoration(
                          labelText: 'Nome da categoria',
                          helperText: 'Use um nome fácil de reconhecer.',
                        ),
                        validator: (String? value) =>
                            FinancialCategoryName.validate(value ?? ''),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      CategoryKindSelector(
                        value: _kind,
                        enabled: !_isEditing && !action.isLoading,
                        onChanged: (FinancialCategoryKind value) {
                          setState(() => _kind = value);
                        },
                      ),
                      if (_isEditing) ...<Widget>[
                        const SizedBox(height: AppSpacing.xs),
                        const Text(
                          'O tipo não pode ser alterado depois da criação.',
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      CategoryIconSelector(
                        value: _icon,
                        onChanged: (FinancialCategoryIcon value) {
                          setState(() => _icon = value);
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      CategoryColorSelector(
                        value: _color,
                        onChanged: (FinancialCategoryColor value) {
                          setState(() => _color = value);
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
                                      FinancialCategoryActionStatus.failure
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
                                    : 'Criar categoria',
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
    final FinancialCategoryDraft draft = FinancialCategoryDraft(
      name: _nameController.text,
      kind: _kind,
      icon: _icon,
      color: _color,
    );
    final FinancialCategoryActionController controller = ref.read(
      financialCategoryActionControllerProvider.notifier,
    );
    if (_isEditing) {
      controller.updateCategory(categoryId: widget.categoryId!, draft: draft);
    } else {
      controller.create(draft);
    }
  }

  Widget _loadingScaffold() => _withSafeBack(
    Scaffold(
      appBar: AppBar(
        leading: const SafeBackButton(fallbackLocation: AppRoutes.categories),
        title: Text(_isEditing ? 'Editar categoria' : 'Nova categoria'),
      ),
      body: const Center(
        child: CircularProgressIndicator(
          semanticsLabel: 'Carregando categoria',
        ),
      ),
    ),
  );

  Widget _errorScaffold(String message) => _withSafeBack(
    Scaffold(
      appBar: AppBar(
        leading: const SafeBackButton(fallbackLocation: AppRoutes.categories),
        title: const Text('Editar categoria'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(message, textAlign: TextAlign.center),
        ),
      ),
    ),
  );

  Widget _withSafeBack(Widget child) =>
      SafeBackScope(fallbackLocation: AppRoutes.categories, child: child);
}
