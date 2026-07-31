Quero que você atue como arquiteto de software sênior, desenvolvedor Flutter, especialista em Firebase, segurança, experiência do usuário, inteligência artificial e gestão financeira pessoal.

Crie um aplicativo completo de gerenciamento financeiro pessoal chamado provisoriamente de **Meu Gestor Financeiro**.

Não quero apenas explicações ou exemplos isolados. Quero que você projete e implemente o sistema de forma funcional, organizada, segura, escalável e pronta para testes.

## 1. Objetivo do sistema

O aplicativo deve permitir que o usuário controle:

* rendas mensais;
* rendas extras;
* contas a pagar;
* contas a receber;
* despesas fixas e variáveis;
* financiamentos;
* parcelamentos;
* dívidas;
* vencimentos;
* pagamentos realizados;
* pagamentos atrasados;
* saldo disponível;
* saldo projetado;
* reservas financeiras;
* metas financeiras.

O principal diferencial deve ser uma inteligência artificial que analise a situação financeira do usuário e ofereça orientações personalizadas, como se fosse um gestor financeiro pessoal altamente experiente.

A IA deve ajudar o usuário a evitar atrasos, endividamento excessivo e falta de dinheiro para despesas essenciais.

## 2. Tecnologias obrigatórias

Utilize:

* Flutter com Dart;
* arquitetura limpa e modular;
* Firebase Authentication;
* Cloud Firestore;
* Firebase Cloud Functions;
* Firebase Cloud Messaging;
* Firebase App Check;
* Firebase Crashlytics;
* Firebase Analytics;
* armazenamento seguro local;
* API do Google Gemini para análises financeiras;
* gerenciamento de estado estável e organizado;
* notificações locais no dispositivo;
* suporte a funcionamento offline e sincronização posterior.

O sistema deve ser preparado inicialmente para Android, mas a arquitetura deve permitir publicação futura para Web, Windows e iOS.

Utilize o padrão monetário brasileiro:

* moeda BRL;
* símbolo R$;
* datas em dd/MM/yyyy;
* idioma português do Brasil;
* fuso horário America/Sao_Paulo.

Nunca coloque chaves da API do Gemini diretamente no aplicativo Flutter. As chamadas à inteligência artificial devem passar por uma Cloud Function segura.

## 3. Cadastro e autenticação

Implemente:

* criação de conta;
* login por e-mail e senha;
* login com Google;
* recuperação de senha;
* confirmação de e-mail;
* logout;
* exclusão da conta;
* proteção dos dados por usuário;
* tela de aceite dos termos e política de privacidade.

Cada usuário somente poderá acessar seus próprios dados.

Crie regras completas de segurança do Firestore.

## 4. Cadastro das rendas

Permita cadastrar rendas fixas e extras.

Cada renda deve possuir:

* descrição;
* categoria;
* valor;
* data prevista de recebimento;
* data real de recebimento;
* recorrência;
* status;
* forma de recebimento;
* conta de destino;
* observações;
* comprovante opcional.

Exemplos:

* salário;
* aposentadoria;
* pensão;
* benefício;
* aluguel recebido;
* comissão;
* trabalho extra;
* venda;
* reembolso;
* outras rendas.

Status possíveis:

* previsto;
* recebido;
* atrasado;
* cancelado.

A renda mensal poderá ser recorrente e gerada automaticamente nos meses seguintes.

## 5. Cadastro das contas a pagar

Permita cadastrar:

* água;
* energia elétrica;
* internet;
* telefone;
* aluguel;
* condomínio;
* financiamento;
* cartão de crédito;
* empréstimos;
* escola;
* faculdade;
* transporte;
* alimentação;
* saúde;
* seguros;
* assinaturas;
* impostos;
* pensão;
* outras despesas.

Cada conta deve possuir:

* nome;
* descrição;
* categoria;
* valor previsto;
* valor efetivamente pago;
* data de vencimento;
* data de pagamento;
* recorrência;
* quantidade de parcelas;
* parcela atual;
* prioridade;
* status;
* juros;
* multa;
* desconto;
* forma de pagamento;
* conta utilizada;
* código de barras opcional;
* observações;
* anexo ou comprovante opcional.

Status possíveis:

* pendente;
* pago;
* parcialmente pago;
* atrasado;
* renegociado;
* cancelado.

Prioridades:

* essencial;
* alta;
* média;
* baixa;
* adiável.

As contas recorrentes devem ser geradas automaticamente a cada mês, sem duplicação.

## 6. Contas, carteiras e cartões

Permita cadastrar:

