# ADR-006 — Anexos e exportações

- Status: aceito
- Data: 22/07/2026

## Contexto

Comprovantes exigem armazenamento protegido; exportações não devem enviar dados à nuvem sem necessidade.

## Decisão

Cloud Storage futuro aceita PDF, JPEG e PNG, máximo 10 MB e cinco arquivos por entidade, com validação de extensão, MIME e assinatura, sem URL pública.

CSV e Excel são locais. PDF é local quando seguro para a memória. Exportação grande por Function exige nova aprovação.

## Consequências

- Storage e billing não são ativados agora.
- Arquivos órfãos expiram após 30 dias.
- Exportação local permanece sob controle do usuário.
