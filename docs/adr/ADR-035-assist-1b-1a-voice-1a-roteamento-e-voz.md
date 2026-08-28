# ADR-035 — ASSIST-1B-1A/ASSIST-VOICE-1A: roteamento lógico e voz local

Data: 25/08/2026
Situação: implementado e validado somente localmente; nenhum provedor de IA ou recurso externo ativado.

## Contexto

O contrato do Assistente já separa contexto confirmado, consentimento, evidências e propostas. Faltavam limites verificáveis para uma futura escolha de modelos e uma opção de leitura acessível sem transformar áudio em dado persistido ou serviço externo.

## Decisão

1. O backend usa tiers lógicos `flash` e `pro`, sem nome de modelo ou fornecedor. `flash` é padrão. `pro` exige múltiplos sinais fechados de complexidade e disponibilidade simultânea de limite de contexto, chamadas e unidades abstratas de custo.
2. O cliente não envia nem escolhe tier. Campo adicional é recusado pelo contrato. Análise complexa sem orçamento falha fechada; não é silenciosamente rebaixada para uma resposta potencialmente inadequada.
3. Unidades de custo não representam preço comercial. Um adaptador futuro, autorizado separadamente, deverá mapear preços reais e aplicar orçamento server-side antes da chamada.
4. Nesta etapa o gateway continua fake e desconectado. Nenhum dado financeiro é enviado e nenhuma resposta é apresentada como gerada por IA.
5. A leitura usa `flutter_tts 4.2.5`, licença MIT, somente como ponte para o TTS nativo do dispositivo. Não há microfone, gravação, arquivo de voz, memória, chave ou serviço de voz em nuvem.
6. “Responder em voz” começa desligado. A resposta textual permanece visível. Pausar, continuar, repetir, parar e três velocidades são controlados por uma abstração substituível em testes.
7. Ocultar dados financeiros interrompe e descarta o texto repetível. Sair da rota, suspender/bloquear o aplicativo e trocar a identidade autenticada também interrompem a reprodução.
8. A voz é configurada como `pt-BR`. Ausência de voz compatível ou falha do mecanismo gera mensagem sanitizada e não afeta a resposta escrita.

## Dependência e compatibilidade

- versão fixada: `flutter_tts 4.2.5`;
- origem pública: pub.dev; licença MIT; sem dependência de SDK de provedor de IA;
- Android mínimo do pacote: API 21; o projeto usa o mínimo definido pelo Flutter;
- consulta `android.intent.action.TTS_SERVICE` declarada no manifesto para visibilidade de pacotes;
- pausar/continuar no Android depende do mecanismo baseado em marcação disponível a partir da API 26; falha é fechada e o texto continua utilizável.

## Consequências

- A política pode ser testada sem custo ou fornecedor e não expõe seleção de modelo ao aplicativo.
- A fala depende das vozes instaladas e das características do mecanismo Android do usuário.
- Uma integração generativa continua bloqueada por seleção explícita de provedor, consentimento de envio, backend, segredo, orçamento, retenção e autorização de deploy.
