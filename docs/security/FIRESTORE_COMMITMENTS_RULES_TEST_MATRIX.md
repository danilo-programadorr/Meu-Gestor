# Matriz local de regras — FIN-5A compromissos

## Ambiente autorizado

- Project ID exclusivo: `demo-meu-gestor-financeiro`;
- somente Firestore Emulator em `127.0.0.1:8080`;
- autenticação simulada por `@firebase/rules-unit-testing`;
- sem `.firebaserc`, login, projeto real, dados reais ou deploy;
- Firebase CLI apenas por `emulators:exec`, que inicia e encerra o processo local.

## Cobertura automatizada

| Grupo | Casos |
|---|---|
| Autorização | UID próprio, UID cruzado, não autenticado e e-mail não confirmado |
| Esquema | criação válida em payables/receivables, campo ausente, campo extra e referências inválidas |
| Liquidação | confirmação atômica válida, metade sem lançamento, lançamento órfão e vínculo bidirecional |
| Divergências | valor, categoria, conta, data de movimento, tipo e origem |
| Idempotência | repetição negada nas regras e duas confirmações concorrentes com um vencedor |
| Histórico | pending para cancelled, paid/received para voided, restaurações e exclusões negadas |
| Lançamento vinculado | edição e anulação isoladas negadas; anulação conjunta permitida |
| Compatibilidade | esquema 1 manual legível/editável/anulável e esquema 2 manual funcional |
| Regressão | perfil, contas, categorias, transactions e acesso owner mantidos protegidos |

Comando local:

```powershell
$env:JAVA_HOME = 'D:\android\jbr'
$env:PATH = "D:\android\jbr\bin;$env:PATH"
npm run test:rules
npm run test:rules:log
```

As variáveis acima valem apenas para o processo atual. O comando não instala nem altera Java no sistema.

## Endurecimento FIN-5A-2B

O limite de 1.000 expressões era alcançado nos cenários negativos de liquidação e anulação porque a regra genérica de atualização avaliava alternativas incompatíveis em sequência e repetia autenticação, perfil, referências e vínculos. O endurecimento separa caminhos payable/receivable, escolhe estado e origem de forma determinística, centraliza o portão financeiro e consulta cada documento relacionado somente no ramo aplicável.

`audit-emulator-log.mjs` falha a validação local se o log registrar limite de expressões, avaliação interrompida, erro de valor nulo, excesso de leituras das regras ou falha interna do Emulator. Negações esperadas continuam aparecendo como `PERMISSION_DENIED` e fazem parte dos testes negativos.
