# ADR-053 — ASSIST-PRIVACY-POPUP-1: consentimento na conversa

## Contexto

A tela de conversa dependia de uma navegação para Privacidade e consentimentos
para ativar o Assistente. Isso interrompia a intenção de conversar e deixava a
concessão dos dois consentimentos em controles separados.

## Decisão

- Ao entrar em Conversa, ausência, revogação, falha de leitura ou forma
  inválida do aceite remoto abre um popup na própria tela, sem navegar ou
  fechá-la.
- O popup apresenta somente a decisão de ativar o Assistente Financeiro:
  “Ativar e continuar” grava primeiro o consentimento geral de IA e então o
  consentimento remoto canônico. A conversa só é liberada após ambas as
  confirmações; falha parcial permanece fechada e permite nova tentativa.
- “Agora não” fecha exclusivamente o popup, mantém a pessoa na conversa e
  preserva o bloqueio remoto.
- Perfil mantém a revogação do Assistente; a ativação acontece somente no
  contexto da conversa. A revogação grava primeiro o bloqueio geral, que já
  fecha o backend mesmo se a segunda escrita falhar.

## Consequências

Texto e voz continuam automáticos conforme ADR-052. O gateway Flutter ainda
exige os dois consentimentos e privacidade financeira desativada; o backend
permanece autoridade revalidando essas condições. Não há alteração de Firebase,
Function, IAM, Rules, Vertex ou produção.
