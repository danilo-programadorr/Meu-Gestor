import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_gestor_financeiro/core/errors/app_exception.dart';

enum AppEnvironment {
  development,
  production;

  static const String developmentValue = 'development';
  static const String productionValue = 'production';

  static AppEnvironment fromDefine(String value) {
    return switch (value) {
      developmentValue => development,
      productionValue => production,
      _ => throw ConfigurationException(
        code: 'invalid_environment',
        message: 'Ambiente de execução inválido.',
      ),
    };
  }
}

final Provider<AppEnvironment> appEnvironmentProvider =
    Provider<AppEnvironment>(
      (Ref ref) => throw const ConfigurationException(
        code: 'environment_not_initialized',
        message: 'O ambiente de execução não foi inicializado.',
      ),
    );
