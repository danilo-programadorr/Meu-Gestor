# ASSIST-1B-0 — auditoria de provedores de IA

## Estado e escopo

Auditoria documental concluída em 25/08/2026, exclusivamente por leitura das fontes oficiais dos fornecedores. Nenhum provedor foi selecionado, contratado, ativado ou chamado. Nenhuma conta, chave, segredo, cobrança, API, Function, Rule ou recurso externo foi criado.

Esta comparação cobre OpenAI API, Gemini Developer API pago/Vertex AI e Anthropic API. O free tier do Gemini Developer API e o Google AI Studio não são candidatos para contexto financeiro: a tabela oficial informa que o conteúdo do free tier pode ser usado para melhorar produtos, ao contrário do paid tier.

## Comparação executiva

| Critério | OpenAI API | Gemini pago / Vertex AI | Anthropic API |
|---|---|---|---|
| Uso para treinamento | conteúdo da API não é usado para treinar por padrão, salvo opt-in | Vertex não treina nem ajusta modelos com dados do cliente sem permissão; Gemini paid tier declara que não usa para melhoria | ofertas comerciais não treinam com entradas/saídas, salvo opt-in explícito |
| Retenção padrão relevante | logs de abuso podem reter conteúdo por até 30 dias; `Responses` deve usar `store: false` e evitar recursos com estado | Vertex pode registrar prompts para abuso; cache em memória, isolado por projeto, tem TTL de 24 h e pode ser desativado; grounding Search/Maps retém conteúdo por 30 dias | API apaga entradas e saídas em até 30 dias, salvo exceções de política, lei ou recurso persistente |
| Retenção reduzida | ZDR/MAM dependem de aprovação e possuem limitações por endpoint/recurso | exceção de abuse monitoring pode ser solicitada; atingir ZDR exige desativar ou evitar cada recurso que retenha dados | ZDR depende de aprovação; classificadores de segurança e recursos incompatíveis permanecem exceções |
| Português | modelos atuais são oficialmente multilíngues; qualidade pt-BR precisa de avaliação própria | português é idioma explicitamente suportado | documentação publica avaliação pt-BR e recomenda fixar o idioma no system prompt |
| Saída estruturada | JSON Schema com Structured Outputs e recusas detectáveis | subconjunto de JSON Schema; formato correto não garante valor semanticamente correto | JSON output e strict tool use com conformidade de esquema nos modelos suportados |
| Ferramentas | function calling e ferramentas hospedadas; permissões precisam de allowlist | function calling e ferramentas/grounding; grounding externo fica proibido no primeiro piloto | ferramentas client-side e server-side; toda saída de ferramenta continua não confiável |
| Controle de gasto | hard spend limit por projeto, alertas, rate limits e APIs de uso/custo | quotas, alertas e spend caps para serviços elegíveis; o spend cap está em preview e não é instantâneo | teto mensal por tier, limite próprio menor e rate limits por organização/workspace |
| Integração operacional | exige serviço backend e segredo/identidade isolada do cliente | Vertex combina com IAM e faturamento Google Cloud já adotados pelo backend, mas exige novo portão externo | exige serviço backend e segredo/identidade isolada do cliente |

## Custos públicos de referência

Valores em USD por um milhão de tokens, consultados em 25/08/2026. Não são orçamento do produto, não incluem impostos, câmbio, Cloud Functions/Run, rede, armazenamento, ferramentas, cache ou retries e não tornam os modelos equivalentes em qualidade.

| Rota representativa de menor custo | Entrada | Saída | Observação |
|---|---:|---:|---|
| OpenAI `gpt-5.6-luna` | US$ 0,20 | US$ 1,20 | modelo atual orientado a alto volume e custo sensível |
| Vertex AI `Gemini 3.5 Flash-Lite`, endpoint global | US$ 0,30 | US$ 2,50 | endpoint não global publicado a US$ 0,33/US$ 2,75 |
| Anthropic `Claude Haiku 4.5` | US$ 1,00 | US$ 5,00 | cache e ferramentas têm regras de preço próprias |

O custo real deverá ser calculado por `tokens de entrada × tarifa + tokens de saída × tarifa + ferramentas + infraestrutura`, medido com a mesma suíte e a mesma carga sintética. Limites por pergunta, por usuário, por dia e por projeto continuam obrigatórios mesmo quando o fornecedor oferece teto de gasto.

## Avaliação por provedor

### OpenAI API

- Pontos favoráveis: menor preço público entre as rotas representativas comparadas, modelos multilíngues, Structured Outputs, function calling, allowlists de modelo/ferramenta e hard spend limit por projeto.
- Cuidados: os logs de abuso podem conter prompts e respostas por até 30 dias; ZDR/MAM exige aprovação; `store: false` não elimina retenções próprias de ferramentas ou endpoints incompatíveis.
- Condição mínima de piloto: projeto isolado, `store: false`, nenhuma ferramenta hospedada, nenhuma busca/web/file, esquema estrito, output curto, rate limit server-side e confirmação documental da política de retenção aplicável à organização.

### Gemini Developer API pago e Vertex AI