* conta corrente;
* conta poupança;
* dinheiro;
* carteira digital;
* cartão de crédito;
* outras contas.

Para cartões de crédito, permita:

* limite total;
* limite disponível;
* dia de fechamento;
* dia de vencimento;
* compras parceladas;
* valor da fatura atual;
* faturas futuras;
* pagamento integral ou parcial;
* juros estimados;
* melhor dia para compra.

Não implemente integração bancária automática na primeira versão. Utilize lançamentos manuais, deixando a arquitetura preparada para uma futura integração com Open Finance.

## 7. Painel principal

Crie um dashboard claro e fácil de entender.

O painel deve mostrar:

* saldo atual;
* total a receber no mês;
* total a pagar no mês;
* total já recebido;
* total já pago;
* contas vencidas;
* contas que vencem nos próximos dias;
* dinheiro livre depois de pagar as contas;
* saldo projetado até o fim do mês;
* saldo projetado para os próximos meses;
* percentual da renda comprometida;
* valor reservado para emergências;
* evolução das despesas;
* comparação entre receitas e despesas;
* gráfico por categoria;
* calendário financeiro;
* nível de risco financeiro.

Utilize indicadores visuais:

* situação saudável;
* atenção;
* risco;
* situação crítica.

Não dependa somente de cores. Utilize textos e ícones para acessibilidade.

## 8. Linha do tempo financeira

Crie uma linha do tempo que organize cronologicamente:

* saldo atual;
* próximos recebimentos;
* próximos vencimentos;
* saldo depois de cada movimentação.

Exemplo:

Saldo atual: R$ 1.000,00

05/08 — Recebimento de salário: +R$ 2.500,00
Saldo projetado: R$ 3.500,00

07/08 — Conta de energia: -R$ 250,00
Saldo projetado: R$ 3.250,00

10/08 — Aluguel: -R$ 1.200,00
Saldo projetado: R$ 2.050,00

Essa linha do tempo deve identificar antecipadamente o dia em que o saldo poderá ficar negativo.

## 9. Previsão financeira

O sistema deve projetar o fluxo de caixa dos próximos:

* 30 dias;
* 3 meses;
* 6 meses;
* 12 meses.

A projeção deve considerar:

* rendas recorrentes;
* rendas extras previstas;
* contas recorrentes;
* parcelas;
* financiamentos;
* dívidas;
* reajustes informados;
* pagamentos atrasados;
* metas;
* reservas;
* saldo atual.

Exiba:

* menor saldo previsto;
* dias de risco;
* meses com déficit;
* meses com sobra;
* total comprometido;
* capacidade mensal de pagamento;
* valor seguro para gastos não essenciais.

Não apresente valores fictícios. Quando não houver dados suficientes, informe claramente que a previsão possui baixa confiança.

## 10. Recurso “Posso comprar?”

Crie uma ferramenta na qual o usuário informa:

* produto ou serviço;
* valor total;
* valor de entrada;
* quantidade de parcelas;
* valor da parcela;
* data da compra;
* prioridade da compra.

O sistema deve responder:

* se a compra cabe no orçamento;
* quanto sobrará depois da compra;
* se alguma conta ficará em risco;
* qual mês será mais afetado;
* qual seria uma parcela mais segura;
* se é melhor esperar;
* em qual data a compra seria mais segura;
* qual impacto ocorrerá na reserva de emergência.

A resposta deve ser baseada nos dados financeiros reais cadastrados pelo usuário.

## 11. Simulador de cenários

Implemente simulações como:

* perda de parte da renda;
* redução de salário;
* aumento de aluguel;
* surgimento de uma despesa emergencial;
* contratação de financiamento;
* antecipação de dívida;
* redução de gastos;
* criação de reserva de emergência;
* recebimento de renda extra;
* parcelamento de uma conta;
* renegociação de dívida.

A simulação não deve alterar os dados reais até que o usuário confirme.

Exiba uma comparação entre:

* situação atual;
* cenário simulado;
* diferença mensal;
* impacto no saldo;
* impacto nas contas essenciais;
* impacto nas metas.

## 12. Inteligência artificial financeira

Integre a API do Google Gemini por meio de uma Firebase Cloud Function.

A IA deverá receber somente os dados financeiros necessários e estruturados. Evite enviar informações pessoais desnecessárias.

A IA deve analisar:

* receitas;
* despesas;
* datas de vencimento;
* atrasos;
* dívidas;
* juros;
* comprometimento da renda;
* gastos por categoria;
* saldo projetado;
* reserva de emergência;
* comportamento dos últimos meses.

