# ADR-007 — Gemini e plano anticrise híbrido

- Status: escolha de provedor superada pela ADR-033; controles determinísticos e de segurança preservados
- Data: 22/07/2026

## Contexto

IA financeira precisa ser útil sem controlar valores, prioridades ou operações.

## Decisão

A proposta histórica indicava Gemini por Function com Authentication, App Check, esquema validado, timeout, custo e limites. A ADR-033 substitui a escolha do fornecedor por contrato neutro: nenhum provedor será conectado sem nova decisão e autorização.

Regras determinísticas produzem cálculos e prioridades do plano anticrise. Um provedor futuro somente explica, organiza, oferece alternativas e pergunta por dados ausentes.

## Consequências

- Modelo é configurável e escolhido entre opções estáveis na implementação.
- Prompt bruto, anexos e identificadores desnecessários não são armazenados/enviados.
- Falha ou recusa da IA não bloqueia funções financeiras.
