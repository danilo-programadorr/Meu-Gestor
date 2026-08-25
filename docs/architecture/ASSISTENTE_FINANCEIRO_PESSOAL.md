# Assistente Financeiro Pessoal — arquitetura ASSIST-0

## Estado do incremento

ASSIST-0 implementa somente domínio, contrato local server-side neutro, políticas e testes. Não há tela, provider de estado, Function, API de IA, segredo, memória persistida, coleção nova, regra publicada ou chamada externa.

## Fluxo seguro futuro

1. O aplicativo envia apenas uma pergunta previamente validada.
2. A borda server-side exige Auth, App Check, e-mail verificado, perfil jurídico atual e consentimento de IA vigente confirmado pelo servidor.
3. O servidor usa exclusivamente o UID do token e monta um snapshot confirmado, sem escrita pendente.
4. O montador converte documentos em fatos mínimos tipados, agrega quando possível e troca IDs persistidos por aliases efêmeros.
5. O provedor recebe pergunta, contexto estruturado, fontes ausentes e esquema de resposta. Não recebe UID, e-mail, nome, token, segredo ou capacidade de escrita.
6. A resposta só é aceita se cada afirmação factual citar evidências do snapshot e toda ação mutável estiver marcada como proposta que exige confirmação.

## Inventário de contexto

| Fonte | Situação | Conteúdo aprovado |
|---|---|---|
| perfil/configuração | disponível | locale, moeda, fuso e preferências estritamente necessárias; nunca identidade |
| contas | disponível | tipo, estado, inclusão no total e saldos derivados em centavos |
| categorias | disponível | nomes seguros, tipo e estado; sem ID persistido |
| lançamentos | disponível | tipo, data civil, valor, categoria/conta por alias e estado |
| contas a pagar/receber | disponível | vencimento, valor, estado, atraso derivado e vínculo por alias |
| carteiras, ativos e operações | disponível | classe, ticker público, quantidade/preços escalados, custo e resultado derivados |
| proventos | disponível | tipo, competência, estado, bruto/imposto/líquido em inteiros |
| cotações atrasadas | referência global | ticker público, preço escalado, horário, atraso e qualidade da fonte |
| dashboard e rentabilidade | derivada | agregados reproduzíveis, cobertura e lacunas |
| dívidas/juros, orçamentos, metas/reserva, projeção e histórico | indisponível | declarar ausência; nunca inventar ou inferir como fato |

Entitlement, cobrança, concessão de teste, owner, operações de privacidade, locks, recibos, diretórios internos, dados de Auth, logs e configuração backend nunca compõem contexto financeiro.

## Consentimento e memória

- IA continua opcional e independente de Analytics.
- O consentimento precisa registrar versão e horário de servidor. Cache ou escrita pendente não autoriza envio.
- Retirar consentimento interrompe novas análises e aciona exclusão futura de memória/resultado retido.
- O modo padrão e único no ASSIST-0 é sem memória. A conversa não é persistida pelo contrato.
- Resumo persistente futuro terá consentimento próprio, finalidade visível, edição/exclusão e retenção máxima de 90 dias; prompt bruto não será memória.
- Reset financeiro invalida qualquer memória financeira; exclusão da conta remove tudo que ainda estiver vinculado ao usuário.

## Fontes e explicabilidade

Cada fato recebe um `evidenceId` efêmero e uma fonte conhecida. A resposta não pode introduzir fatos sem evidência. Horários são UTC no transporte e datas civis seguem `America/Sao_Paulo`. Dinheiro usa centavos BRL; valores escalados nunca usam ponto flutuante.

O texto final deve distinguir fato confirmado, cálculo determinístico, estimativa, hipótese e dado ausente. Cotações são informativas e atrasadas. Nenhuma saída constitui recomendação de comprar, vender ou manter.

## Ações e experiência

Leitura, explicação, comparação, pergunta e sugestão não alteram dados. Criar, editar, arquivar, cancelar, anular ou excluir pode no máximo produzir uma prévia. Um executor futuro, separado do provedor, exigirá confirmação explícita da prévia exata, expiração curta, UID próprio, revisão/idempotência e todas as invariantes do módulo afetado.

Reset financeiro, exclusão de conta, autenticação, assinatura, owner, segurança e administração não são delegáveis ao assistente. Falha da IA nunca bloqueia o núcleo financeiro. Mensagens de erro não exibem dados financeiros ou técnicos.

## Bloqueios para um incremento conectado

- escolha e análise contratual do provedor;
- base legal/texto final de consentimento e política de privacidade;
- Function com IAM mínimo, App Check, rate limit, timeout, orçamento e observabilidade sanitizada;
- política técnica de exclusão no provedor e avaliação de retenção zero;
- testes adversariais, qualidade financeira e comportamento em indisponibilidade;
- autorização específica para qualquer Rule, segredo, recurso externo ou deploy.
