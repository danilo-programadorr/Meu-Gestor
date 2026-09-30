# ADR-037 — ASSIST-VOICE-2A: modo de conversa local

Data: 28/08/2026

## Decisão

O modo de conversa usa o reconhecedor configurado no Android. O microfone só é solicitado após explicação e toque explícito, enquanto a tela está visível e o app em primeiro plano. Não existe áudio persistido, serviço em segundo plano, palavra de ativação ou telemetria de voz própria.

Em 30/09/2026, o modo remoto passou a sintetizar somente texto já admitido pelo servidor com `gemini-3.1-flash-tts-preview`, voz feminina `Sulafat`, em `pt-BR`. O WAV retorna no mesmo envelope apenas para o modo voz, é limitado e reproduzido por arquivo efêmero no cache, removido na conclusão/interrupção; o TTS Android permanece fallback. O modo texto não chama síntese. A gravação do microfone nunca é enviada ao sintetizador.

A transcrição é estado efêmero da tela, apagada ao sair, ao perder foco, bloquear, trocar de conta ou ativar privacidade financeira. O assistente pode pedir um esclarecimento contextual e preservar somente a pergunta anterior durante a sessão; respostas e fatos financeiros não são reenviados como memória do cliente. A voz nunca executa mutações financeiras.

## Consequências

`RECORD_AUDIO` exige divulgação futura no Google Play Data safety: microfone usado para reconhecer perguntas nesta tela, sem persistência pelo app e transcrição temporária. A publicação futura deve declarar o possível processamento pelo reconhecimento Android e pelo Gemini-TTS, além de manter a alternativa textual.
