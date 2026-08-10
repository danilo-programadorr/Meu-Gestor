# ADR-018 — INV-PROV-1 proventos manuais

## Status

Aceita em 10/08/2026. Implementação e validações concluídas; Security Rules compiladas e publicadas com sucesso exclusivamente em development, sem acesso a production, com SHA-256 `8B689BA72FE05B1C04409E00083644D83B2EEACFDDA67A7C8D003B843E102FBE`. O APK debug development foi gerado e aprovado manualmente; commit e push permaneciam pendentes nesta atualização documental.

## Contexto

O acompanhamento de ações e FIIs precisava registrar proventos conhecidos pelo usuário sem introduzir cotação, agenda externa, cálculo tributário ou impacto no núcleo financeiro. O registro deve suportar previsão, confirmação, cancelamento e correção auditável, inclusive diante de timeout e concorrência.

## Decisão

- usar `users/{uid}/investmentIncomeEvents/{eventId}`, separada de operações, lançamentos e compromissos;
- aceitar `dividend` e `jcp` para ações e `fiiIncome` para FIIs;
- iniciar em `expected`, permitir `expected -> received|cancelled` e `received -> voided`, sem restauração ou exclusão;
- permitir edição financeira somente em `expected`; recebimento e anulação preservam valores, referências, data prevista e data efetiva;
- representar dinheiro em centavos, quantidade em escala 8 e valor unitário em escala 6; calcular bruto com `BigInt` e half-up e derivar líquido como bruto menos imposto retido informado;
- usar data civil de `America/Sao_Paulo`; previsão pode ser futura, recebimento efetivo não;
- exigir carteira e ativo próprios e ativos, campos exatos, perfil jurídico atual, e-mail verificado, revisão crescente, `mutationId` novo e timestamps do servidor;
- confirmar toda escrita por releitura server-only; em resultado incerto, reutilizar evento/mutação para reconciliar sem duplicar;
- apresentar uma quarta aba responsiva, sem dados fictícios, com privacidade global, filtros e agregações calculadas apenas dos eventos confirmados;
- não criar `transaction`, não referenciar `account` e não alterar posição, saldo ou resumo mensal.

`originType` e `externalId` já fazem parte do esquema fechado. Uma futura origem automática poderá reutilizar os mesmos documentos e transições por nova versão compatível, sem migração destrutiva dos registros manuais; nenhum provedor é aceito nesta versão.

## Consequências

O usuário pode acompanhar proventos reais informados por ele e corrigir o histórico por anulação, sem confundir acompanhamento patrimonial com dinheiro disponível. Cada mutação relevante custa uma escrita e uma releitura de confirmação; o workspace acrescenta uma consulta à coleção de proventos. Histórico e gráficos são agregados localmente e ainda não têm paginação.

Agenda automática, amortização, eventos corporativos, cálculo de imposto devido, DARF, compensações, múltiplas moedas, recorrência, notificações e integração com o núcleo financeiro permanecem fora do escopo. A proposta de integração B3 e de integrações automáticas com corretoras foi cancelada por decisão do responsável pelo projeto: não é requisito, limitação pendente ou incremento futuro, e não autoriza implementação, pesquisa técnica nem preparação arquitetural. A futura cotação de mercado com atraso por provedor de dados independente não depende de integração B3 e permanece uma decisão separada.
