# Política de Privacidade — versão provisória exclusiva para desenvolvimento

Versão técnica: `privacy-dev-1.0.0`.

Este texto é um artefato técnico provisório. Não é documento jurídico final, não autoriza publicação e não deve ser usado em produção.

## Tratamento existente neste incremento

O Firebase Authentication trata os dados necessários à criação de conta e autenticação. O Firestore development armazena somente nome de exibição, locale, moeda, fuso, snapshot de verificação, versões e datas de aceite, preferências separadas de IA e Analytics, timestamps técnicos e versão do esquema. O perfil não armazena email, telefone, CPF, endereço, foto, identificadores externos, aparelho, IP ou dados financeiros.

As preferências de IA e Analytics começam desativadas e podem ser alteradas separadamente. IA, Gemini e Analytics continuam inativos; mudar a preferência não envia dados a esses serviços. `aiConsentUpdatedAt` e `analyticsConsentUpdatedAt` registram somente quando suas escolhas correspondentes foram alteradas.

O aplicativo não lê nem grava dados financeiros e não ativa Crashlytics, Storage, notificações, App Check, Cloud Functions ou Gemini nesta etapa.

Senhas, tokens, credenciais Google e conteúdo de configuração não são registrados em logs do aplicativo.

## Conteúdo ainda obrigatório

O documento oficial deverá definir controlador, finalidades, bases legais, retenção, compartilhamentos, direitos do titular, exclusão, canais de atendimento e demais obrigações aplicáveis.

## Portão de produção

O uso em produção permanece bloqueado até a revisão e aprovação da Política de Privacidade oficial e das configurações de produção.