A IA deverá gerar sugestões como:

* contas que devem ser priorizadas;
* gastos que podem ser reduzidos;
* assinaturas pouco utilizadas;
* despesas que aumentaram;
* risco de faltar dinheiro;
* melhor momento para pagar determinada conta;
* possibilidade de antecipar parcelas;
* necessidade de renegociar uma dívida;
* valor possível para reserva;
* metas realistas;
* plano de recuperação financeira.

A IA não deve usar frases genéricas. Toda orientação deve explicar:

* qual problema foi identificado;
* quais dados levaram a essa conclusão;
* qual ação é recomendada;
* qual impacto esperado;
* qual o nível de urgência;
* quais riscos existem;
* quais alternativas estão disponíveis.

A IA nunca deve inventar receitas, despesas, juros, datas ou saldos.

Quando faltarem informações, ela deve dizer exatamente quais dados são necessários.

Não apresente a IA como contador, consultor de investimentos ou profissional legal. Informe que as orientações são educativas e de organização financeira, podendo ser necessária a avaliação de um profissional qualificado em situações complexas.

## 13. Plano anticrise

Quando o sistema detectar que o usuário não terá dinheiro suficiente para pagar tudo, crie automaticamente um plano anticrise.

O plano deve:

1. proteger alimentação, moradia, saúde, água, energia e transporte essencial;
2. separar despesas essenciais das não essenciais;
3. identificar contas que podem gerar corte de serviço;
4. identificar dívidas com juros mais altos;
5. sugerir quais contas devem ser negociadas;
6. sugerir redução ou suspensão de gastos não essenciais;
7. calcular o valor que ainda falta;
8. indicar possíveis datas de recuperação;
9. mostrar como cada ação altera a projeção;
10. apresentar um plano semanal e mensal.

Nunca recomende deixar de pagar uma obrigação sem explicar os possíveis efeitos.

Não recomende empréstimos como primeira solução.

Caso um empréstimo seja analisado, compare:

* custo efetivo;
* juros;
* prazo;
* parcela;
* impacto mensal;
* risco de aumentar o endividamento.

## 14. Estratégias para dívidas

Implemente opções de organização de dívidas:

* método avalanche, priorizando os maiores juros;
* método bola de neve, priorizando as menores dívidas;
* método personalizado, considerando risco e essencialidade.

Mostre:

* tempo estimado para quitação;
* juros estimados;
* valor mensal necessário;
* ordem sugerida;
* economia estimada;
* impacto de pagamentos extras.

Explique as vantagens e desvantagens de cada estratégia.

## 15. Alertas e notificações

Crie alertas configuráveis para:

* conta próxima do vencimento;
* conta vencendo hoje;
* conta atrasada;
* recebimento previsto;
* renda não recebida;
* saldo projetado negativo;
* limite do cartão próximo do máximo;
* gasto acima da média;
* orçamento de categoria excedido;
* meta atrasada;
* risco financeiro crítico.

Permita alertas:

* 10 dias antes;
* 7 dias antes;
* 3 dias antes;
* 1 dia antes;
* no dia do vencimento;
* depois do atraso.

Utilize notificações locais e Firebase Cloud Messaging.

As Cloud Functions devem verificar periodicamente os vencimentos e gerar notificações sem duplicação.

## 16. Orçamentos por categoria

Permita definir limites mensais para categorias como:

* alimentação;
* transporte;
* lazer;
* saúde;
* compras;
* assinaturas;
* educação.

Exiba:

* orçamento definido;
* valor utilizado;
* valor disponível;
* percentual consumido;
* previsão até o fim do mês.

Avise quando atingir:

* 70%;
* 90%;
* 100%;
* valor acima do limite.

## 17. Metas financeiras

Permita criar metas como:

* reserva de emergência;
* quitar uma dívida;
* comprar um produto;
* fazer uma viagem;
* pagar um curso;
* trocar de veículo;
* formar uma entrada;
* organizar despesas anuais.

Cada meta deve possuir:

* nome;
* valor total;
* valor acumulado;
* prazo;
* prioridade;
* contribuição mensal;
* progresso;
* conta vinculada.

O sistema deve calcular se a meta é viável e sugerir uma contribuição compatível com a renda disponível.

## 18. Relatórios

Crie relatórios de:

* receitas por período;
* despesas por período;
* despesas por categoria;
* contas pagas;
* contas atrasadas;
* dívidas;
* cartões;
* evolução do saldo;
* comparação entre meses;
* orçamento previsto versus realizado;
* projeção futura;
* evolução das metas;
* recomendações geradas pela IA.

