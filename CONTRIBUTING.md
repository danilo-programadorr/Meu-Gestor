# Como contribuir

Obrigado pelo interesse em contribuir com o Meu Gestor Financeiro. O projeto trata informações financeiras como sensíveis e exige mudanças pequenas, verificáveis e compatíveis com a especificação.

## Ambiente

Use Flutter 3.41.1, Dart 3.11.0, Android SDK e Java 21. A configuração Firebase deve pertencer ao próprio desenvolvedor e permanecer somente em `android/app/google-services.json`, que é ignorado pelo Git.

```powershell
flutter pub get
flutter analyze
flutter test
```

## Branches

Crie branches curtas a partir de `main`:

- `feat/nome-da-funcionalidade`;
- `fix/descricao-da-correcao`;
- `docs/assunto`;
- `test/assunto`;
- `chore/assunto`.

Não misture funcionalidades independentes na mesma branch.

## Commits

Prefira mensagens no padrão Conventional Commits:

```text
feat: adiciona comportamento concluído
fix: corrige falha específica
docs: atualiza documentação pública
test: amplia cobertura de autenticação
```

Commits não devem conter código incompleto, segredos, credenciais, dados pessoais, APKs, caches ou configurações Firebase locais.

## Qualidade obrigatória

Antes de abrir uma pull request, execute:

```powershell
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

Inclua testes proporcionais ao risco da mudança. Não remova testes para ocultar falhas e não ignore advertências sem justificativa técnica documentada.

## Arquitetura e segurança

- preserve as camadas `presentation`, aplicação/controllers, domínio e dados;
- mantenha tipos Firebase fora das entidades de domínio;
- nunca represente dinheiro com ponto flutuante;
- não acesse Firestore diretamente por widgets;
- não registre e-mail, valores financeiros, tokens ou credenciais;
- não inclua `google-services.json`, arquivos `.env` reais ou material de assinatura;
- não ative serviço externo, faturamento ou telemetria por meio de uma pull request.

## Pull requests

Antes do envio:

1. revise todos os arquivos modificados;
2. confirme que a mudança corresponde a um requisito aprovado;
3. descreva comportamento, testes e riscos;
4. verifique que a documentação continua verdadeira;
5. aguarde revisão antes de fazer merge.

Use o template de pull request e não publique dados sensíveis em discussões ou evidências.
