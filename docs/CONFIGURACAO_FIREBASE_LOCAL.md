# Configuração Firebase local

O repositório público não contém configuração Firebase, credenciais nem identificadores de projeto. Cada desenvolvedor deve usar um projeto próprio e manter os arquivos gerados exclusivamente no computador local.

## Procedimento

1. Crie um projeto Firebase de desenvolvimento sob uma conta que você controla.
2. Registre um aplicativo Android usando o `applicationId` efetivamente configurado no seu fork.
3. Cadastre as impressões SHA-1 e SHA-256 da assinatura debug usada no seu ambiente.
4. Ative somente os provedores necessários para o teste autorizado. A fundação atual utiliza e-mail/senha e Google.
5. Baixe o arquivo Android `google-services.json` fornecido pelo Firebase Console.
6. Coloque o arquivo em `android/app/google-services.json`.
7. Confirme que o arquivo continua ignorado pelo Git e nunca o publique, copie ou transcreva para documentação.
8. Execute o aplicativo em development.

```powershell
git check-ignore -v android/app/google-services.json
flutter pub get
flutter run --dart-define=APP_ENV=development
```

## Regras de segurança

- não coloque client IDs, chaves, tokens ou conteúdo do JSON no código Dart;
- não envie configuração Firebase por issue ou pull request;
- não reutilize um projeto de produção para desenvolvimento;
- não adicione `serverClientId` manualmente quando a configuração Android oficial já fornecer o cliente Web necessário;
- não habilite Firestore, Storage, Functions, Analytics, App Check ou faturamento sem avaliar regras, privacidade e custos;
- revogue e substitua qualquer credencial publicada acidentalmente.

O arquivo `.env.example` não configura Firebase e não contém valores reais.