- Pontos favoráveis: português explicitamente suportado, structured output, function calling, IAM/identidade de serviço e controles de faturamento integrados ao Google Cloud. Vertex não usa dados do cliente para treinamento sem permissão.
- Cuidados: o free tier/AI Studio não serve para dados financeiros; prompt logging para abuso pode existir; cache em memória de 24 h vem habilitado por padrão; grounding com Search/Maps cria retenção de 30 dias; spend caps ainda estão em preview e podem ter atraso de aplicação.
- Condição mínima de piloto: somente serviço pago/Vertex, identidade dedicada sem chave baixável, cache desativado, nenhuma modalidade de grounding, região e DPA revisados, quotas conservadoras e spend cap adicional ao orçamento/alertas.

### Anthropic API

- Pontos favoráveis: entradas/saídas comerciais não treinam modelos por padrão, suporte pt-BR documentado, Structured Outputs, strict tool use e tetos mensais efetivos.
- Cuidados: retenção padrão de até 30 dias; ZDR exige aprovação e possui exceções; Files API, prompt caching e ferramentas de terceiros têm políticas próprias; a rota econômica representativa tem preço público superior às alternativas de baixo custo comparadas.
- Condição mínima de piloto: organização com retenção confirmada, sem Files/web/search/cache, saída estruturada, ferramentas desativadas, limite mensal próprio e rate limit no backend.

## Recomendação sem seleção

1. Manter o contrato provider-neutral do ASSIST-0 e não adicionar SDK de fornecedor ao Flutter.
2. Priorizar **Vertex AI como primeira rota de prova técnica**, apenas por compatibilidade operacional com IAM e backend Google Cloud já adotados, não por decisão de fornecedor.
3. Executar o mesmo benchmark sintético em OpenAI API e Anthropic API antes de qualquer escolha. OpenAI deve ser o comparador principal de custo/estrutura; Anthropic, o comparador de qualidade em pt-BR e comportamento de segurança.
4. Descartar o free tier do Gemini e qualquer console interativo para dados financeiros.
5. Não aprovar produção sem contrato/DPA, base legal e consentimento versionado, retenção conhecida, processo de exclusão, residência/processamento avaliados, hard cap ou mecanismo equivalente, limite interno, testes adversariais e avaliação pt-BR.

Essa ordem é apenas uma recomendação de avaliação. A escolha final depende de um incremento separado com dados exclusivamente sintéticos, métricas iguais de qualidade, latência, tokens, falhas, retenção efetiva e custo total. Nenhum provedor é selecionado por este documento.

## Arquitetura obrigatória para qualquer candidato

- A chave ou identidade fica somente no backend e, quando segredo for necessário, no Secret Manager; nunca no APK, Firestore, Git, log ou configuração cliente.
- O aplicativo envia apenas a pergunta aprovada. O backend confirma Auth, App Check, e-mail, perfil, UID e consentimento e monta contexto mínimo com aliases efêmeros.
- O primeiro piloto usa somente leitura, sem memória, busca externa, upload de arquivo, ferramenta server-side ou ação mutável.
- `temperature`/aleatoriedade baixa quando disponível, esquema fechado, validação semântica local e evidências obrigatórias continuam independentes do fornecedor.
- Logs registram apenas operação, modelo lógico, duração, contagem de tokens e código sanitizado; nunca pergunta, resposta, valores, UID, e-mail ou segredo.
- Timeout, máximo de tokens, rate limit, circuit breaker, limite diário e teto financeiro falham fechados sem bloquear o núcleo financeiro.

## Fontes oficiais consultadas

### OpenAI

- [Data controls in the OpenAI platform](https://developers.openai.com/api/docs/guides/your-data)
- [Models and current token prices](https://developers.openai.com/api/docs/models)
- [Structured model outputs](https://developers.openai.com/api/docs/guides/structured-outputs)
- [Function calling](https://developers.openai.com/api/docs/guides/function-calling)
- [Project rate limits, spend alerts and hard spend limits](https://developers.openai.com/api/reference/typescript/resources/admin/subresources/organization/subresources/projects)

### Google

- [Vertex AI and zero data retention](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/vertex-ai-zero-data-retention)
- [Gemini Developer API pricing and data-use distinction](https://ai.google.dev/gemini-api/docs/pricing)
- [Vertex AI generative pricing](https://cloud.google.com/vertex-ai/generative-ai/pricing)
- [Structured outputs](https://ai.google.dev/gemini-api/docs/structured-output)
- [Function calling](https://ai.google.dev/gemini-api/docs/function-calling)
- [Google models and language support](https://cloud.google.com/vertex-ai/generative-ai/docs/models)
- [Spend cap budgets](https://docs.cloud.google.com/billing/docs/how-to/budgets-spend-caps)

### Anthropic

- [Commercial API retention](https://privacy.claude.com/en/articles/7996866-how-long-do-you-store-my-organization-s-data)
- [Commercial data use for model training](https://privacy.claude.com/en/articles/7996885-how-do-you-use-personal-data-in-model-training)
- [Zero data retention scope](https://privacy.claude.com/en/articles/8956058-i-have-a-zero-data-retention-agreement-with-anthropic-what-products-does-it-apply-to)
- [Model pricing](https://platform.claude.com/docs/en/about-claude/pricing)
- [Structured outputs](https://platform.claude.com/docs/en/build-with-claude/structured-outputs)
- [Tool use](https://platform.claude.com/docs/en/agents-and-tools/tool-use/overview)
- [Rate and spend limits](https://platform.claude.com/docs/en/api/rate-limits)
- [Multilingual support](https://platform.claude.com/docs/en/build-with-claude/multilingual-support)
