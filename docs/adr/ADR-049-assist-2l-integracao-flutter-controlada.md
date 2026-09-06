# ADR-049 — ASSIST-2L: integração Flutter controlada da resposta fundamentada

## Contexto

O backend local já define a callable `assistRemoteV1`, o contrato mínimo
`assist-remote-v1`, a barreira de evidências e o retorno fail-closed. A tela de
conversa precisava ficar preparada para consumir uma resposta fundamentada sem
transformar voz ou texto em envio automático.

## Decisão

- A tela preserva o resumo determinístico como fluxo principal e só tenta a
  consulta remota após o toque explícito em “Consultar resposta fundamentada”.
- A flag compilada de chamadas remotas começa falsa. Nesse estado o controller
  não chama sequer o gateway; não existe requisição de rede.
- Mesmo numa ativação futura, Flutter constrói exclusivamente
  `{ contractVersion: 'assist-remote-v1', message }`. UID, e-mail, token,
  contexto, valores, custo e modelo não atravessam a fronteira cliente.
- Consentimento de IA e privacidade financeira são verificados no controller
  antes da tentativa. O backend permanece autoridade para revalidá-los,
  montar contexto, decidir Flash/Pro, aplicar custo e chamar provedor.
- A resposta aceita é estrita: `safe_unavailable` ou uma resposta fundamentada
  com texto seguro, aliases efêmeros, fonte permitida e período civil
  `America/Sao_Paulo`. Forma inválida vira indisponibilidade segura.
- Saída, troca de conta e privacidade invalidam operações tardias e removem a
  resposta localmente. A integração não altera qualquer dado financeiro.

## Consequências

Não houve chamada Firebase, Function em nuvem, Vertex, deploy, segredo ou
ativação para usuário. A habilitação da flag continua dependente de autorização
externa específica, revisão do backend e rollout controlado.

## Verificação

Testes cobrem flag desligada sem gateway, consentimento ausente, privacidade,
payload mínimo, resposta fundamentada válida, forma inválida, indisponibilidade
e retorno tardio após bloqueio de privacidade.
