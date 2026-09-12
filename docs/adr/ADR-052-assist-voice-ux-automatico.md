# ADR-052 — ASSIST-VOICE-UX-1: envio automático por modo

## Contexto

O modo de conversa exigia uma segunda ação para consultar a resposta
fundamentada após a pergunta. Isso quebrava a continuidade tanto do texto
quanto da voz. Além disso, a interface de voz mostrava a transcrição e a
resposta escrita, embora a escolha desse modo deva preservar uma experiência
somente em áudio.

## Decisão

- Enviar uma pergunta textual segura inicia automaticamente a consulta remota e
  mostra o único painel de resposta fundamentada com fontes e período civil.
- Quando o reconhecedor encerra uma fala, o texto efêmero é enviado
  automaticamente e removido do estado visual antes da resposta. A resposta ou
  indisponibilidade segura é reproduzida exclusivamente pelo TTS; não há
  transcrição, cartão de resposta ou evidência visível nesse modo.
- O cliente ainda envia somente a mensagem. Antes do gateway, ele exige
  consentimento geral de IA, aceite remoto próprio válido e privacidade
  financeira desativada. O backend revalida tudo e continua sendo a única
  autoridade para contexto, evidência, custo e resposta.
- A tela Privacidade e consentimentos só permite editar o aceite remoto depois
  de o consentimento geral de IA estar salvo. Retirar esse consentimento revoga
  também o aceite remoto; se a revogação remota falhar, o consentimento geral
  já salvo continua bloqueando o backend.

## Consequências

O botão “Consultar resposta fundamentada” deixa de existir. Saída, troca de
conta, perda de primeiro plano ou privacidade financeira continuam invalidando
retornos tardios, parando voz e removendo o estado local. A alteração não cria
uma capacidade de escrita financeira, não persiste áudio ou transcrição e não
altera a política de falha fechada.