Permita filtros por:

* dia;
* semana;
* mês;
* ano;
* categoria;
* conta;
* status.

Permita exportar dados em:

* PDF;
* CSV;
* planilha compatível com Excel.

## 19. Estrutura sugerida do Firestore

Crie uma estrutura segura e escalável semelhante a:

users/{userId}

users/{userId}/accounts/{accountId}

users/{userId}/incomes/{incomeId}

users/{userId}/expenses/{expenseId}

users/{userId}/creditCards/{cardId}

users/{userId}/creditCardInvoices/{invoiceId}

users/{userId}/installments/{installmentId}

users/{userId}/debts/{debtId}

users/{userId}/budgets/{budgetId}

users/{userId}/goals/{goalId}

users/{userId}/notifications/{notificationId}

users/{userId}/financialAnalyses/{analysisId}

users/{userId}/simulations/{simulationId}

users/{userId}/categories/{categoryId}

Para cada coleção, defina:

* modelo Dart;
* campos;
* tipos;
* campos obrigatórios;
* índices;
* validações;
* conversores;
* datas de criação e atualização;
* identificação do usuário;
* regras de leitura e gravação.

Utilize timestamps do servidor quando necessário.

## 20. Cloud Functions

Crie funções para:

* gerar contas recorrentes;
* gerar rendas recorrentes;
* atualizar status de contas vencidas;
* calcular projeções;
* verificar alertas;
* enviar notificações;
* processar análises pelo Gemini;
* controlar limite de solicitações;
* registrar auditoria;
* impedir chamadas abusivas;
* excluir dados do usuário de forma segura;
* processar exportações;
* gerar resumos financeiros mensais.

As funções devem ser idempotentes, evitando duplicações.

## 21. Segurança e privacidade

Implemente:

* Firebase App Check;
* regras restritivas do Firestore;
* validação no aplicativo e no servidor;
* proteção de chaves e segredos;
* limitação de requisições;
* sanitização de entradas;
* logs sem dados financeiros sensíveis;
* exclusão completa da conta;
* opção de exportação dos dados;
* política de retenção;
* consentimento para uso da IA;
* opção de não utilizar análise por IA;
* proteção contra acesso de outro usuário;
* tratamento seguro de anexos.

Nenhuma chave secreta deve ficar no código Flutter ou no repositório público.

Utilize variáveis de ambiente ou gerenciamento seguro de segredos nas Cloud Functions.

## 22. Experiência do usuário

A interface deve ser simples para pessoas que não possuem conhecimentos de contabilidade.

Utilize textos como:

* dinheiro que entrou;
* dinheiro que vai entrar;
* contas a pagar;
* contas pagas;
* dinheiro livre;
* risco de faltar dinheiro.

Evite termos contábeis complexos sem explicação.

Inclua:

* modo claro e escuro;
* acessibilidade;
* tamanhos de fonte ajustáveis;
* máscaras monetárias;
* confirmação antes de excluir;
* filtros;
* pesquisa;
* telas vazias orientativas;
* mensagens de erro compreensíveis;
* tutorial inicial;
* dados de demonstração opcionais.

## 23. Telas necessárias

Crie pelo menos:

1. tela de abertura;
2. apresentação inicial;
3. login;
4. cadastro;
5. recuperação de senha;
6. dashboard;
7. calendário financeiro;
8. linha do tempo do saldo;
9. lista de receitas;
10. cadastro de receita;
11. lista de despesas;
12. cadastro de despesa;
13. contas vencidas;
14. contas e carteiras;
15. cartões;
16. faturas;
17. dívidas;
18. parcelamentos;
19. orçamentos;
20. metas;
21. simulador;
22. tela “Posso comprar?”;
23. assistente financeiro com IA;
24. recomendações;
25. plano anticrise;
26. relatórios;
27. notificações;
28. configurações;
29. perfil;
30. privacidade e consentimentos.

## 24. Regras de cálculo

Centralize os cálculos financeiros em serviços próprios e crie testes automatizados.

Considere:

saldo atual = soma dos saldos das contas.

saldo projetado = saldo atual + receitas previstas - despesas previstas.

dinheiro livre = receitas recebidas e previstas confiáveis - despesas essenciais - contas pendentes - compromissos reservados.

percentual de renda comprometida = despesas obrigatórias ÷ renda mensal confiável × 100.

Não trate limite de cartão de crédito como dinheiro disponível.

Não some transferências entre contas como nova renda ou nova despesa.

