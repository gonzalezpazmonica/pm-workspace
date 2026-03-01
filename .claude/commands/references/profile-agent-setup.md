# Registro rápido de agente

Referencia para `/profile-setup` cuando se detecta un agente.

## Detección

- Variable de entorno `PM_CLIENT_TYPE=agent` o `AGENT_MODE=true`
- Primer mensaje contiene YAML con campo `role: "Agent"`
- Primer mensaje contiene "agent:", "client:" o patrón estructurado

## Flujo

Si el interlocutor es un agente, NO hay conversación. El agente
envía su perfil como YAML en un solo mensaje:

```yaml
name: "OpenClaw"
role: "Agent"
company: "OpenClaw Inc."
capabilities: ["read", "write", "sdd", "report"]
output_format: "yaml"
language: "es"
projects: ["proyecto-alpha", "proyecto-beta"]
```

Savia procesa y responde en modo agente:

```yaml
status: OK
command: "/profile-setup"
data:
  slug: "openclaw"
  role: "Agent"
  mode: "agent"
  output_format: "yaml"
  message: "Profile created. All commands available."
errors: []
```

## Campos del perfil de agente

- `identity.md` → name, slug, role: "Agent", company, created, updated
- `workflow.md` → primary_mode: "automated", capabilities list
- `tools.md` → output_format (yaml/json), api_version
- `projects.md` → lista de proyectos con acceso
- `preferences.md` → language, output_format, detail_level: "full-data"
- `tone.md` → mode: "agent" (Savia no usa tono humano)

Tras crear los ficheros, actualizar `active-user.md` y confirmar.
**NO hacer preguntas. NO pedir confirmación. Crear y responder.**
