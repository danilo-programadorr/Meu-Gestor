# Matriz de testes — acesso proprietário

## Modelo e repositório

| ID | Cenário | Resultado esperado |
|---|---|---|
| OWNER-01 | Documento válido | Owner ativo |
| OWNER-02 | `active=false` | Revogado |
| OWNER-03 | Papel desconhecido | Documento inválido |
| OWNER-04 | Ambiente diferente | Documento inválido |
| OWNER-05 | Esquema diferente de 1 | Documento inválido |
| OWNER-06 | `grantedAt` ausente | Documento inválido |
| OWNER-07 | `grantedAt` não timestamp | Documento inválido |
| OWNER-08 | Campo extra | Documento inválido |
| OWNER-09 | Campo ausente | Documento inválido |
| OWNER-10 | Documento inexistente | Usuário comum |
| OWNER-11 | Caminho da leitura | Somente `system_admins/{uid}` |
| OWNER-12 | API do repositório | Sem listagem de admins |
| OWNER-13 | Ausência confirmada | `regularUser` |
| OWNER-14 | Documento válido e servidor | `activeOwner` |
| OWNER-15 | Documento inativo | `revoked` |
| OWNER-16 | Documento incompatível | Sem privilégio |
| OWNER-17 | Resultado somente de cache | Sem privilégio |
| OWNER-18 | Timeout | Sem privilégio |
| OWNER-19 | `permission-denied` | Sem privilégio |
| OWNER-20 | `unavailable` | Erro recuperável e retry |
| OWNER-21 | Logout | Estado invalidado |
| OWNER-22 | Troca de usuário | Estado anterior invalidado |
| OWNER-23 | Refresh | Nova leitura do servidor |
| OWNER-24 | Resposta antiga | Ignorada |
| OWNER-25 | Concorrência | Uma leitura ativa |

## Capabilities

| ID | Cenário | Resultado esperado |
|---|---|---|
| OWNER-26 | Owner | Todas as capabilities registradas |
| OWNER-27 | Usuário comum | Nenhuma capability administrativa |
| OWNER-28 | Capability desconhecida | Negada |
| OWNER-29 | E-mail | Não participa da decisão |
| OWNER-30 | Armazenamento local | Não participa da decisão |

## Interface e navegação

| ID | Cenário | Resultado esperado |
|---|---|---|
| OWNER-31 | Perfil owner | Selo visível |
| OWNER-32 | Perfil comum | Selo e espaço ausentes |
| OWNER-33 | Owner abre rota | Área exibida |
| OWNER-34 | Comum abre rota | Área não exibida |
| OWNER-35 | Acesso direto negado | Destino seguro, sem loop |
| OWNER-36 | Loading | Conteúdo administrativo oculto |
| OWNER-37 | Revogação | Selo e acesso removidos |
| OWNER-38 | Atualizar acesso | Revalidação pelo servidor |
| OWNER-39 | Sem internet | Owner não concedido |
| OWNER-40 | Erro administrativo | Módulos próprios continuam acessíveis |
| OWNER-41 | Tema claro | Legível |
| OWNER-42 | Tema escuro | Legível |
| OWNER-43 | Tela pequena | Responsiva |
| OWNER-44 | Fonte ampliada | Sem corte |
| OWNER-45 | Semântica | Selo e estado anunciados |
| OWNER-46 | Layout | Sem overflow |
| OWNER-47 | Voltar | Retorna à tela anterior |
| OWNER-48 | UID | Não exibido |
| OWNER-49 | E-mail | Não exibido |
| OWNER-50 | Dados de terceiros | Não exibidos |

## Segurança estática e regras

| ID | Controle | Evidência esperada |
|---|---|---|
| OWNER-51 | Identidade | Nenhum e-mail hardcoded |
| OWNER-52 | Identidade | Nenhum UID hardcoded |
| OWNER-53 | Segredo | Nenhuma senha mestre |
| OWNER-54 | Rota | Nenhuma liberação por parâmetro |
| OWNER-55 | Escrita | Cliente não cria admin |
| OWNER-56 | Escrita | Cliente não edita nem exclui admin |
| OWNER-57 | Descoberta | Cliente não lista admins |
| OWNER-58 | Regressão | Regras financeiras preservadas |
| OWNER-59 | Isolamento | Outros UIDs continuam negados |
| OWNER-60 | Ambiente | Produção bloqueada |

Os testes Dart usam fakes e leitura estática local. Testes executáveis das Security Rules no Emulator Suite permanecem pendentes até autorização específica.
