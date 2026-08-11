# ADR-021 — SUB-1C enforcement Premium local

## Status

Aceita localmente em 10/08/2026. Código, Security Rules, testes e documentação não foram publicados. Nenhum usuário do Firebase development foi bloqueado.

## Contexto

O SUB-1A definiu a política canônica de entitlement e o SUB-1B implementou o contrato de leitura confirmada e um backend de referência local. A área de investimentos ainda precisava aplicar a decisão em profundidade sem depender da interface, sem apagar patrimônio histórico e sem criar um bypass temporário para development ou owner.

## Decisão

- `InvestmentPremiumAccessController` é o coordenador único da aplicação. Ele relê `users/{uid}/entitlements/premium` do servidor, rejeita cache e escrita pendente e produz `loading`, `full`, `readOnly`, `denied` ou `confirmationError`.
- A política SUB-1A permanece a única fonte da matriz temporal. `trialing`, `active`, `gracePeriod` e `cancelled` ainda vigente permitem acesso integral; perda posterior preserva somente leitura; ausência, `pending`, documento inválido, ambiente/UID incompatível e capability ausente negam.
- `PremiumGuardedInvestmentRepository` protege leitura e todas as mutações. Controllers verificam novamente antes e depois da operação, não consomem IDs antes da autorização e descartam resposta tardia ou pertencente a sessão diferente.
- Todas as rotas de investimentos têm um gate declarativo. Formulários exigem mutação; listas e detalhes exigem leitura. O conteúdo protegido não é construído antes da confirmação.
- `investmentsManual` governa carteiras, ativos e operações. `investmentIncome` governa proventos. Uma capability nunca concede a outra.
- As Security Rules são a autoridade final. Leituras exigem entitlement integralmente válido e acesso integral ou histórico. Escritas exigem estado integral, capability e `request.time`, além de todas as invariantes já existentes.
- Documento ausente nunca é interpretado como expiração. Owner não recebe bypass e continua sem acesso cruzado.

## Preservação e experiência

Ao perder Premium, nenhum documento é escrito, arquivado ou excluído. Quantidade, custo, preço médio, resultado, proventos, contas, lançamentos, compromissos, saldo e resumo mensal permanecem intactos. A interface mantém seleção, filtros, privacidade, temas e navegação de consulta, apresenta aviso discreto e remove ações mutáveis. Falha de confirmação tem texto seguro e retry; ausência apresenta apenas informação de recurso futuro, sem preço, compra ou botão funcional de assinatura.

## Custo e segurança das regras

Leituras usam validação estrutural completa do entitlement. O caminho de mutação valida campos exatos e somente os atributos de autorização — owner, ambiente, capabilities, estado, período, revisão e esquema — porque o documento é backend-only; dados administrativos continuam validados no `get` do cliente e no mapper/backend. Duplicações no validador de transições de proventos foram removidas sem ampliar campos, estados ou transições. A suíte local confirma operações atômicas dentro do limite de 1.000 expressões e sem leituras excessivas.

## Consequências e limites

O enforcement está somente no worktree local. `firestore.rules` não foi publicado; fazê-lo antes de existir concessão development segura bloquearia usuários reais. Não há backend implantado, Google Play Billing, produto, preço, compra, restauração comercial, paywall, grant real ou entitlement real. O SUB-1D será responsável pela experiência comercial e depende de backend autoritativo, entitlements development administráveis com segurança e autorização própria para publicação.
