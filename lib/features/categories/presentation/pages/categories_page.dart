import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_gestor_financeiro/app/routing/app_routes.dart';
import 'package:meu_gestor_financeiro/app/routing/safe_back_navigation.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
import 'package:meu_gestor_financeiro/features/categories/domain/financial_category.dart';
import 'package:meu_gestor_financeiro/features/categories/presentation/controllers/financial_categories_controller.dart';
import 'package:meu_gestor_financeiro/features/categories/presentation/controllers/financial_category_action_controller.dart';
import 'package:meu_gestor_financeiro/features/categories/presentation/widgets/category_card.dart';
import 'package:meu_gestor_financeiro/features/categories/presentation/widgets/category_visuals.dart';

class CategoriesPage extends ConsumerWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<FinancialCategoryActionState>(
      financialCategoryActionControllerProvider,
      (
        FinancialCategoryActionState? previous,
        FinancialCategoryActionState next,
      ) {
        if (previous?.status != next.status && next.message != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(next.message!)));
            }
          });
        }
      },
    );
    final AsyncValue<FinancialCategoriesState> categories = ref.watch(
      financialCategoriesControllerProvider,
    );
    return SafeBackScope(
      fallbackLocation: AppRoutes.home,
      child: Scaffold(
        appBar: AppBar(
          leading: const SafeBackButton(fallbackLocation: AppRoutes.home),
          title: const Text('Categorias'),
          actions: <Widget>[
            IconButton(
              tooltip: 'Categorias arquivadas',
              onPressed: () => context.push(AppRoutes.archivedCategories),
              icon: const Icon(Icons.archive_outlined),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push(AppRoutes.newCategory),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Adicionar categoria'),
        ),
        body: SafeArea(
          child: categories.when(
            loading: () => const Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Carregando categorias',
              ),
            ),
            error: (Object error, StackTrace stackTrace) => _CategoriesError(
              message: safeCategoriesErrorMessage(error),
              onRetry: ref
                  .read(financialCategoriesControllerProvider.notifier)
                  .refresh,
            ),
            data: (FinancialCategoriesState state) => RefreshIndicator(
              onRefresh: ref
                  .read(financialCategoriesControllerProvider.notifier)
                  .refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  104,
                ),
                children: <Widget>[
                  const Row(
                    children: <Widget>[
                      Icon(Icons.cloud_done_outlined, size: 18),
                      SizedBox(width: AppSpacing.xs),
                      Expanded(child: Text('Lista confirmada pelo servidor')),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (state.activeCategories.isEmpty)
                    const _EmptyCategories()
                  else ...<Widget>[
                    _CategorySection(
                      title: 'Receitas',
                      categories: state.activeByKind(
                        FinancialCategoryKind.income,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _CategorySection(
                      title: 'Despesas',
                      categories: state.activeByKind(
                        FinancialCategoryKind.expense,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  OutlinedButton.icon(
                    onPressed: () => context.push(AppRoutes.archivedCategories),
                    icon: const Icon(Icons.archive_outlined),
                    label: Text(
                      'Categorias arquivadas (${state.archivedCategories.length})',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategorySection extends ConsumerWidget {
  const _CategorySection({required this.title, required this.categories});

  final String title;
  final List<FinancialCategory> categories;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: AppSpacing.sm),
      if (categories.isEmpty)
        Text('Nenhuma categoria de ${title.toLowerCase()} cadastrada.')
      else
        for (final FinancialCategory category in categories)
          CategoryCard(
            category: category,
            onEdit: () => context.push(AppRoutes.editCategory(category.id)),
            onArchive: () => _confirmArchive(context, ref, category),
            actionsEnabled: !ref
                .watch(financialCategoryActionControllerProvider)
                .isLoading,
          ),
    ],
  );

  Future<void> _confirmArchive(
    BuildContext context,
    WidgetRef ref,
    FinancialCategory category,
  ) async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('Arquivar esta categoria?'),
            content: const Text(
              'Ela não ficará disponível para novos lançamentos. '
              'Os lançamentos antigos continuarão preservados e a categoria poderá ser restaurada.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Arquivar'),
              ),
            ],
          ),
        ) ??
        false;
    if (confirmed) {
      await ref
          .read(financialCategoryActionControllerProvider.notifier)
          .setArchived(categoryId: category.id, archived: true);
    }
  }
}

class _EmptyCategories extends StatelessWidget {
  const _EmptyCategories();

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: <Widget>[
          const Icon(
            Icons.category_outlined,
            size: 56,
            semanticLabel: 'Nenhuma categoria cadastrada',
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Você ainda não criou categorias.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Crie categorias de receita e despesa para organizar seus lançamentos.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: () => context.push(AppRoutes.newCategory),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Adicionar categoria'),
          ),
        ],
      ),
    ),
  );
}

class _CategoriesError extends StatelessWidget {
  const _CategoriesError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.cloud_off_outlined, size: 56),
          const SizedBox(height: AppSpacing.md),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Tentar novamente'),
          ),
        ],
      ),
    ),
  );
}
