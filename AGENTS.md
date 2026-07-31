# Regras permanentes de desenvolvimento

Este arquivo se aplica a todo o repositório. Instruções mais específicas em subdiretórios podem acrescentar restrições, mas não podem reduzir segurança, qualidade ou proteção de dados.

## 1. Autoridade e escopo

1. Ler `PLANO_DESENVOLVIMENTO.md` e este arquivo antes de qualquer trabalho.
2. Trabalhar em incrementos pequenos, completos e verificáveis.
3. Não iniciar implementação até existir autorização explícita do solicitante.
4. Não ampliar o escopo funcional por inferência. Registrar decisões ausentes e solicitar aprovação quando alterarem o produto.
5. Não instalar, atualizar, remover ou configurar ferramentas, SDKs, pacotes globais, serviços ou contas sem explicar impacto, comando e alternativa e obter autorização.
6. Não criar, alterar ou implantar recursos externos sem autorização compatível com o impacto.
7. Não publicar nem executar deploy em produção sem autorização específica.

## 2. Ambiente e comandos

1. Usar comandos compatíveis com Windows PowerShell.
2. Preferir comandos não interativos, determinísticos e com escopo explícito.
3. Antes de executar um comando destrutivo, confirmar o caminho absoluto e a autorização do solicitante.
4. Nunca usar comandos destrutivos contra diretórios amplos, variáveis não resolvidas ou caminhos inferidos.
5. Não sobrescrever alterações existentes do solicitante.
6. Inspecionar o estado do Git e os arquivos afetados antes de editar.
7. Não usar `git reset --hard`, descarte forçado ou reescrita de histórico sem pedido explícito.
8. Não fazer commit, push, merge, rebase, criação de tag ou abertura de pull request sem solicitação.

## 3. Qualidade do código

1. Não entregar código incompleto, pseudocódigo, marcadores de continuação, funções vazias ou comentários que substituam implementação.
2. Não usar dados fictícios em produção. Dados de demonstração são permitidos exclusivamente em ambiente `development` e em testes automatizados, desde que estejam desativados por padrão, sejam ativados por configuração explícita de desenvolvimento, não contenham dados pessoais reais, nunca sejam enviados ao Firebase de produção e possam ser apagados completamente.
3. Implementar somente funcionalidades com comportamento e critérios de aceite definidos.
4. Manter o domínio financeiro independente de Flutter, Firebase e widgets.
5. Usar tipos explícitos e objetos de valor para dinheiro, moeda, datas e identificadores.
6. Nunca representar valores monetários com ponto flutuante.
7. Manter arquivos e componentes coesos; evitar abstrações sem uso real.
8. Tratar erros de forma tipada e apresentar mensagens seguras e compreensíveis.
9. Não ignorar advertências do analisador sem justificativa documentada.
10. Não adicionar dependências sem explicar finalidade, manutenção, licença, impacto de tamanho e alternativa nativa.
11. Fixar dependências resolvidas no arquivo de lock apropriado e revisar atualizações por testes.
12. Executar formatação, análise e testes relevantes antes de declarar uma tarefa concluída.

## 4. Arquitetura

1. Organizar o código por funcionalidade, com camadas `presentation`, `domain` e `data` quando a complexidade justificar.
2. Direcionar dependências para o domínio; tipos Firebase não entram em entidades de domínio.
3. Acessar Firestore apenas por implementações de repositório.
4. Colocar regras de negócio em casos de uso ou domínio, não em widgets.
5. Usar Riverpod para estado e dependências e `go_router` para navegação, salvo decisão arquitetural aprovada em contrário.
6. Estados assíncronos devem representar carregamento, sucesso, vazio e falha.
7. Registrar decisões estruturais relevantes em `docs/adr`.
8. Evitar duplicação de fonte de verdade. Projeções e caches precisam de estratégia explícita de consistência e reconstrução.

## 5. Firebase e dados

