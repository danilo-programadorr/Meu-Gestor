# Política de segurança

## Versões suportadas

O projeto está em desenvolvimento e ainda não possui versão de produção. Somente o código mais recente da branch `main` recebe correções de segurança neste momento.

## Como reportar uma vulnerabilidade

Use a opção privada **Report a vulnerability** na aba **Security** do repositório. Não abra issue pública contendo vulnerabilidade explorável, credencial, token, configuração Firebase, dado pessoal ou informação financeira.

Se o canal privado não estiver disponível, abra uma issue sem detalhes técnicos solicitando que um mantenedor disponibilize um canal privado. Não anexe evidências sensíveis à issue.

Inclua no relato privado, quando possível:

- componente e versão afetados;
- impacto observado;
- passos mínimos para reprodução sem dados reais;
- mitigação sugerida;
- confirmação de que nenhuma credencial real foi publicada.

Os mantenedores farão triagem e responderão conforme disponibilidade e gravidade, sem promessa de prazo incompatível com a natureza voluntária do projeto. A correção será publicada depois de reduzir o risco de exploração e revisar possíveis impactos.

## Escopo de dados

Nunca envie senhas, tokens, chaves privadas, contas de serviço, arquivos `google-services.json`, dados financeiros reais ou informações pessoais em um relatório. Se uma credencial tiver sido exposta, revogue-a e faça a rotação no provedor correspondente.

## Dados financeiros implementados

Perfil, contas, categorias, lançamentos, compromissos, investimentos e proventos manuais usam caminhos subordinados ao UID. Acesso financeiro exige email verificado e perfil jurídico atual. Documentos financeiros usam campos fechados, timestamps do servidor e exclusão negada. Operações de investimento não afetam o saldo, são encadeadas, imutáveis e alteram a projeção do ativo somente em mutação atômica. Proventos usam coleção própria, referências ativas, revisão e transições terminais; não criam lançamento nem alteram conta, posição ou resumo mensal. Logs locais de diagnóstico registram somente operação, etapa, duração, categoria técnica, tipo/código sanitizado e estado final; nunca registram valores, descrições, notas, IDs de documentos, email ou tokens.

As regras são validadas localmente no Emulator Suite com projeto `demo-*`. Perfil, núcleo financeiro, compromissos, investimentos, proventos e owner foram publicados somente no projeto development mediante autorizações específicas. As regras do INV-PROV-1 foram compiladas e publicadas com sucesso exclusivamente em development, sem acesso a production, com SHA-256 `8B689BA72FE05B1C04409E00083644D83B2EEACFDDA67A7C8D003B843E102FBE`; o APK debug development foi gerado e aprovado manualmente, enquanto commit e push permaneciam pendentes nesta atualização. Não flexibilize regras para contornar erros de configuração ou publicação.

## Acesso proprietário

O papel `owner` é concedido somente por um documento administrativo criado manualmente em `system_admins/{uid}`. O aplicativo usa o UID da sessão, lê somente o próprio documento diretamente do servidor e não possui API para criar, editar, excluir ou listar administradores.

E-mail, senha, UID hardcoded, parâmetro de rota, preferência ou armazenamento local nunca autorizam owner. O documento é válido somente em development e a decisão falha fechada diante de cache, timeout, erro ou incompatibilidade.

Capabilities owner liberam funcionalidades do produto e futuros recursos comerciais, mas não ignoram Security Rules, isolamento por UID, autenticação, validações financeiras, concorrência, integridade ou limites técnicos contra abuso. Diagnósticos omitem identidade, conteúdo administrativo, tokens, project ID e dados financeiros.

## Entitlement Premium — SUB-1A

O SUB-1A é somente domínio e contrato. Não existe entitlement persistido, backend verificador, Security Rule Premium, produto de loja, compra, paywall ou bloqueio ativo. Investimentos continuam acessíveis no ambiente development atual.

O modelo não contém purchase token, recibo completo, payload Google, dados de cartão, preço, credencial ou identificador externo usado como autorização. O contrato cliente possui somente leitura, observação confirmada, releitura do servidor e diagnóstico sanitizado; criar, ativar, renovar, revogar, reembolsar e conceder pertencem ao futuro backend.

Concessões administrativas e de development deverão ter validade e auditoria, ser emitidas somente pelo backend e respeitar o ambiente. Owner poderá receber acesso para o próprio UID, sem ignorar isolamento ou obter acesso cruzado. A decisão local é projeção de experiência e nunca substitui a futura autorização de backend e Security Rules.

Após perda de Premium, dados patrimoniais não são apagados nem alterados: leitura histórica é preservada, mutações são bloqueadas e cotações deixam de ser fornecidas. Esse comportamento ainda não foi conectado aos repositórios ou à interface. A integração B3/corretoras permanece cancelada; cotações por provedor independente permanecem bloqueadas por licenciamento e SUB-1.
