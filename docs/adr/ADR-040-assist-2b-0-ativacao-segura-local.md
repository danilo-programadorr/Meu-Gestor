# ADR-040 — ASSIST-2B-0: preparação local para ativação segura

Data: 30/08/2026
Situação: implementado somente localmente; chamadas reais permanecem desligadas.

## Decisão

1. O Flutter conhece apenas `assist-remote-v1` e envia exclusivamente a mensagem sanitizada. UID, e-mail, consentimento, contexto financeiro, escolha Flash/Pro, credenciais e tokens nunca fazem parte do payload.
2. A borda futura valida no servidor autenticação, App Check, e-mail verificado, perfil jurídico, consentimento atual confirmado pelo servidor e contexto próprio sem escrita pendente antes de selecionar um tier.
3. O roteador escolhe Flash ou Pro exclusivamente no backend, dentro dos limites de fatos, contexto, custo e uso. O cliente não possui seletor de modelo.
4. O kill switch local começa ativo e a flag de provedor real começa compilada como `false`. Mesmo com o kill switch desativado em teste, a ausência da flag mantém a execução bloqueada.
5. A barreira fail-closed continua sendo obrigatória antes de qualquer entrega. Observabilidade futura aceita apenas duração, resultado sanitizado e tier; não aceita prompt, resposta, áudio, UID, e-mail, valores nem dados de terceiros.

## Ativação development — autorizações externas separadas

Nenhuma ação abaixo foi executada neste incremento. A ativação development exigirá, nesta ordem, autorizações específicas para:

1. criar ou aprovar a identidade runtime sem chave e os papéis mínimos da Function Gen 2 dedicada;
2. criar Secret Manager para a credencial do provedor, concedendo acesso apenas à identidade runtime;
3. criar a Function development com App Check, Auth, e-mail verificado, perfil jurídico e limite de requisições; publicar somente esse codebase;
4. aprovar regras locais/publicadas, se um caminho de leitura confirmado adicional for necessário;
5. definir orçamento, alertas, cotas e o procedimento operacional do kill switch;
6. testar exclusivamente com fixtures sintéticas antes de qualquer opt-in de usuário; e
7. aprovar separadamente o consentimento de envio, retenção, monitoramento e o rollout development.

Não há autorização implícita para Vertex, outro provedor, Firebase, IAM, Secret Manager, deploy, regras, cobrança ou produção.