Não considere uma renda apenas prevista como garantida. Permita ao usuário informar o nível de confiança da renda.

Diferencie:

* saldo bancário;
* saldo projetado;
* dinheiro reservado;
* dinheiro realmente livre para gastar.

## 25. Testes

Crie:

* testes unitários;
* testes de widgets;
* testes de integração;
* testes dos cálculos;
* testes das regras do Firestore;
* testes das Cloud Functions;
* testes de recorrência;
* testes contra lançamentos duplicados;
* testes de fuso horário;
* testes de arredondamento monetário;
* testes para meses com diferentes quantidades de dias.

Não utilize números de ponto flutuante de forma que gere erros monetários. Armazene valores monetários em centavos inteiros ou utilize uma estratégia segura equivalente.

## 26. Entrega por etapas

Desenvolva na seguinte ordem:

### Etapa 1 — Planejamento

Apresente:

* arquitetura;
* estrutura de pastas;
* entidades;
* fluxo de navegação;
* modelo de dados;
* regras de negócio;
* dependências necessárias.

### Etapa 2 — Projeto base

Gere:

* projeto Flutter;
* configuração do Firebase;
* temas;
* rotas;
* gerenciamento de estado;
* tratamento de erros;
* autenticação.

### Etapa 3 — Controle financeiro principal

Implemente:

* contas;
* receitas;
* despesas;
* recorrências;
* dashboard;
* calendário;
* projeção de saldo.

### Etapa 4 — Recursos avançados

Implemente:

* cartões;
* parcelamentos;
* dívidas;
* orçamentos;
* metas;
* simuladores;
* notificações.

### Etapa 5 — Inteligência artificial

Implemente:

* Cloud Function segura;
* integração com Gemini;
* análises;
* recomendações;
* plano anticrise;
* histórico de análises.

### Etapa 6 — Relatórios e segurança

Implemente:

* relatórios;
* exportação;
* regras de segurança;
* App Check;
* testes;
* documentação.

## 27. Forma de resposta obrigatória

Não entregue todo o projeto em um único bloco incompleto.

Primeiro apresente:

1. arquitetura recomendada;
2. estrutura de pastas;
3. tecnologias e bibliotecas;
4. modelo completo do Firestore;
5. lista das telas;
6. fluxo do usuário;
7. regras dos cálculos;
8. plano de implementação.

Depois comece a gerar os arquivos em ordem.

Para cada arquivo, informe:

* caminho completo;
* finalidade;
* código completo;
* dependências relacionadas;
* comandos necessários.

Não utilize códigos fictícios, trechos com “...” ou comentários como “implementar depois”.

Quando um arquivo for alterado, sempre apresente a versão completa e atualizada.

Antes de avançar para outra etapa:

* verifique imports;
* verifique nomes de classes;
* verifique dependências;
* verifique compatibilidade entre os arquivos;
* verifique regras de segurança;
* verifique possíveis chaves duplicadas no pubspec.yaml;
* informe os comandos exatos para executar no Windows PowerShell.

Considere que o desenvolvimento será realizado no Windows com Visual Studio Code.

Utilize comandos compatíveis com PowerShell. Não utilize “&&” para encadear comandos. Apresente cada comando em sua própria linha.

## 28. Resultado esperado

O resultado deve ser um aplicativo financeiro pessoal funcional que:

* ajude o usuário a saber o que pode pagar;
* mostre quanto dinheiro realmente estará disponível;
* antecipe períodos de dificuldade;
* evite atrasos;
* ajude a reorganizar dívidas;
* gere alertas;
* sugira ações práticas;
* permita testar decisões antes de tomá-las;
* mantenha os dados protegidos;
* funcione de maneira simples para usuários sem experiência financeira.

Comece agora pela arquitetura completa, estrutura do Firestore, regras de negócio, estrutura de pastas e planejamento da primeira versão funcional.

## 29. Decisões funcionais e técnicas complementares aprovadas

As decisões abaixo complementam e detalham as seções anteriores. Em caso de dúvida, estas regras específicas prevalecem sobre propostas anteriores de planejamento.

### 29.1 Dados de demonstração

Dados de demonstração são permitidos somente no ambiente development e em testes automatizados.

Eles devem:

* estar desativados por padrão;
* nunca ser enviados ao Firebase de produção;
* nunca conter dados pessoais reais;
* ser ativados somente por configuração explícita de desenvolvimento;
* poder ser apagados completamente.

Nenhum dado fictício será exibido no aplicativo de produção.

### 29.2 Contas a receber

Contas a receber são uma entidade separada de rendas e usam a coleção:

