# ADR-005 — Offline, conflitos e simulações

- Status: aceito
- Data: 22/07/2026

## Contexto

Operações financeiras offline e aplicação de cenários não podem causar confirmação silenciosa ou perda concorrente.

## Decisão

Consultas e cadastros simples funcionam offline. Operações críticas podem ser preparadas, mas só confirmam após servidor validar revision, updatedAt, atomicidade e idempotência.

Conflitos mostram as versões ao usuário. Simulação apresenta prévia e só aplica após confirmação, em operação atômica e auditável.

## Consequências

- Last-write-wins silencioso é proibido.
- A interface distingue pendente local de confirmado.
- Testes cobrem reconexão, conflito e falha parcial.
