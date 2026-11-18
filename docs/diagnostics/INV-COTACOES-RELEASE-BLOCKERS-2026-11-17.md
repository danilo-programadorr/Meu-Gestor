# INV-COTACOES-RECOVERY-1 — pré-publicação em 17/11/2026

## Preparação

- Main local e remota conferidas em
  `9fe7fd3a69a537f9e67953b7028e64c676a48547`.
- Worktree gerenciada criada pelo aplicativo após consentimento do proprietário.
- Copiados somente os quatro arquivos de código/teste de cotações, o plano de
  ativação e o diagnóstico anterior. Do plano de desenvolvimento foi transferida
  apenas a seção 43.4; mudanças SEC-1/social/lockfiles ficaram na origem.
- Os seis arquivos copiados tiveram hashes comparados com a origem. Os originais
  foram preservados. Nenhum commit, push, deploy ou APK foi executado.
- Registros automáticos existentes de 17/11 mostraram HTTP 200 e marcadores de
  conclusão na revisão `refreshdelayedmarketquotes-00005-lec`, inclusive às
  18:30 de Brasília com duração 3,734637821 s. Não houve disparo manual BRAPI.

## Gate impeditivo: Premium no artefato instalado

A auditoria do lockfile foi tratada apenas como indício. Para conferir o gate,
os manifests de Premium do SHA base foram extraídos para uma pasta temporária
ignorada, sem código de negócio, credenciais ou dependências da cópia de trabalho.

Foram usados Node 22 portátil e instalação reproduzível com:

```text
npm ci --omit=dev --omit=optional --ignore-scripts --no-audit --no-fund
npm audit --omit=dev --omit=optional --audit-level=moderate --json
```

A instalação terminou com código zero e preservou o hash do lockfile:
`544307F1C74D5FE07B396AECE670D3A31F4049237910EC961583E4E7591B7440`.
A auditoria, equivalente ao comando de `audit:production-artifact` com saída
estruturada, terminou com código 1: um alerta alto e cinco moderados. Portanto,
não são alertas de dependências opcionais ausentes do artefato.

| Pacote resolvido | Versão | Classe do alerta |
|---|---|---|
| body-parser | 2.3.0 | alto, advisory direto |
| qs | 6.16.0 | moderado, advisory direto |
| google-gax | 5.0.8 | moderado, cadeia transitiva |
| rimraf | 5.0.10 | moderado, cadeia transitiva |
| glob | 10.5.0 | moderado, advisory direto e transitivo |
| minimatch | 9.0.9 | moderado, advisory direto |

O código de negócio e a superfície de exploração de cada advisory não foram
avaliados nesta preparação. O resultado é bloqueio do gate existente, não prova
de exploração, incidente ou vulnerabilidade alcançável pela Function de cotações.

## Por que não é uma atualização patch do lockfile

- `body-parser 2.4.0` e `qs 6.16.1` corrigem os respectivos advisories e já têm
  uma alteração local anterior, separada deste incremento.
- A cadeia instalada é `@google-cloud/firestore 8.7.1 → google-gax 5.0.8 →
  rimraf 5.0.10 → glob 10.5.0 → minimatch 9.0.9`.
- `google-gax` exige `rimraf ^5.0.1`; `rimraf` exige `glob ^10.3.7`; `glob`
  exige `minimatch ^9.0.4`.
- Os advisories consultados informam correções em `glob 14.0.2` e
  `minimatch 11.0.1`, fora dessas faixas. Metadados oficiais conferidos não
  mostraram patch posterior nas linhas atuais de google-gax 5.0 e rimraf 5.0.
- A linha Firestore 8 termina em 8.7.1 nos metadados consultados e exige gax 5.
  O primeiro Firestore encontrado com gax 6 é 9.0.1 (`^6.0.1`). Gax 6.0.0
  remove a dependência direta de rimraf e exige Node >=22. Isso indica uma
  migração de major a avaliar, não uma correção comprovada ou já autorizada.
- Firebase Admin 14.2.0 exige Firestore `^8.6.0` no lockfile conferido.
  É necessário verificar sua compatibilidade antes de definir uma migração:
  atualizar apenas a dependência direta pode conservar uma segunda cópia da
  cadeia antiga. Nenhuma migração foi tentada.

Fontes primárias: [body-parser](https://github.com/advisories/GHSA-27r3-jxmh-p828),
[qs](https://github.com/advisories/GHSA-6pq8-jhm2-2vcw),
[glob](https://github.com/advisories/GHSA-3g3m-2fjr-6pw4),
[minimatch](https://github.com/advisories/GHSA-g3hv-75wg-m249);
metadados públicos de `registry.npmjs.org` para os pacotes e seus pais.

## Decisão pendente

Abrir um incremento de dependências separado para avaliar a migração compatível
de Firestore/google-gax e, se necessário, Firebase Admin, preservando Auth,
comportamento e dados. Antes de aplicar majors, apresentar o conjunto exato de
versões e riscos. Não usar force, overrides, remoção do gate ou aceitação de
risco implícita. O escopo atual exige preservar dependências.

O INV-COTACOES-RECOVERY-1 fica preparado, mas sua publicação continua impedida
até o gate obrigatório poder passar. O runtime de cotações recuperado permanece
inalterado. Não houve alteração de IAM, Rules, quotas, Assistente ou produção
nesta preparação.

## Resolução do pré-requisito em 18/11/2026

Após avaliação e autorização das versões exatas pelo proprietário, foi criado
um incremento separado, sem deploy de Premium: Admin `14.5.1`, Firestore
`9.4.1`, Functions preservado em `7.3.2`, `body-parser 2.4.0` e `qs 6.16.1`.
A árvore obrigatória deixou de conter rimraf/glob/minimatch, sem overrides,
force ou mudanças de negócio. O artefato instalado com dev/opcionais omitidos
passou na auditoria existente com zero vulnerabilidades.

- Commit exclusivo do pré-requisito: `0be126eb8eb9751c315af974f1352eb1683ba0bf`.
- Qualidade no SHA exato: execução `44372814506`, com Flutter, contratos Node,
  Premium e Emulator aprovados.
- Localmente: 65 testes de assinaturas, 19 de Premium e três do artefato
  aprovados. Cinco testes novos com Admin/Firestore reais no Emulator passaram
  duas vezes no mesmo banco, sem limpeza entre rodadas. Identificadores
  sintéticos exclusivos e pré-condições impedem reaproveitar uma concessão
  anterior; foram cobertas serialização, concorrência, idempotência, isolamento,
  falha fechada e expiração. Revisão independente não deixou achados pendentes.
- Nenhum código de negócio Premium, IAM, Rules, controle, quota ou produção
  foi alterado. O pré-requisito não demonstra funcionamento visual no aparelho.

A publicação do reparo de cotações pode retomar seu gate próprio, sem misturar
os dois commits. A validação local do empacotador de cotações deve usar caminho
sem ponto: o filtro preexistente do script de preparação considera o caminho
inteiro e omite contratos sob o ancestral `.codex`. A mesma fonte foi copiada
com conferência de hashes para uma pasta temporária compatível, sem mudar o
empacotador, o workflow ou os contratos para contornar uma validação.
