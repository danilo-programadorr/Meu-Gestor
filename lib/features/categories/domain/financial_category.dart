import 'package:meu_gestor_financeiro/core/errors/app_exception.dart';

enum FinancialCategoryKind {
  income('Receita'),
  expense('Despesa');

  const FinancialCategoryKind(this.label);

  final String label;

  static FinancialCategoryKind fromStorage(String value) =>
      FinancialCategoryKind.values.firstWhere(
        (FinancialCategoryKind kind) => kind.name == value,
        orElse: () => throw const FormatException('invalid_category_kind'),
      );
}

enum FinancialCategoryIcon {
  salary('Salário'),
  extraIncome('Renda extra'),
  sale('Venda'),
  refund('Reembolso'),
  food('Alimentação'),
  home('Moradia'),
  transport('Transporte'),
  health('Saúde'),
  education('Educação'),
  leisure('Lazer'),
  subscription('Assinatura'),
  shopping('Compras'),
  bill('Conta'),
  other('Outro');

  const FinancialCategoryIcon(this.label);

  final String label;

  static FinancialCategoryIcon fromStorage(String value) =>
      FinancialCategoryIcon.values.firstWhere(
        (FinancialCategoryIcon icon) => icon.name == value,
        orElse: () => throw const FormatException('invalid_category_icon'),
      );
}

enum FinancialCategoryColor {
  cyan('Ciano'),
  blue('Azul'),
  green('Verde'),
  purple('Roxo'),
  orange('Laranja'),
  pink('Rosa'),
  red('Vermelho'),
  yellow('Amarelo'),
  teal('Verde-azulado'),
  gray('Cinza');

  const FinancialCategoryColor(this.label);

  final String label;

  static FinancialCategoryColor fromStorage(String value) =>
      FinancialCategoryColor.values.firstWhere(
        (FinancialCategoryColor color) => color.name == value,
        orElse: () => throw const FormatException('invalid_category_color'),
      );
}

abstract final class FinancialCategoryName {
  static const int minimumLength = 2;
  static const int maximumLength = 40;

  static String normalize(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ');

  static String? validate(String value) {
    if (RegExp(r'[\x00-\x1F\x7F]').hasMatch(value)) {
      return 'O nome contém caracteres não permitidos.';
    }
    final String normalized = normalize(value);
    if (normalized.length < minimumLength ||
        normalized.length > maximumLength) {
      return 'Informe um nome entre 2 e 40 caracteres.';
    }
    return null;
  }

  static String requireValid(String value) {
    final String? message = validate(value);
    if (message != null) {
      throw ValidationException(
        code: 'invalid_category_name',
        message: message,
      );
    }
    return normalize(value);
  }
}

final class FinancialCategory {
  const FinancialCategory({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.kind,
    required this.icon,
    required this.color,
    required this.isArchived,
    required this.archivedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.schemaVersion,
  });

  static const int currentSchemaVersion = 1;

  final String id;
  final String ownerId;
  final String name;
  final FinancialCategoryKind kind;
  final FinancialCategoryIcon icon;
  final FinancialCategoryColor color;
  final bool isArchived;
  final DateTime? archivedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int schemaVersion;

  FinancialCategory copyWith({
    String? name,
    FinancialCategoryIcon? icon,
    FinancialCategoryColor? color,
    bool? isArchived,
    DateTime? archivedAt,
    bool clearArchivedAt = false,
    DateTime? updatedAt,
  }) => FinancialCategory(
    id: id,
    ownerId: ownerId,
    name: name ?? this.name,
    kind: kind,
    icon: icon ?? this.icon,
    color: color ?? this.color,
    isArchived: isArchived ?? this.isArchived,
    archivedAt: clearArchivedAt ? null : archivedAt ?? this.archivedAt,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    schemaVersion: schemaVersion,
  );

  static void validate(FinancialCategory category) {
    if (category.id.isEmpty ||
        category.ownerId.isEmpty ||
        FinancialCategoryName.requireValid(category.name) != category.name ||
        category.schemaVersion != currentSchemaVersion ||
        category.isArchived != (category.archivedAt != null)) {
      throw const FormatException('invalid_financial_category');
    }
  }
}

final class FinancialCategoryDraft {
  const FinancialCategoryDraft({
    required this.name,
    required this.kind,
    required this.icon,
    required this.color,
  });

  final String name;
  final FinancialCategoryKind kind;
  final FinancialCategoryIcon icon;
  final FinancialCategoryColor color;

  FinancialCategoryDraft normalized() => FinancialCategoryDraft(
    name: FinancialCategoryName.requireValid(name),
    kind: kind,
    icon: icon,
    color: color,
  );
}
