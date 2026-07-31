import 'package:flutter/material.dart';
import 'package:meu_gestor_financeiro/app/theme/app_spacing.dart';

enum LegalDocumentType { terms, privacy }

class LegalDocumentPage extends StatelessWidget {
  const LegalDocumentPage({required this.type, super.key});

  final LegalDocumentType type;

  @override
  Widget build(BuildContext context) {
    final bool isTerms = type == LegalDocumentType.terms;
    return Scaffold(
      appBar: AppBar(
        title: Text(isTerms ? 'Termos de Uso' : 'Política de Privacidade'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _DevelopmentNotice(),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    isTerms
                        ? 'Condições provisórias do ambiente de desenvolvimento'
                        : 'Informações provisórias de privacidade do ambiente de desenvolvimento',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    isTerms
                        ? 'Este incremento permite criar conta, autenticar, recuperar senha, confirmar email e encerrar a sessão para testes de desenvolvimento.'
                        : 'Neste incremento, os dados de conta são tratados pelo Firebase Authentication exclusivamente para autenticação. Nenhum dado financeiro é criado ou acessado.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    isTerms
                        ? 'O uso em produção e a publicação permanecem bloqueados até a aprovação dos documentos jurídicos oficiais e das configurações de produção.'
                        : 'Não estão ativos Analytics, Crashlytics, Storage, notificações, Gemini ou coleta de dados financeiros. O documento oficial deverá definir controlador, bases legais, retenção, direitos e canais de atendimento.',
                    style: Theme.of(context).textTheme.bodyLarge,
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

class _DevelopmentNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                Icons.science_outlined,
                color: Theme.of(context).colorScheme.primary,
                semanticLabel: 'Desenvolvimento',
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Texto provisório exclusivo para desenvolvimento. Não é um documento jurídico final.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
