# ADR-037 — ASSIST-VOICE-2A: modo de conversa local

Data: 28/08/2026

## Decisão

O modo de conversa usa exclusivamente o reconhecedor e o sintetizador nativos configurados no Android. O microfone só é solicitado após explicação e toque explícito, enquanto a tela está visível e o app em primeiro plano. Não existe áudio persistido, serviço em segundo plano, palavra de ativação, telemetria, API própria ou voz em nuvem.

A transcrição é estado efêmero da tela, apagada ao sair, ao perder foco, bloquear, trocar de conta ou ativar privacidade financeira. Apenas intenções que mapeiam às quatro perguntas determinísticas existentes são respondidas; ausência de correspondência informa a limitação sem inventar conversa livre. A voz nunca executa mutações financeiras.

## Consequências

`RECORD_AUDIO` exige divulgação futura no Google Play Data safety: microfone usado para reconhecer perguntas nesta tela, retenção zero de áudio e transcrição local temporária. A publicação futura deve validar o serviço de reconhecimento do dispositivo e manter a alternativa textual.
