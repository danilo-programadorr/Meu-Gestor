# Cobertura de comentários do código

## Objetivo

Este inventário acompanha a adoção de comentários curtos em bloco para explicar
a responsabilidade de cada unidade de código própria. Comentários não devem
descrever linha a linha, repetir tipos ou substituir testes, contratos e
documentação de arquitetura.

## Regras do inventário

- Inclui código manual Flutter, backend ESM, Functions, scripts, testes e
  Android nativo próprio.
- Exclui dependências, arquivos gerados, build, caches, lockfiles, configurações
  sem suporte a comentários e diretórios temporários.
- Cada arquivo de produção recebe um bloco de responsabilidade na abertura;
  blocos com política, efeito externo, transação ou fronteira de segurança
  recebem comentário curto adicional no ponto de entrada.
- Testes recebem um bloco de intenção: comportamento, isolamento ou regressão
  que protegem. Fixtures continuam sintéticas e não documentam dados reais.

## Linha de base — CODE-DOCS-1A

Auditoria local em 06/09/2026: 495 arquivos próprios elegíveis.

| Área | Arquivos | Cobertura inicial | Próxima revisão |
|---|---:|---|---|
| Flutter: accounts | 21 | pendente | módulo de contas |
| Flutter: authentication | 19 | pendente | autenticação |
| Flutter: calendar | 10 | pendente | calendário |
| Flutter: categories | 15 | pendente | categorias |
| Flutter: commitments | 15 | pendente | compromissos |
| Flutter: home | 4 | pendente | Home |
| Flutter: investments | 38 | pendente | investimentos |
| Flutter: owner_access | 16 | pendente | owner seguro |
| Flutter: privacy | 10 | pendente | privacidade |
| Flutter: profile | 17 | pendente | perfil |
| Flutter: subscriptions | 32 | pendente | assinatura inativa |
| Flutter: transactions | 23 | pendente | lançamentos |
| Flutter: assistant | 20 | em revisão inicial | CODE-DOCS-1A |
| Testes Flutter de módulos | 132 | pendente, exceto Assistente | por módulo |
| Testes Flutter núcleo/regressão | 28 | pendente | núcleo |
| Backend: assistant | 33 | em revisão inicial | CODE-DOCS-1A |
| Backend: privacy | 8 | pendente | privacidade |
| Backend: quotes | 9 | pendente | cotações |
| Backend: subscriptions | 19 | pendente | assinatura |
| Functions: assistant | 7 | em revisão inicial | CODE-DOCS-1A |
| Functions: premium | 11 | pendente | assinatura |
| Functions: privacy | 6 | pendente | privacidade |
| Functions: quotes | 5 | pendente | cotações |
| Android nativo e demais scripts próprios | 28 | pendente | por fronteira |

## Módulo Assistente — primeira revisão

Escopo: 79 arquivos.

| Subárea | Arquivos | Estado |
|---|---:|---|
| backend/assistant | 35 | comentários de responsabilidade iniciados, incluindo ASSIST-2M |
| backend/functions/assistant | 7 | comentários de fronteira e fail-closed iniciados |
| lib/features/assistant | 20 | revisão inicial em andamento |
| test/features/assistant | 16 | revisão inicial em andamento |
| test/firestore_rules | 1 | pendente de revisão junto à Rule isolada |

O inventário não certifica cobertura total até que cada arquivo do módulo tenha
sido revisado e os testes relevantes tenham passado. Ele não autoriza alteração
funcional, dependência, serviço externo ou publicação.