users/{userId}/receivables/{receivableId}

Uma conta a receber pode representar venda, empréstimo feito a outra pessoa, reembolso, aluguel, serviço realizado, valor parcelado a receber ou outros créditos.

Campos obrigatórios ou previstos:

* descrição;
* devedor ou origem opcional;
* categoria;
* valor total;
* valor recebido;
* valor restante;
* data prevista;
* data efetiva;
* parcelas;
* status;
* prioridade;
* observações;
* anexo opcional.

Status:

* previsto;
* parcialmente recebido;
* recebido;
* atrasado;
* renegociado;
* cancelado.

Quando houver recebimento, o sistema criará ou vinculará um lançamento de renda, sem duplicar o valor.

### 29.3 Reserva financeira

A reserva financeira é uma meta vinculada a uma conta. A fonte oficial é composta pelos movimentos da meta.

O valor reservado na conta é apenas resumo derivado e reconstruível, nunca uma segunda fonte de verdade.

O dinheiro reservado:

* continua fazendo parte do saldo bancário;
* não é considerado dinheiro livre;
* pode ser usado em simulações;
* somente é liberado mediante confirmação do usuário.

### 29.4 Confiança das rendas previstas

Níveis iniciais:

* confirmada: peso de 100%;
* alta: peso de 80%;
* média: peso de 50%;
* baixa: peso de 20%.

O sistema exibe:

* projeção nominal, usando todos os valores previstos;
* projeção conservadora, aplicando os pesos de confiança.

Renda cancelada ou atrasada sem nova previsão tem peso de 0%. Os pesos ficam centralizados e configuráveis, sem números espalhados pelo código.

### 29.5 Níveis de risco financeiro

As regras são determinísticas e explicáveis.

Crítico:

* saldo atual negativo;
* saldo projetado negativo nos próximos 30 dias;
* despesa essencial atrasada;
* ausência de dinheiro para alimentação, moradia, saúde, água, energia ou transporte essencial.

Risco:

* saldo projetado negativo entre 31 e 90 dias;
* mais de 90% da renda confiável comprometida;
* utilização do cartão acima de 90%;
* dívida atrasada com juros elevados.

Atenção:

* entre 70% e 90% da renda comprometida;
* dinheiro livre menor que 10% da renda confiável;
* orçamento de categoria acima de 90%;
* ausência de reserva de emergência.

Saudável:

* nenhuma condição crítica, de risco ou atenção identificada.

Quando mais de uma condição existir, prevalece o nível mais grave. O sistema sempre informa os fatos que causaram a classificação.

### 29.6 Recorrências nos dias 29, 30 e 31

Quando o dia configurado não existir no mês, a ocorrência é gerada no último dia desse mês. Isso inclui dia 31 em fevereiro, dia 31 em abril e dia 30 em fevereiro.

A geração usa America/Sao_Paulo, competência mensal e chave idempotente.

### 29.7 Fechamento de cartão

Compras realizadas antes do dia de fechamento entram na fatura atual. Compras realizadas no dia do fechamento ou depois entram na próxima fatura.

O melhor dia de compra é inicialmente o dia seguinte ao fechamento. O usuário pode corrigir manualmente a fatura de uma compra quando a administradora aplicar regra diferente.

### 29.8 Juros, multas e descontos

O sistema nunca inventa taxas.

Juros, multas, descontos, custo efetivo e taxas são:

* informados pelo usuário;
* obtidos de regra cadastrada;
* ou marcados como desconhecidos.

Quando a taxa for desconhecida, o sistema informa que não é possível calcular o custo com precisão. Taxas são armazenadas em pontos-base inteiros.

### 29.9 Pagamentos parciais

Cada pagamento parcial possui registro próprio e imutável.

O sistema calcula:

* total pago;
* valor restante;
* data de cada pagamento;
* conta utilizada;
* juros e multas informados;
* status atualizado.

Pagamentos não são sobrescritos. Correções ocorrem por cancelamento ou lançamento compensatório auditável.

### 29.10 Gasto acima da média

A média usa os três meses completos anteriores da mesma categoria.

O alerta é gerado quando:

* o gasto ultrapassar a média em pelo menos 20%;
* e a diferença for de pelo menos R$ 50,00.

Os parâmetros são configuráveis. Sem três meses completos, o sistema informa que não há histórico suficiente.

### 29.11 Assinaturas pouco utilizadas

Sem integração com o fornecedor, o sistema não afirma que uma assinatura não está sendo utilizada.

Ele identifica despesas recorrentes classificadas como assinatura e pergunta periodicamente:

