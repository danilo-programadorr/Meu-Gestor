# ADR-039 — ASSIST-2A: benchmark Vertex sintético e limitado

Data: 30/08/2026
Situação: prova técnica controlada em development; não seleciona fornecedor nem integra IA ao aplicativo.

## Contexto

O ASSIST-0 exige uma borda neutra, contexto minimizado e controles de custo antes de qualquer integração generativa. Era necessário verificar, sem contexto de usuário, a disponibilidade técnica global e o comportamento estrutural de um modelo Flash e um Pro em português.

## Decisão

1. O teste usa somente o endpoint global e os modelos GA `gemini-2.5-flash` e `gemini-2.5-pro`.
2. São permitidas no máximo oito chamadas: quatro fixtures inteiramente sintéticas por modelo. Cada chamada é limitada a 1.500 tokens de entrada e 500 de saída.
3. Áudio, imagem, grounding, busca web, cache, ferramentas e streaming ficam explicitamente desativados. Não há envio de dado financeiro, calendário, transcrição, identidade, credencial ou dado de usuário.
4. O coletor aceita apenas métricas agregadas: modelo, rótulo sintético, latência, tokens, custo estimado e nota estrutural. Prompt e resposta não têm campo persistível.
5. Após até R$ 0,088 estimados no ensaio interrompido por erro local do coletor, o novo limite adicional foi R$ 1,912. O teste íntegro consumiu estimativa conservadora de R$ 0,230401; o teto agregado contabilizado é R$ 0,318401, abaixo de R$ 2,00.

## Resultado agregado

| Modelo | Chamadas | Latência média | Nota estrutural média | Custo estimado |
|---|---:|---:|---:|---:|
| Flash | 4 | 2,729 s | 8,0/10 | R$ 0,034689 |
| Pro (ensaio inicial) | 4 | 5,963 s | inconclusivo por truncamento | R$ 0,195712 |

As quatro respostas iniciais de Pro chegaram muito próximas ao limite de 500 tokens e não concluíram o JSON exigido. Elas são classificadas como `inconclusive_truncated`, sem nota. Isso não é julgamento de qualidade do modelo.

O retry autorizado usou as mesmas quatro categorias sintéticas, JSON compacto e teto de 800 tokens. As quatro respostas concluíram entre 27 e 88 tokens: latência média de 7,215 s, nota estrutural média de 5,25/10 e custo estimado de R$ 0,020713. A nota mede somente o contrato mínimo das fixtures; não é uma avaliação financeira, de segurança em produção ou de qualidade geral. O teto agregado conservador passou a R$ 0,339114, ainda abaixo de R$ 2,00.

Os custos são estimativas locais conservadoras, com multiplicador fixo de R$ 10 por US$ 1; a cobrança efetiva permanece fonte de verdade externa. Não foram persistidos prompts ou respostas, e o arquivo temporário de métricas permanece ignorado pelo Git.

## Consequências

- Flash demonstrou menor latência e custo neste conjunto mínimo; Pro concluiu o JSON compacto no retry, porém foi mais lento. Nenhum fornecedor ou modelo está selecionado para o produto.
- O app, o APK, Firestore, Functions, Rules e Secret Manager continuam sem integração de IA.
- Próxima decisão requer política de retenção, consentimento de envio, arquitetura server-side, orçamento e avaliação adicional explicitamente autorizada.
