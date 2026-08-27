---
context_tier: L2
---

# DOMAIN: Mensajería agente→agente

## Por qué existe esta skill

Bus local de mensajería A2A con roles y receipts, sin pasar por el usuario —
patrón `agent_message.send` de Prime Agent (SE-347), implementado sobre
ficheros JSONL en infraestructura propia.

## Conceptos de dominio

- **Inbox/outbox**: colas por receptor (`~/.savia/msg/inbox/<agente>.jsonl`) +
  ledger global.
- **Receipts**: queued (ledger) → delivered (inbox) → read (ack).
- **Roles**: parent, child, steer, follow_up.

## Límites

- No usar para datos N3+ fuera de disco propio (el bus es local, pero el
  contenido sigue sujeto a confidencialidad por nivel).
- Complementa agent-notes-protocol (handoff formal), no lo sustituye.

## Confidencialidad

- Colas en `~/.savia/msg` (disco propio, CRIT-001). Nunca en el repo.
