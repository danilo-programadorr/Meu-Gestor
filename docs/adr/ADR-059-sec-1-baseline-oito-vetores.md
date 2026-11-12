# ADR-059 — SEC-1 baseline contra oito vetores comuns

- Status: implementação local; publicação externa não autorizada
- Data: 26/10/2026

## Contexto

O aplicativo precisava tornar verificável a proteção contra XSS, rotas de API
expostas, chaves expostas, banco aberto, SQL injection, abuso por tentativas,
prompt injection e dependências sem procedência. A revisão mostrou que a maior
parte dos controles já existia, mas havia duas lacunas concretas: URLs externas
de notícias não exigiam HTTPS no cliente e a busca autenticada de ativos não
possuía limite persistente por proprietário.

## Decisão

1. Conteúdo remoto continua renderizado somente por widgets `Text`, sem HTML ou
   WebView. URLs de matéria e imagem passam a aceitar apenas HTTPS absoluto sem
   credenciais embutidas.
2. HTTP operacional de cotações e notícias permanece privado. Callables públicas
   exigem Auth, e-mail verificado e App Check e aceitam contratos fechados.
3. Segredos de BRAPI e Marketaux continuam em `defineSecret`; valores de runtime
   e identidades não entram no APK ou Git. O gate de CI valida lockfiles, não
   segredos.
4. Firestore mantém negação por padrão, isolamento por UID e coleções internas
   sem leitura/escrita de cliente. O contador de busca também é server-side.
5. Não existe driver ou banco SQL no runtime; filtros Firestore usam APIs
   parametrizadas. Introduzir SQL exigirá ADR e testes próprios.
6. Firebase Auth conserva a proteção de tentativas da plataforma. Assistente
   mantém quota e ledger. A busca de ativos passa a consumir atomicamente uma
   janela de 30 tentativas por cinco minutos por hash opaco do UID, antes do
   provedor, falhando fechada em corrupção ou indisponibilidade do contador.
7. O Assistente mantém ferramentas enumeradas, schema fechado, admissão de
   evidências e resposta renderizada pelo servidor. Uma instrução de sistema
   separada classifica mensagem, continuação e fatos como dados não confiáveis;
   saída que tenta selecionar ferramenta fora do catálogo é descartada.
8. Dependências npm diretas permanecem fixadas e todos os artefatos resolvidos
   precisam vir de `registry.npmjs.org` com integridade SHA-512. Dependências
   Dart só podem vir do SDK ou `pub.dev`. O gate é local, determinístico e não
   executa scripts nem consulta rede.

## Consequências

- A busca de ativos pode responder `resource-exhausted` após abuso; consultas
  normais continuam compatíveis com o debounce do cliente.
- O documento opaco de limite não contém UID, consulta, carteira ou valores e é
  inacessível pelas Rules. Configuração futura de TTL é otimização operacional,
  não requisito para a proteção funcionar.
- A medida reduz os vetores conhecidos, mas não substitui App Check, IAM mínimo,
  auditoria de dependências, monitoração e testes recorrentes.
- Nenhum recurso Firebase, segredo, IAM, ambiente development ou produção foi
  alterado por esta implementação local.
