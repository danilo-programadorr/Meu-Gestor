# ADR-008 — Privacidade, retenção, backups e notificações

- Status: aceito
- Data: 22/07/2026

## Contexto

Analytics, IA, logs, retenção e tela bloqueada tratam dados financeiros sensíveis.

## Decisão

- Analytics inicia desativado e permite retirada de consentimento.
- IA tem consentimento separado.
- Crashlytics e Analytics não recebem dados pessoais ou financeiros.
- IA e notificações antigas retêm 90 dias; auditoria técnica 180; anexos órfãos 30.
- Backup de produção é planejado para 30 dias, sem ativação paga agora.
- Tela bloqueada usa mensagem genérica por padrão.

## Consequências

- Política jurídica final continua necessária antes da publicação.
- Exclusão de conta cobre dados, anexos e dispositivos e informa janela de backup.
- Detalhes na notificação exigem opção informada.
