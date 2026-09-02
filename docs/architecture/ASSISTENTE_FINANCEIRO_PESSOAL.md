# Assistente Financeiro Pessoal — arquitetura ASSIST-0 a ASSIST-VOICE-1A

## Estado do incremento

ASSIST-0 implementa domínio, contrato server-side neutro, políticas e testes. O ASSIST-1A acrescenta interface local, consentimento visível, quatro perguntas guiadas e resumos determinísticos. O ASSIST-1B-0 compara provedores somente por documentação oficial. ASSIST-1B-1A prepara tiers lógicos e ASSIST-VOICE-1A acrescenta leitura pelo sintetizador nativo. ASSIST-2A executou uma prova técnica sintética controlada em development, sem integrar IA ao aplicativo. Nenhum fornecedor foi selecionado; não há Function, API de IA no aplicativo, segredo versionado, memória persistida, coleção nova ou regra publicada.

ASSIST-VOICE-2A-R1 concentra o núcleo visual no eixo da conversa, mantendo estados e transcrição na área inferior segura. A pulsação continua respeitando reduzir animações; há dez partículas discretas no total e nenhuma informação depende apenas de cor ou movimento.

ASSIST-VOICE-2A acrescenta uma rota de conversa local. Após explicação e ação explícita, ela usa somente o reconhecedor configurado no Android e mantém a transcrição na memória da tela. Não grava, salva, envia ou observa áudio em segundo plano. Saída, bloqueio, perda de foco, troca de conta ou privacidade financeira interrompem reconhecimento e TTS e descartam a transcrição. O texto reconhecido é mapeado exclusivamente às quatro perguntas determinísticas; ausência de mapeamento ou evidência não gera conversa inventada nem ação financeira.

## Roteamento neutro ASSIST-1B-1A

- `flash` é o tier lógico padrão para conversa e explicações comuns;
- `pro` só é escolhido no backend quando há ao menos dois sinais fechados de complexidade e limites de contexto, chamadas e custo disponíveis;
- o request público aceita apenas a pergunta, portanto o usuário não escolhe modelo nem injeta contexto;
- unidades de custo são guardrails abstratos e não simulam preço de provedor;
- limites excedidos falham antes do gateway; análise complexa não é rebaixada silenciosamente;
- o gateway desta etapa permanece fake, sem endpoint, SDK, chave ou resposta real de IA.

## Barreira e plano dual ASSIST-2A

- Uma única barreira fail-closed é aplicada antes de devolver toda resposta de gateway, independentemente de Flash ou Pro.
- Recomendações de compra, venda ou alocação, mutações financeiras, calendário, conta, investimento, segredos, dados de terceiros, fonte inválida e número sem fato confirmado retornam resposta segura determinística.
- Com privacidade financeira ativa, qualquer número é bloqueado antes da entrega.
- O plano dual mantém Flash como padrão lógico e Pro somente após escalonamento do backend. A feature flag de provedor real permanece desligada; o fallback é `safe_unavailable`, nunca uma chamada automática ou seletor do usuário.

## Preparação de ativação ASSIST-2B-0

- A fronteira Flutter aceita apenas a mensagem sanitizada e a versão `assist-remote-v1`; nunca transporta UID, e-mail, consentimento, fatos, valores, modelo, tokens ou credenciais.
- A decisão de Flash/Pro é calculada no backend após autorização, consentimento e contexto confirmado. O plano local contém apenas tier e limites, sem mensagem, fato ou pedido ao provedor.
- O kill switch inicia ativo e a flag de chamada real está compilada como `false`. O repositório Flutter falha fechado e não possui gateway, portanto não pode iniciar uma chamada de IA.
- A lista exata de recursos e aprovações necessários para development está na [ADR-040](../adr/ADR-040-assist-2b-0-ativacao-segura-local.md). Nenhuma ação externa é autorizada por esta preparação local.

## Controle persistente ASSIST-2C

- O ledger de custo não armazena contexto, identidade, mensagem, resposta, áudio, ticker ou valor financeiro: somente `requestId` aleatório, tier, duração, custo reservado, custo confirmado e estado.
- Uma reserva transacional precede qualquer chamada futura. Ela aplica teto diário de R$ 5,00 e operacional mensal de R$ 45,00 em centavos inteiros; inconsistência, ausência de reserva e repetição conflitante falham fechadas.
- A repetição idempotente do mesmo `requestId` retorna o mesmo registro. Capacidade não usada só é liberada após custo medido e confirmado; uma chamada sem confirmação permanece reservada.
- A futura persistência fica em banco Firestore nomeado, isolado do banco padrão e sem acesso de cliente. Alertas de orçamento observam gasto, mas não substituem este bloqueio interno.

## Callable local ASSIST-2D-0

- A factory compatível com callable Gen 2 recebe `onCall` por injeção e não registra codebase, Function ou endpoint. O contrato público aceita somente versão e mensagem sanitizada; campos de contexto, UID, e-mail, modelo, custo e instruções são negados.
- Auth, e-mail verificado, App Check, perfil jurídico e consentimento são revalidados server-side. Privacidade financeira ativa interrompe o fluxo antes de qualquer leitura de contexto.
- O roteador interno decide Flash ou Pro, mas a resposta não revela tier ou modelo. Kill switch obrigatório e flag do provedor compilada como falsa retornam somente `safe_unavailable`; a porta do ledger é validada, nunca chamada.

