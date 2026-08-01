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

Perfil, contas, categorias e lançamentos usam caminhos subordinados ao UID. Acesso financeiro exige email verificado e perfil jurídico atual. Categorias e lançamentos usam campos fechados, timestamps do servidor e exclusão negada. Logs locais de diagnóstico registram somente operação, etapa, duração, categoria técnica, tipo/código sanitizado e estado final; nunca registram valores, descrições, notas, IDs de documentos, email ou tokens.

As regras de perfil, contas, categorias, lançamentos e owner foram publicadas manualmente no projeto development. A validação real no Emulator Suite permanece futura; não flexibilize regras para contornar erros de configuração ou publicação.

## Acesso proprietário

O papel `owner` é concedido somente por um documento administrativo criado manualmente em `system_admins/{uid}`. O aplicativo usa o UID da sessão, lê somente o próprio documento diretamente do servidor e não possui API para criar, editar, excluir ou listar administradores.

E-mail, senha, UID hardcoded, parâmetro de rota, preferência ou armazenamento local nunca autorizam owner. O documento é válido somente em development e a decisão falha fechada diante de cache, timeout, erro ou incompatibilidade.

Capabilities owner liberam funcionalidades do produto e futuros recursos comerciais, mas não ignoram Security Rules, isolamento por UID, autenticação, validações financeiras, concorrência, integridade ou limites técnicos contra abuso. Diagnósticos omitem identidade, conteúdo administrativo, tokens, project ID e dados financeiros.
