# Matriz de ações por entidade

Estado auditado no incremento `CRUD-AUDIT-1`, em 24/08/2026. A matriz usa o código e os testes como fonte de verdade. `Servidor` indica uma operação que nunca pode ser executada diretamente pelo cliente.

Legenda: `Sim` = ação disponível; `Cond.` = ação condicionada pelas invariantes indicadas; `Servidor` = somente backend administrativo/auditável; `—` = ação deliberadamente inexistente.

| ID | Entidade | Cadastrar | Visualizar | Editar | Excluir | Arquivar | Cancelar | Anular | Restaurar | Tela ou responsável | Regra de integridade |
|---|---|---|---|---|---|---|---|---|---|---|---|
| AUTH | Usuário Firebase Authentication | Sim | Sim | Cond. | Servidor | — | — | — | — | Autenticação e Dados e privacidade | exclusão definitiva exige operação de privacidade confirmada; não existe restauração |
| PROFILE | Perfil jurídico | Sim | Sim | Sim | Servidor | — | — | — | — | Perfil | removido somente com a conta; owner não acessa outro UID |
| CONSENT | Consentimentos jurídicos | Sim | Sim | Sim | Servidor | — | — | — | — | Perfil e atualização legal | versões aceitas são auditáveis; remoção somente com a conta |
| APPEARANCE | Preferência visual do dispositivo | Sim | Sim | Sim | Sim | — | — | — | Sim | Aparência | reset financeiro preserva; exclusão pode preservar a preferência do dispositivo |
| ACCOUNT | Conta/carteira financeira | Sim | Sim | Sim | — | Sim | — | — | Sim | Contas e carteiras; detalhes | saldo é derivado; histórico impede exclusão física |
| CATEGORY | Categoria financeira | Sim | Sim | Sim | — | Sim | — | — | Sim | Categorias; arquivadas | lançamentos históricos preservam a referência |
| TRANSACTION | Lançamento financeiro | Sim | Sim | Cond. | — | — | — | Sim | — | Lançamentos; detalhes | somente descrição é corrigível; anulação é irreversível e saldo é recalculado |
| PAYABLE | Conta a pagar | Sim | Sim | Cond. | — | — | Sim | Cond. | — | Contas a pagar; detalhes | pendência não afeta saldo; pagar cria um lançamento; liquidação pode ser anulada atomicamente |
| RECEIVABLE | Conta a receber | Sim | Sim | Cond. | — | — | Sim | Cond. | — | Contas a receber; detalhes | pendência não afeta saldo; receber cria um lançamento; liquidação pode ser anulada atomicamente |
| INV_PORTFOLIO | Carteira de investimentos | Sim | Sim | Sim | Cond. | Sim | — | — | Sim | Investimentos; gerenciar carteiras | exclusão somente em schema 2 sem qualquer histórico, após arquivar e revalidar no servidor |
| INV_ASSET | Ativo acompanhado | Sim | Sim | Cond. | Cond. | Sim | — | — | Sim | Ativos; detalhes; formulário | ticker é identidade imutável; tipo só muda sem histórico; nome pode ser corrigido; exclusão somente em schema 2 sem operação ou provento |
| INV_OPERATION | Operação de investimento | Sim | Sim | — | — | — | — | Cond. | — | Lançamentos do ativo | apenas a última operação válida pode ser anulada; projeção do ativo muda atomicamente |
| INV_INCOME | Provento | Sim | Sim | Cond. | — | — | Cond. | Cond. | — | Proventos; formulário | esperado pode ser editado/cancelado; recebido pode ser anulado; histórico é preservado |
| MARKET_QUOTE | Snapshot global de cotação | Servidor | Cond. | Servidor | Servidor | — | — | — | — | Cotações | cliente não escreve; snapshot antigo nunca substitui novo; recurso externo ainda desativado |
| CALCULATION | Simulação e análise manual | — | Sim | Sim | Sim | — | — | — | — | Calculadoras e análises | estado efêmero local; não persiste nem altera saldo, posição ou provento |
| PRIVACY_OPERATION | Operação de reset/exclusão | Servidor | Cond. | Servidor | — | — | — | — | — | Dados e privacidade | cliente prepara/confirma por callable futura; operação é idempotente e não restaurável |
| PRIVACY_LOCK | Bloqueio de privacidade | Servidor | — | Servidor | Servidor | — | — | — | — | Backend de privacidade | cliente não lê ou escreve; bloqueia mutações pendentes conforme o escopo |
| PRIVACY_RECEIPT | Recibo anônimo | Servidor | — | — | Servidor | — | — | — | — | Backend de privacidade | sem UID/e-mail/valores; retenção planejada de 30 dias |
| ENTITLEMENT | Entitlement comercial histórico | Servidor | Cond. | Servidor | Servidor | — | — | — | — | infraestrutura inativa | FREE-1 removeu toda participação no runtime ativo |
| CLOSED_TEST | Diretório e concessão de teste fechado | Servidor | — | Servidor | Servidor | — | — | — | — | infraestrutura inativa | não concede acesso no runtime FREE-1 e nunca autoriza acesso cruzado |
| OWNER | Registro de acesso proprietário | Servidor | Cond. | Servidor | Servidor | — | — | — | — | área proprietária | libera capabilities administrativas próprias, nunca dados financeiros de outro UID |

## Convenção visual e semântica

- Ação iconográfica primária usa os símbolos canônicos: lápis para editar, lixeira para excluir, caixa para arquivar e caixa aberta para restaurar.
- Todo botão apenas com ícone deve ter tooltip e rótulo semântico específicos, como “Excluir PETR4”, e área de toque fornecida por `IconButton`.
- A lixeira só aparece quando existe uma exclusão real. Cancelar, anular e arquivar nunca usam lixeira.
- Exclusão permanente exige confirmação que descreve consequências. Quando a digitação reduz risco material, exige a frase exata aprovada.
- Ações em andamento ficam desabilitadas para impedir múltiplos toques e respostas tardias não podem apresentar sucesso.
- Menus contextuais agrupam ações secundárias, principalmente arquivar/restaurar. Ações principais frequentes permanecem visíveis.
- Botões com texto mantêm verbo explícito e ícone coerente. Tooltip é obrigatório para controles somente com ícone; o texto visível já fornece o nome acessível nos demais.

## Auditoria de telas

As jornadas auditadas incluem autenticação, verificação de e-mail, perfil, consentimentos, aparência, Home, contas, categorias, lançamentos, compromissos, investimentos, carteiras, ativos, operações, proventos, cotações, calculadoras/análises, owner e dados/privacidade. Telas somente de leitura não recebem ações destrutivas artificiais. Infraestruturas Premium e de teste fechado permanecem inativas e não aparecem no fluxo FREE-1.

O teste estrutural da matriz exige todas as entidades acima e verifica os contratos de ação mais sensíveis. Testes de domínio, repositório, widgets e Security Rules comprovam as condições; a matriz não substitui essas suítes.
