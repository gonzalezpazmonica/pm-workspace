---
name: webhook-config
description: Configurar webhooks para recibir eventos push de Azure DevOps, GitHub y otras fuentes
developer_type: all
agent: task
context_cost: medium
---

# /webhook-config

> 🦉 Savia recibe eventos en tiempo real — sin polling.

---

## Cargar perfil de usuario

Grupo: **Infrastructure** — cargar:

- `identity.md` — nombre
- `projects.md` — proyectos conectados
- `preferences.md` — notification_channel

---

## Subcomandos

- `/webhook-config add {source}` — registrar nuevo webhook
- `/webhook-config list` — listar webhooks activos
- `/webhook-config remove {id}` — eliminar webhook
- `/webhook-config test {id}` — enviar evento de prueba

---

## Flujo

### Paso 1 — Seleccionar fuente y eventos

```
📡 Webhook Setup

  Fuentes disponibles:
  ├─ azure-devops — work item updates, sprint events, PR merges
  ├─ github — push, PR, issues, releases, CI status
  └─ custom — cualquier endpoint que envíe JSON

  Eventos sugeridos para {proyecto}:
  ├─ ✅ Work item → State changed (sprint tracking)
  ├─ ✅ Sprint → Started / Completed (burndown)
  ├─ ✅ Pull Request → Merged (velocity)
  └─ ⬜ Build → Completed (DORA metrics)
```

### Paso 2 — Configurar endpoint

```yaml
webhook:
  id: "wh-001"
  source: "azure-devops"
  project: "sala-reservas"
  events:
    - "workitem.updated"
    - "sprint.completed"
    - "git.pullrequest.merged"
  endpoint: "http://localhost:{port}/webhooks/azure"
  secret: "{generated-hmac-secret}"
  created: "2026-03-02"
```

### Paso 3 — Mapear eventos a acciones

```
📋 Event → Action Mapping

  workitem.updated → actualizar /sprint-status cache
  sprint.completed → trigger /sprint-review-auto
  git.pullrequest.merged → actualizar velocity metrics
  build.completed → actualizar DORA metrics
```

### Paso 4 — Verificar conectividad

Enviar evento de prueba y confirmar recepción.

---

## Modo agente (role: "Agent")

```yaml
status: ok
action: webhook_config
webhooks_active: 3
sources: ["azure-devops", "github"]
events_mapped: 7
last_event: "2026-03-02T14:30:00Z"
```

---

## Restricciones

- **NUNCA** almacenar secretos de webhook en ficheros no cifrados
- **NUNCA** exponer endpoints webhook a internet sin autenticación
- **NUNCA** procesar eventos sin validar firma HMAC
- Webhooks locales solo (localhost) — para producción, usar proxy seguro
- Rate limiting: máximo 100 eventos/minuto por fuente
