# ADR-007 — Gemini e plano anticrise híbrido

- Status: aceito
- Data: 22/07/2026

## Contexto

IA financeira precisa ser útil sem controlar valores, prioridades ou operações.

## Decisão

Gemini é acessado por Function com Authentication, App Check, esquema validado, timeout, custo e limite inicial de 10 análises por usuário/dia e cerca de 2.000 tokens de saída.

Regras determinísticas produzem cálculos e prioridades do plano anticrise. Gemini somente explica, organiza, oferece alternativas e pergunta por dados ausentes.

## Consequências

- Modelo é configurável e escolhido entre opções estáveis na implementação.
- Prompt bruto, anexos e identificadores desnecessários não são armazenados/enviados.
- Falha ou recusa da IA não bloqueia funções financeiras.