“Você ainda utiliza esta assinatura?”

Somente após resposta do usuário pode sugerir cancelamento ou manutenção.

### 29.12 Política offline e conflitos

Consultas e novos cadastros podem funcionar offline.

Transferências, pagamentos, recebimentos, cancelamentos e aplicação de simulações podem ser preparados offline, mas somente são confirmados depois da sincronização com o servidor.

O sistema usa:

* versão do documento;
* updatedAt;
* operações atômicas;
* chaves idempotentes;
* detecção de edição concorrente.

Não existe last-write-wins silencioso. Em conflito, o aplicativo apresenta as versões e solicita confirmação.

### 29.13 Aplicação de simulações

Uma simulação nunca altera dados reais automaticamente.

Antes da aplicação, o sistema mostra:

* operações que serão criadas;
* operações que serão alteradas;
* impacto nos saldos;
* impacto nas projeções;
* impacto nas metas.

Após confirmação explícita, a aplicação ocorre de forma atômica e auditável.

### 29.14 Anexos

Está aprovado o uso futuro do Firebase Cloud Storage para comprovantes e anexos.

Regras iniciais:

* formatos permitidos: PDF, JPEG e PNG;
* tamanho máximo: 10 MB por arquivo;
* no máximo cinco anexos por entidade;
* validação de extensão, MIME type e assinatura básica;
* proibição de executáveis e arquivos compactados;
* nomes sem dados pessoais;
* acesso somente pelo proprietário;
* nenhuma URL pública permanente;
* exclusão conforme a política de retenção.

A ativação do Storage e do faturamento exige autorização separada.

### 29.15 Exportações

Na primeira versão:

* CSV é gerado localmente no aparelho;
* planilha compatível com Excel é gerada localmente;
* PDF é gerado localmente quando o relatório couber com segurança na memória do dispositivo.

Dados financeiros não são enviados ao Cloud Storage apenas para exportação. Exportações muito grandes podem futuramente usar Cloud Function, mediante nova aprovação.

### 29.16 Gemini

A integração:

* usa Cloud Function;
* exige Authentication e App Check;
* usa resposta estruturada e validada;
* possui limite de uso por usuário;
* possui timeout;
* possui controle de custo;
* nunca envia anexos, e-mail, nome, CPF ou identificadores desnecessários;
* nunca armazena prompt bruto;
* guarda somente resultado estruturado, versão do modelo, hash dos dados e informações técnicas permitidas.

O modelo Gemini é configurável por variável de ambiente ou segredo e não fica fixo no aplicativo.

Configuração inicial:

* limite configurável de 10 análises por usuário por dia;
* saída curta e estruturada;
* no máximo aproximadamente 2.000 tokens de resposta;
* região compatível com a arquitetura Firebase escolhida.

A escolha definitiva do modelo ocorre na implementação, usando modelo estável oficialmente suportado.

### 29.17 Plano anticrise

O plano anticrise usa modelo híbrido.

Decisões financeiras, cálculos, prioridades e valores são produzidos por regras determinísticas.

O Gemini pode:

* explicar resultados;
* organizar o plano em linguagem acessível;
* apresentar alternativas;
* fazer perguntas sobre dados ausentes.

O Gemini não pode:

* modificar cálculos;
* mudar prioridades essenciais;
* criar receitas ou despesas;
* executar pagamentos;
* aplicar decisões automaticamente.

### 29.18 Analytics, Crashlytics e consentimentos

Analytics permanece desativado até consentimento ou decisão jurídica aprovada. O usuário pode retirar o consentimento.

Eventos Analytics nunca contêm valores financeiros, descrições, nomes de contas, e-mails, dados pessoais, dívidas ou saldos.

Crashlytics remove dados pessoais e financeiros dos logs.

A IA exige consentimento específico e separado. A recusa da IA não impede o uso das funções financeiras normais.

### 29.19 Retenção e exclusão

Retenção inicial:

* análises estruturadas da IA: 90 dias;
* auditoria técnica sem dados financeiros: 180 dias;
* notificações antigas: 90 dias;
* exportações locais: sob controle do usuário;
* anexos: enquanto vinculados a entidade ativa;
* anexos órfãos: remoção programada após 30 dias.

Ao excluir a conta:

* exigir reautenticação;
* interromper novas operações;
* excluir dados ativos;
* remover anexos;
* revogar dispositivos;
* registrar apenas o mínimo técnico permitido;
* informar quando backups deixarem de conter os dados conforme a política vigente.

A política jurídica final será revisada antes da publicação.