## Registro Gen 2 local ASSIST-2E-0

- `assistRemoteV1` é o único nome de export futuro. O registro injetável fixa `southamerica-east1`, 256 MiB, 30 segundos, concorrência 1, mínimo 0, máximo 1 e App Check obrigatório.
- Não há codebase configurado, SDK Vertex, URL, projeto, identidade runtime ou composição Firebase real. O Flutter continua sem gateway; a futura ligação de `onCall` exigirá aprovação própria.

## Codebase Functions local ASSIST-2F-0

- A embalagem implantável fica isolada em `backend/functions/assistant`, usa Node 22 e exporta somente `assistRemoteV1`.
- A dependência direta única é `firebase-functions` 7.3.2. O contrato puro é copiado somente no predeploy, sem duplicar decisões de domínio.
- `ASSISTANT_RUNTIME_SERVICE_ACCOUNT` é um parâmetro obrigatório sem valor no Git. Não há Firebase Admin, cliente Firestore, Vertex, Secret Manager ou URL externa no artefato.
- Enquanto o provedor real permanece desligado, Auth/e-mail/App Check são validados e a resposta é `safe_unavailable` antes de qualquer porta de perfil, contexto, uso ou ledger. Assim não há acesso ao banco padrão, ao banco nomeado ou a dados financeiros.

## Voz local ASSIST-VOICE-1A

- a opção aparece antes de `Consultar`, começa desligada e não substitui a resposta textual;
- o adaptador `AssistantTtsEngine` isola `flutter_tts` e permite testes sem canal de plataforma;
- idioma `pt-BR`, velocidade lenta/normal/rápida e controles pausar, continuar, repetir e parar;
- privacidade financeira oculta interrompe a voz e descarta o conteúdo repetível;
- saída da tela, suspensão/bloqueio e troca de conta interrompem o mecanismo;
- não há microfone, gravação, memória de voz, arquivo de áudio nem nuvem;
- voz ausente ou falha nativa produz mensagem segura e conserva a leitura visual.

## Auditoria ASSIST-1B-0

A comparação atual de privacidade, retenção, uso de dados, custos, português, saídas estruturadas, ferramentas e controles de gasto está em [ASSISTENTE_PROVEDORES_IA.md](ASSISTENTE_PROVEDORES_IA.md). A recomendação define apenas uma ordem futura de avaliação com dados sintéticos; o contrato continua neutro e nenhum fornecedor foi escolhido.

## Prova técnica ASSIST-2A

O benchmark limitado está registrado na [ADR-039](../adr/ADR-039-assist-2a-benchmark-vertex-sintetico.md). Ele usou somente fixtures sintéticas e endpoint global, bloqueou áudio, imagem, grounding, cache, ferramentas e streaming, e reteve apenas métricas agregadas. Nenhum prompt, resposta, dado financeiro ou identificador de usuário foi persistido. O resultado não seleciona modelo ou fornecedor e não habilita envio de contexto pelo aplicativo.

## Experiência local ASSIST-1A

- A rota `/assistente` fica no grupo Assistência do menu da Home.
- Antes do consentimento, a tela apresenta escopo e proteção, mas não observa providers financeiros.
- As perguntas disponíveis consultam resumo do mês, saldo atual, compromissos e investimentos cadastrados.
- Cada resposta exibe período civil, fontes confirmadas e indisponibilidade sem preencher lacunas.
- O resumo de investimentos usa somente custo, resultado realizado e proventos manuais; não simula cotação ou rentabilidade.
- A privacidade global oculta cifras e contagens. Não há texto livre, recomendação, memória ou ação mutável.
- O consentimento atual vale somente para leitura local. Envio futuro a provedor exige política versionada e autorização próprias.

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

Leitura, explicação, comparação, pergunta e sugestão não alteram dados. Criar, editar, arquivar, cancelar, anular, excluir ou propor lembrete pode no máximo produzir uma prévia. Um executor futuro, separado do provedor, exigirá confirmação explícita da prévia exata, expiração curta, UID próprio, revisão/idempotência e todas as invariantes do módulo afetado. Em particular, uma proposta de lembrete não paga, recebe, conclui nem altera compromisso financeiro.

Reset financeiro, exclusão de conta, autenticação, assinatura, owner, segurança e administração não são delegáveis ao assistente. Falha da IA nunca bloqueia o núcleo financeiro. Mensagens de erro não exibem dados financeiros ou técnicos.

## Bloqueios para um incremento conectado

- benchmark sintético e escolha explícita do provedor após a auditoria ASSIST-1B-0;
- base legal/texto final de consentimento e política de privacidade;
- Function com IAM mínimo, App Check, rate limit, timeout, orçamento e observabilidade sanitizada;
- política técnica de exclusão no provedor e avaliação de retenção zero;
- testes adversariais, qualidade financeira e comportamento em indisponibilidade;
- autorização específica para qualquer Rule, segredo, recurso externo ou deploy.
