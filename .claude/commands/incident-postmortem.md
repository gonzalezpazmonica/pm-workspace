---
name: incident-postmortem
description: Template de postmortem — timeline, root cause analysis, action items
developer_type: all
agent: none
context_cost: medium
---

# /incident-postmortem

> 🦉 Savia estructura el postmortem para que el equipo aprenda del incidente.

---

## Cargar perfil de usuario

Grupo: **Reporting** — cargar:

- `identity.md` — nombre, empresa
- `preferences.md` — language, report_format
- `projects.md` — proyecto afectado
- `tone.md` — formality

---

## Subcomandos

- `/incident-postmortem {descripción}` — crear nuevo postmortem
- `/incident-postmortem --from-alert {id}` — crear desde una alerta
- `/incident-postmortem --list` — listar postmortems existentes

---

## Flujo

### Paso 1 — Recopilar información del incidente

Preguntar al Tech Lead:

1. ¿Qué ocurrió? (descripción breve)
2. ¿Cuándo se detectó? ¿Cuándo se resolvió?
3. ¿Qué servicios/usuarios se vieron afectados?
4. ¿Cuál fue la severidad? (SEV1-4)

### Paso 2 — Construir timeline

```
Timeline:
  HH:MM — Incidente detectado por {fuente}
  HH:MM — Equipo notificado via {canal}
  HH:MM — Causa raíz identificada: {descripción}
  HH:MM — Fix deployed
  HH:MM — Servicio restaurado
  Total: {N} horas de impacto
```

### Paso 3 — Root cause analysis (5 Whys)

Guiar al Tech Lead a través de los 5 porqués:

1. ¿Por qué falló el servicio? → ...
2. ¿Por qué no se detectó antes? → ...
3. ¿Por qué no había protección? → ...
4. ¿Por qué no se había previsto? → ...
5. ¿Cuál es la causa raíz sistémica? → ...

### Paso 4 — Generar documento

Guardar en `output/postmortems/{fecha}-{incidente}.md`:

```
# Postmortem: {título}

## Resumen
  Fecha: {fecha} | Severidad: SEV{N} | Duración: {N}h
  Impacto: {usuarios/servicios afectados}

## Timeline
  {timeline del paso 2}

## Root Cause Analysis
  {5 whys del paso 3}
  Causa raíz: {conclusión}

## Action Items
  | # | Acción | Responsable | Prioridad | Fecha límite |
  |---|---|---|---|---|
  | 1 | {acción preventiva} | @{persona} | Alta | {fecha} |
  | 2 | {mejora de detección} | @{persona} | Media | {fecha} |

## Lecciones aprendidas
  {2-3 lecciones clave}
```

---

## Modo agente (role: "Agent")

```yaml
status: ok
action: incident_postmortem
severity: SEV2
duration_hours: 3.5
root_cause: "Missing retry logic on external API"
action_items: 3
output_file: output/postmortems/2026-03-01-api-timeout.md
```

---

## Restricciones

- **NUNCA** asignar culpa a personas — enfoque blameless
- **NUNCA** publicar sin revisión del Tech Lead
- Tono constructivo: aprender, no castigar
- Action items deben ser específicos, medibles y con responsable
