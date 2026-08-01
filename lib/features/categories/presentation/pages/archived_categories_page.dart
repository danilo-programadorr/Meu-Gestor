import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_gestor_financeiro/app/routing/app_routes.dart';
import 'package:meu_gestor_financeiro/app/routing/safe_back_navigation.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';
import 'package:meu_gestor_financeiro/features/categories/domain/financial_category.dart';
import 'package:meu_gestor_financeiro/features/categories/presentation/controllers/financial_categories_controller.dart';
import 'package:meu_gestor_financeiro/features/categories/presentation/controllers/financial_category_action_controller.dart';
import 'package:meu_gestor_financeiro/features/categories/presentation/widgets/category_visuals.dart';

class ArchivedCategoriesPage extends ConsumerWidget {
  const ArchivedCategoriesPage({super.key});

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
      fallbackLocation: AppRoutes.categories,
      child: Scaffold(
        appBar: AppBar(
          leading: const SafeBackButton(fallbackLocation: AppRoutes.categories),
          title: const Text('Categorias arquivadas'),
        ),
        body: SafeArea(
          child: categories.when(
            loading: () => const Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Carregando categorias arquivadas',
              ),
            ),
            error: (Object error, StackTrace stackTrace) => Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      safeCategoriesErrorMessage(error),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton(
                      onPressed: ref
                          .read(financialCategoriesControllerProvider.notifier)
                          .refresh,
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            ),
            data: (FinancialCategoriesState state) {
              if (state.archivedCategories.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: Text(
                      'Você não possui categorias arquivadas.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: state.archivedCategories.length,
                itemBuilder: (BuildContext context, int index) {
                  final FinancialCategory category =
                      state.archivedCategories[index];
                  return Card(
                    child: ListTile(
                      leading: Icon(categoryIconData(category.icon)),
                      title: Text(category.name),
                      subtitle: Text(category.kind.label),
                      trailing: TextButton.icon(
                        onPressed:
                            ref
                                .watch(
                                  financialCategoryActionControllerProvider,
                                )
                                .isLoading
                            ? null
                            : () => ref
                                  .read(
                                    financialCategoryActionControllerProvider
                                        .notifier,
                                  )
                                  .setArchived(
                                    categoryId: category.id,
                                    archived: false,
                                  ),
                        icon: const Icon(Icons.unarchive_outlined),
                        label: const Text('Restaurar'),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
