# Matriz de enforcement Premium — SUB-1C

Estado: implementada e validada exclusivamente localmente. As regras não foram publicadas e nenhum Firebase real foi acessado.

| Entitlement | Capability solicitada | Leitura histórica | Mutação |
|---|---|---:|---:|
| ausente | qualquer | negar | negar |
| `pending` | qualquer | negar | negar |
| `trialing` vigente | presente | permitir | permitir |
| `active` vigente | presente | permitir | permitir |
| `gracePeriod` antes de `graceUntil` | presente | permitir | permitir |
| `cancelled` antes do fim exclusivo | presente | permitir | permitir |
| `cancelled` no/depois do fim | concedida anteriormente | permitir | negar |
| `expired`, `accountHold`, `paused`, `revoked`, `refunded` | concedida anteriormente | permitir | negar |
| documento inválido, schema/owner/ambiente incompatível | qualquer | negar | negar |
| confirmação indisponível, cache ou escrita pendente | qualquer | negar | negar |

## Separação por capability

| Área | Leitura | Mutação |
|---|---|---|
| carteiras, ativos e operações | `investmentsManual` | `investmentsManual` integral |
| proventos | `investmentIncome` | `investmentIncome` integral |
| cotações | não implementada | `investmentQuotes` não cria funcionalidade |
| calculadoras e análises | não implementadas | capabilities reservadas não criam funcionalidade |

## Defesas

- Security Rules: autoridade definitiva, `request.time`, UID próprio, e-mail confirmado, perfil jurídico, entitlement e invariantes financeiras.
- Repositório: decorator impede leitura ou mutação fora da capability e retorna falha tipada.
- Controller: bloqueia múltiplos toques, verifica antes/depois, não consome ID na negação e descarta resposta tardia.
- Rotas/UI: não constroem conteúdo antes da confirmação; somente leitura remove ações; erro permite retry; nenhuma decisão da UI concede acesso.

Dados históricos nunca são apagados ou modificados por mudança de entitlement. Retomar um entitlement válido restaura mutações sem migração.
