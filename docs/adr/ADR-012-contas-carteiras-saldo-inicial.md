# ADR-012 — Contas, carteiras e saldo inicial

- Status: aceito, regras publicadas em development e fluxo validado manualmente
- Data: 01/08/2026

## Contexto

A Etapa 4A introduz o primeiro núcleo financeiro depois de Authentication, perfil e consentimentos. O incremento precisa preservar isolamento por usuário, precisão monetária e recuperação segura sem antecipar transações ou cartões.

## Decisão

- Contas ficam em `users/{uid}/accounts/{accountId}`.
- O ID é gerado sem dados pessoais e não é duplicado no documento.
- Valores são centavos inteiros BRL entre -9.999.999.999 e 9.999.999.999 por conta.
- Não existe `currentBalanceCents`; nesta etapa, saldo exibido é saldo inicial.
- O total soma saldos iniciais somente de contas ativas incluídas.
- Tipos são checking, savings, cash, digitalWallet, investment e other.
- Cartão de crédito não é conta e permanece fora do incremento.
- Arquivamento reversível substitui exclusão permanente.
- Criação reutiliza ID na tentativa e exige confirmação por leitura do servidor.
- Acesso exige Auth verificado, perfil válido, termos atuais e UID próprio, tanto nos controllers quanto nas regras.
- Regras usam campos exatos, transições pareadas e negação por padrão.
- Não existem transações, transferências, receitas, despesas ou ajustes nesta etapa.
- Consulta é limitada à subcoleção própria, sem collectionGroup ou índice composto.
- Regras serão publicadas manualmente pelo proprietário apenas em development.
- Testes reais no Emulator Suite continuam pendentes por falta de autorização.

## Consequências

O modelo é pequeno, auditável e sem saldo duplicado. A confirmação por servidor acrescenta leituras, mas evita apresentar cache ou escrita pendente como sucesso. O total local é adequado ao volume pessoal inicial. Antes de movimentos, a edição do saldo inicial é permitida; depois, deverá ser bloqueada ou representada por ajuste auditável. Sem Emulator Suite, a matriz de regras não pode ser declarada executada.

## Alternativas rejeitadas

- saldo materializado como fonte canônica: risco de divergência;
- cartão dentro de accounts: mistura limite de crédito com dinheiro;
- exclusão definitiva: perda de histórico e recuperação;
- nomes como IDs: colisões, mutabilidade e exposição;
- ponto flutuante: perda de precisão monetária;
- publicação automática: fora da autorização do proprietário.
