# Matriz de testes das regras Firestore

Situação: **pendente de Emulator Suite ou validação manual autorizada**. Nenhum caso abaixo foi apresentado como executado em emulador.

| ID | Caso | Resultado esperado | Controle principal | Estado |
|---|---|---|---|---|
| FR-001 | Anônimo lendo perfil | negar | `request.auth != null` | pendente |
| FR-002 | Anônimo criando perfil | negar | `request.auth != null` | pendente |
| FR-003 | Usuário não verificado lendo perfil | negar | token `email_verified` | pendente |
| FR-004 | Usuário não verificado criando perfil | negar | token `email_verified` | pendente |
| FR-005 | Verificado lendo o próprio perfil por caminho exato | permitir | uid do caminho | pendente |
| FR-006 | Verificado lendo perfil de outro uid | negar | igualdade de uid | pendente |
| FR-007 | Verificado listando `users` | negar | `allow list: false` | pendente |
| FR-008 | Criação com todos os campos válidos | permitir | esquema e timestamps | pendente |
| FR-009 | Criação com `ownerId` incorreto | negar | proprietário | pendente |
| FR-010 | Criação com campo adicional | negar | chaves exatas | pendente |
| FR-011 | Criação com campo ausente | negar | chaves exatas | pendente |
| FR-012 | Criação com tipo incorreto | negar | tipos fechados | pendente |
| FR-013 | Criação com nome curto, longo, espaços inválidos ou controle | negar | validação de nome | pendente |
| FR-014 | Criação com locale diferente de `pt-BR` | negar | valor fixo | pendente |
| FR-015 | Criação com moeda diferente de `BRL` | negar | valor fixo | pendente |
| FR-016 | Criação com fuso diferente de `America/Sao_Paulo` | negar | valor fixo | pendente |
| FR-017 | Criação com `schemaVersion` diferente de 1 | negar | esquema atual | pendente |
| FR-018 | Criação com versão jurídica desconhecida | negar | versões development atuais | pendente |
| FR-019 | Timestamp literal do cliente no lugar de servidor | negar | igualdade com `request.time` | pendente |
| FR-020 | Atualização válida de nome e `updatedAt` | permitir | campos aprovados | pendente |
| FR-021 | Alteração de `ownerId` | negar | campo imutável | pendente |
| FR-022 | Alteração de `createdAt` | negar | campo imutável | pendente |
| FR-023 | Alteração de locale, moeda, fuso ou esquema | negar | campos imutáveis | pendente |
| FR-024 | Alteração de timestamp de consentimento sem mudar booleano | negar | transição pareada | pendente |
| FR-025 | Mudança de IA com timestamp do servidor | permitir | transição pareada IA | pendente |
| FR-026 | Mudança de IA alterando Analytics | negar | campos e timestamps independentes | pendente |
| FR-027 | Mudança de Analytics com timestamp do servidor | permitir | transição pareada Analytics | pendente |
| FR-028 | Mudança de Analytics alterando IA | negar | campos e timestamps independentes | pendente |
| FR-029 | Novo aceite de Termos com versão atual e timestamp | permitir | transição jurídica pareada | pendente |
| FR-030 | Novo aceite de Política com versão atual e timestamp | permitir | transição jurídica pareada | pendente |
| FR-031 | Exclusão do perfil pelo cliente | negar | `allow delete: false` | pendente |
| FR-032 | Acesso a qualquer subcoleção financeira | negar | bloqueio recursivo | pendente |
| FR-033 | Leitura ou escrita em caminho desconhecido | negar | negação global | pendente |

Antes de qualquer publicação futura de produção, todos os casos permitidos e negados precisam ser automatizados no Emulator Suite.
