# ADR-024 — SUB-1E-2: concessão segura de teste fechado

**Status:** aceito localmente; nenhuma concessão, regra ou recurso externo foi publicado.

## Contexto

O teste fechado da Google Play precisa de uma participação contínua mínima de catorze dias. O produto definiu uma única janela operacional fixa de quinze dias, sem cobrança, oferta Play de quinze dias, paywall ou aviso modal de expiração.

## Decisão

- `closedTestGrant` é uma origem de entitlement distinta, e não é assinatura, compra, preço, oferta comercial nem direito de production.
- Um backend futuro emite a concessão somente para um UID que esteja em sua lista autorizada, em `development`, no track fechado `closed` e dentro da janela global UTC fixa de quinze dias configurada no servidor.
- A concessão ativa contém exatamente as cinco capabilities Premium. O backend materializa a expiração com seu relógio confiável; o aplicativo não calcula quinze dias, não usa o relógio do aparelho e não escreve, restaura ou reutiliza concessões.
- O documento expirado não retém capabilities Premium. A experiência segue o fluxo comercial normal, preservando o núcleo gratuito e os dados históricos sem popup modal de expiração.
- `closedTestGrant` é inválida em production. Após o lançamento, somente entitlement verificado da Google Play poderá liberar Premium em production.
- Auditoria local contém somente ação, origem, ambiente, track, quantidade de capabilities, revisão e instante. UID, e-mail, grant ID, token e credencial não são registrados.

## Consequências

As Rules locais mantêm todas as escritas cliente negadas e só aceitam a forma de documento coerente com a concessão ativa ou expirada. A lista autorizada e a janela são configuração server-side futura; esta etapa não cria Function, App Check, Secret Manager, Firebase, Google Cloud, Play Console ou testador real.
