# ADR-034 — ASSIST-1A: interface local e resumos determinísticos

## Estado

Aceita em 25/08/2026 e implementada somente localmente.

## Contexto

O ASSIST-0 definiu a fronteira segura para uma integração futura com IA, mas não oferecia experiência no aplicativo. Conectar um provedor antes da decisão jurídica, técnica e comercial criaria risco desnecessário de exposição de dados. Ao mesmo tempo, o aplicativo já possui agregados financeiros reais e confirmados que podem responder perguntas objetivas sem modelo generativo.

## Decisão

1. O Assistente passa a ter rota própria e acesso pelo menu da Home.
2. A experiência inicial contém apenas perguntas guiadas e resumos calculados por regras determinísticas do domínio.
3. Sem consentimento opcional ativo, a tela não observa providers financeiros. O escopo permanece visível e a pessoa pode gerenciar a preferência existente.
4. Com consentimento, somente estados do próprio usuário confirmados pelo servidor entram nos resumos. Fonte ausente é exibida como indisponível e nenhum valor é estimado.
5. Cada resposta informa período civil de `America/Sao_Paulo`, fontes e premissas. Dinheiro permanece em centavos inteiros.
6. Privacidade global oculta valores e contagens. A tela é somente leitura, não aceita texto livre, não produz recomendação e não possui memória.
7. Nenhuma API de IA, Function, segredo, coleção, Rule, dependência ou recurso externo é criado pelo ASSIST-1A.
8. O booleano de consentimento atual autoriza somente esta leitura local. Qualquer envio futuro a provedor exige política e versão de consentimento próprias, além dos controles server-side do ASSIST-0.

## Consequências

- A pessoa obtém utilidade imediata sem compartilhar dados com terceiros.
- Os resumos não fingem conversa inteligente nem conhecimento inexistente.
- O componente que observa dados é montado somente depois do consentimento, reduzindo acesso desnecessário.
- Uma integração de IA futura continua sendo incremento separado e não poderá reutilizar silenciosamente o consentimento local como autorização de envio.
