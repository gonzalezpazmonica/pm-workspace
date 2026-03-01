---
name: ceo-alerts
description: Panel de alertas estratégicas para dirección — solo decisiones que requieren nivel C
developer_type: all
agent: none
context_cost: medium
---

# /ceo-alerts

> 🦉 Savia filtra el ruido y te muestra solo lo que necesita tu atención como directivo.

---

## Cargar perfil de usuario

Grupo: **Reporting** — cargar:

- `identity.md` — nombre, rol
- `projects.md` — proyectos a monitorizar
- `tone.md` — alert_style

---

## Subcomandos

- `/ceo-alerts` — alertas activas de todos los proyectos
- `/ceo-alerts {proyecto}` — alertas de un proyecto
- `/ceo-alerts --history` — últimas 10 alertas resueltas

---

## Flujo

### Paso 1 — Escanear fuentes de alertas

Para cada proyecto:

1. **Sprint health**: ¿Sprint actual con >30% items sin completar a 2 días del cierre?
2. **Team burnout**: ¿Equipo con >120% capacidad durante 2+ sprints?
3. **Technical debt**: ¿Deuda técnica en tendencia ascendente >3 sprints consecutivos?
4. **Risk register**: ¿Riesgos con exposure ALTA o CRÍTICA sin mitigación?
5. **Delivery**: ¿DORA metrics clasificados como LOW en 2+ dimensiones?
6. **Security**: ¿CVEs críticos sin resolver >7 días?
7. **Dependencies**: ¿Bloqueos inter-proyecto sin resolver >5 días?

### Paso 2 — Clasificar por severidad

| Severidad | Criterio | Acción esperada |
|---|---|---|
| 🔴 CRÍTICA | Riesgo de fracaso del proyecto o del equipo | Decisión inmediata |
| 🟠 ALTA | Impacto en delivery o calidad significativo | Revisión esta semana |
| 🟡 MEDIA | Tendencia negativa que requiere vigilancia | Revisión en próximo comité |

### Paso 3 — Mostrar panel

```
🦉 CEO Alerts — {fecha}

🔴 CRÍTICAS ({N})
  [{proyecto}] Sprint fallido: 45% items sin completar, 1 día restante
  [{proyecto}] Burnout risk: equipo al 135% capacidad, sprint 3 consecutivo

🟠 ALTAS ({N})
  [{proyecto}] Deuda técnica ↑ 4 sprints consecutivos, ratio 23%→31%
  [{proyecto}] CVE-2026-XXXX sin resolver, 12 días

🟡 MEDIAS ({N})
  [{proyecto}] Velocity ↓ 15% vs media 3 sprints
  [{proyecto}] 3 dependencias bloqueadas inter-equipo

💡 Recomendaciones:
  1. {acción prioritaria}
  2. {acción secundaria}
```

Solo mostrar alertas si existen. Sin alertas → "✅ Sin alertas estratégicas activas."

---

## Modo agente (role: "Agent")

```yaml
status: ok
action: ceo_alerts
critical: 2
high: 1
medium: 3
alerts:
  - project: sala-reservas
    severity: critical
    type: sprint_failure
    message: "45% items incomplete, 1 day remaining"
```

---

## Restricciones

- **NUNCA** incluir alertas operativas (build roto, test fallido) — eso es nivel Tech Lead
- **NUNCA** más de 10 alertas — si hay más, agrupar por proyecto
- Solo alertas que requieren decisión de nivel directivo
- Sin jerga técnica en las descripciones