1. Separar projetos Firebase de desenvolvimento e produção.
2. Usar Firebase Emulator Suite para desenvolvimento e testes de regras sempre que aplicável.
3. Negar acesso por padrão nas Security Rules.
4. Isolar dados pelo `uid` autenticado e validar campos, tipos, limites, enumerações e imutabilidade.
5. Testar regras de leitura e escrita autorizadas e negadas antes de deploy.
6. Não confiar em validação exclusivamente no cliente.
7. Usar operações atômicas para mudanças financeiras relacionadas.
8. Usar timestamps de servidor para auditoria técnica quando aplicável.
9. Versionar o esquema e planejar migrações idempotentes e compatíveis.
10. Criar somente índices exigidos pelas consultas implementadas.
11. Não apagar dados financeiros ou de auditoria sem regra de retenção aprovada.
12. Medir leituras, gravações, armazenamento, listeners e tráfego das funcionalidades.
13. Ativar serviços Firebase somente quando necessários e aprovados.

## 6. Segredos e segurança

1. Nunca colocar chaves privadas, tokens, senhas, contas de serviço, certificados, keystores ou segredos de backend no código ou no Git.
2. Nunca exibir segredos em comandos, logs, testes, documentação ou mensagens.
3. Usar Google Cloud Secret Manager ou o cofre protegido da CI para segredos de backend.
4. Gerar configurações de cliente Firebase somente com ferramentas oficiais após aprovação; não copiar chaves manualmente.
5. Tratar Security Rules, Authentication e App Check como controles obrigatórios, pois configuração de cliente não protege dados.
6. Aplicar privilégio mínimo a contas, serviços e pipelines.
7. Revisar arquivos ignorados antes do primeiro commit e antes de qualquer publicação.
8. Se um segredo for exposto, interromper o fluxo, informar o incidente e propor revogação e rotação antes de continuar.

## 7. Privacidade e conformidade

1. Tratar dados financeiros como sensíveis.
2. Coletar apenas dados necessários à funcionalidade aprovada.
3. Não registrar valores financeiros, tokens, e-mail ou dados pessoais em logs de diagnóstico.
4. Exigir aprovação para Analytics, publicidade, rastreamento ou compartilhamento com terceiros.
5. Documentar finalidade, retenção, exportação e exclusão dos dados.
6. Considerar LGPD, políticas das lojas e requisitos de exclusão de conta desde o desenho.
7. Manter dados reais fora de testes, emuladores, capturas de tela e documentação.

## 8. Testes e verificação

1. Escrever testes unitários para regras monetárias, validações e casos de uso.
2. Escrever testes de widget para estados e interações relevantes.
3. Escrever testes de integração para jornadas críticas aprovadas.
4. Testar Security Rules no emulador, incluindo acessos negados.
5. Verificar concorrência, modo offline, paginação, fusos horários e limites de moeda conforme o escopo.
6. Usar valores de teste somente na suíte automatizada ou no conjunto de demonstração controlado de `development`; nunca incorporá-los ao aplicativo de produção ou a ambientes reais.
7. Não reduzir ou remover testes para ocultar falhas.
8. Relatar com precisão comandos executados, resultados e verificações que não puderam ser concluídas.

## 9. Critério de conclusão

Uma tarefa somente está concluída quando:

- o comportamento solicitado está integralmente implementado;
- não há código incompleto ou dados simulados no produto;
- não há segredos ou dados reais expostos;
- formatação, análise e testes relevantes foram executados com sucesso;
- regras, índices, documentação e migrações necessários foram atualizados;
- custos, segurança, privacidade e compatibilidade foram considerados;
- limitações remanescentes foram informadas de forma objetiva;
- nenhuma ação externa pendente foi apresentada como concluída.

## 10. Comunicação

1. Explicar antes de qualquer instalação, configuração externa, ação destrutiva ou mudança de custo.
2. Informar suposições e distinguir proposta de requisito aprovado.
3. Apresentar resultados verificáveis e não afirmar sucesso sem evidência.
4. Ao encontrar bloqueio, executar primeiro verificações seguras e de leitura; depois solicitar a decisão mínima necessária.
5. Encerrar cada incremento com resumo dos arquivos alterados, testes executados, riscos e próximo passo autorizado.
