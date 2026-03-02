---
name: nl-query
description: Consultas en lenguaje natural — pregunta sobre tu proyecto sin memorizar comandos
developer_type: all
agent: task
context_cost: medium
---

# /nl-query

> 🦉 Savia entiende lo que preguntas, aunque no sepas el comando exacto.

---

## Cargar perfil de usuario

Grupo: **Sprint & Daily** — cargar:

- `identity.md` — nombre, rol
- `projects.md` — proyecto activo
- `preferences.md` — language

---

## Subcomandos

- `/nl-query {pregunta}` — interpretar y ejecutar
- `/nl-query --explain` — mostrar qué comando ejecutaría sin hacerlo
- `/nl-query --history` — últimas 10 consultas y comandos mapeados

---

## Flujo

### Paso 1 — Interpretar intención

Mapear la pregunta del usuario a comandos existentes:

```
Pregunta → Intención → Comando(s)

"¿cómo va el sprint?"      → estado sprint    → /sprint-status
"¿llegaremos a tiempo?"    → riesgo sprint     → /risk-predict
"¿quién está bloqueado?"   → bloqueantes       → /sprint-status --blocked
"resume la retro de ayer"  → meeting summary   → /meeting-summarize --type retro
"¿cuánta deuda tenemos?"   → debt metrics      → /debt-summary
"¿qué hizo Ana ayer?"      → daily individual  → /daily-generate --person Ana
"plan del próximo sprint"  → autoplan          → /sprint-autoplan
```

### Paso 2 — Confirmar interpretación

```
🔍 He interpretado tu pregunta como:

  Pregunta: "{pregunta original}"
  Comando: /sprint-status --project sala-reservas
  Confianza: {alta/media/baja}

  ¿Ejecuto? [S/n]
```

Si confianza ≥ 80%: ejecutar directamente (skip confirmación).
Si confianza 50-79%: confirmar antes de ejecutar.
Si confianza < 50%: pedir reformulación o sugerir opciones.

### Paso 3 — Ejecutar y presentar

Ejecutar el comando mapeado y presentar resultado en formato natural.

### Paso 4 — Aprender patrones

Registrar mapeos exitosos para mejorar futuras interpretaciones.

---

## Modo agente (role: "Agent")

```yaml
status: ok
action: nl_query
query: "¿cómo va el sprint?"
mapped_command: "sprint-status"
confidence: 92
executed: true
```

---

## Restricciones

- **NUNCA** ejecutar comandos destructivos sin confirmación explícita
- **NUNCA** inventar datos si el comando mapeado no tiene información
- **NUNCA** adivinar si confianza < 50% — pedir clarificación
- Si no hay mapeo claro → sugerir los 3 comandos más probables
- Respetar siempre los permisos del rol del usuario