### 29.20 Backups

Backups de produção são planejados com retenção inicial de 30 dias.

Antes do lançamento:

* documentar restauração;
* executar teste de restauração;
* restringir acesso;
* registrar custos;
* definir quem pode autorizar restauração.

Backups pagos não serão ativados sem autorização.

### 29.21 Notificações na tela bloqueada

Por padrão, a tela bloqueada usa texto genérico:

“Você possui um novo alerta financeiro.”

Valores, nomes de contas, dívidas, saldos e descrições aparecem somente depois que o usuário abre o aplicativo autenticado.

O usuário pode aumentar o nível de detalhe após aviso de privacidade.

### 29.22 Faturamento Firebase

A arquitetura pode considerar o plano Blaze para Cloud Functions, Storage, tarefas agendadas e Gemini.

O faturamento não será ativado nesta etapa.

Antes da ativação:

* estimar custos;
* configurar alertas de orçamento;
* separar development e production;
* obter autorização explícita.

### 29.23 Identificador do aplicativo

O identificador definitivo do aplicativo Android é `br.com.hellenfaro.meugestorfinanceiro`.

A aprovação do identificador não autoriza a criação do projeto Flutter, a instalação de ferramentas, a configuração do Firebase nem qualquer outra implementação. Essas ações continuam dependentes de autorização explícita.

## 30. Decisões aprovadas para o Projeto Base

### 30.1 Identidade do projeto

O identificador definitivo do aplicativo Android é `br.com.hellenfaro.meugestorfinanceiro`.

O nome interno do projeto Flutter é `meu_gestor_financeiro`.

O nome exibido do aplicativo é **Meu Gestor Financeiro**.

### 30.2 Estratégia de saldo

A fonte oficial do saldo é:

saldo inicial da conta
+ entradas confirmadas
- saídas confirmadas
+ transferências recebidas
- transferências enviadas.

Nenhum campo de saldo materializado é fonte canônica.

Resumos, saldos calculados e `monthlySummaries` são caches derivados, protegidos e totalmente reconstruíveis.

### 30.3 Confirmação de e-mail

Antes da confirmação do e-mail, o usuário pode somente:

- acessar a tela de confirmação;
- reenviar o e-mail de confirmação;
- atualizar o estado da confirmação;
- sair da conta;
- excluir a conta;
- consultar termos e política de privacidade.

Não é permitido cadastrar ou alterar dados financeiros antes da confirmação.

Contas autenticadas pelo Google podem ser consideradas verificadas quando o Firebase Authentication informar `emailVerified=true`.

### 30.4 Reajustes

Reajustes podem ser:

- valor fixo;
- percentual.

Todo reajuste possui:

- tipo;
- valor ou percentual;
- data inicial de vigência;
- descrição;
- entidade relacionada.

O reajuste é aplicado apenas às ocorrências futuras.

Aplicação retroativa exige confirmação explícita do usuário e gera operações auditáveis.

### 30.5 Formas de recebimento

Enumeração inicial:

- pix;
- transferência bancária;
- dinheiro;
- cartão;
- boleto;
- cheque;
- outro.

### 30.6 Formas de pagamento

Enumeração inicial:

- pix;
- transferência bancária;
- dinheiro;
- cartão de débito;
- cartão de crédito;
- boleto;
- débito automático;
- outro.

### 30.7 Portões adiados

As decisões seguintes não bloqueiam a criação da base do projeto e permanecem como portões das respectivas etapas:

- modelo Gemini definitivo: decidir na Etapa 5;
- região e projetos Firebase: decidir antes da configuração Firebase;
- Storage, Blaze e backups pagos: exigem autorização separada;
- textos jurídicos: concluir antes da publicação;
- pesos do método personalizado de dívidas: decidir antes desse módulo;
- fórmula do rotativo: decidir antes do módulo de cartões;
- limiar de juros elevados: decidir antes do plano de dívidas;
- catálogo Analytics: decidir antes da ativação do Analytics.

### 30.8 Autorização limitada da Etapa 2

Está autorizada somente a fundação local da Etapa 2: repositório Git no diretório do projeto, `.gitignore`, projeto Flutter apenas Android, estrutura modular, dependências fundamentais aprovadas, tema, localização, rotas, erros tipados, ambientes, objetos de valor monetários, análise estática e testes correspondentes.

Continuam proibidos nesta etapa: Firebase CLI, FlutterFire CLI, configuração ou criação de projetos Firebase, Gemini, Storage, Blaze, Analytics, Crashlytics, deploy, commit, push e publicação.
