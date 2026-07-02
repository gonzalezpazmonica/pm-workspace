---
name: release-readiness
description: Checklist de release — features, tests, docs, compliance, deployment
developer_type: all
agent: task
context_cost: high
tier: extended
---

# /release-readiness

> 🦉 Savia verifica que todo está listo antes de lanzar a producción.

---

## Cargar perfil de usuario

Grupo: **Reporting** — cargar:

- `identity.md` — nombre, rol
- `preferences.md` — language, detail_level
- `projects.md` — proyecto target
- `tone.md` — formality

---

## Subcomandos

- `/release-readiness` — checklist completo pre-release
- `/release-readiness --quick` — solo bloqueantes (go/no-go rápido)
- `/release-readiness --history` — historial de releases anteriores

---

## Flujo

### Paso 1 — Verificar features comprometidas

```
📦 Features del Release — {versión}

| Feature | Estado | Tests | Docs | Owner |
|---|---|---|---|---|
| {feature 1} | ✅ Done | ✅ | ✅ | @{persona} |
| {feature 2} | ✅ Done | ⚠️ Parcial | ❌ | @{persona} |
| {feature 3} | 🔄 WIP | ❌ | ❌ | @{persona} |

Completadas: {N}/{total} ({%})
```

### Paso 2 — Verificar calidad

```
🧪 Quality Gate

  Tests unitarios: {pass}/{total} ({%}) — {✅/❌}
  Tests integración: {pass}/{total} ({%}) — {✅/❌}
  Tests E2E: {pass}/{total} ({%}) — {✅/❌}
  Cobertura: {%} (umbral: {%}) — {✅/❌}
  Bugs abiertos críticos: {N} — {✅ si 0 / ❌ si >0}
  Bugs abiertos altos: {N} — {⚠️ si >0}
  Tests flaky: {N} — {⚠️ si >3}
```

### Paso 3 — Verificar documentación y compliance

```
📄 Documentación & Compliance

  README actualizado: {✅/❌}
  CHANGELOG actualizado: {✅/❌}
  Release notes redactadas: {✅/❌}
  API docs actualizadas: {✅/❌}
  Compliance scan limpio: {✅/❌}
  Security audit sin críticos: {✅/❌}
  Licencias verificadas: {✅/❌}
```

### Paso 4 — Verificar deployment

```
🚀 Deployment Readiness

  Pipeline CI/CD verde: {✅/❌}
  Migraciones DB preparadas: {✅/❌/N/A}
  Variables de entorno configuradas: {✅/❌}
  Rollback plan documentado: {✅/❌}
  Monitoring/alertas configuradas: {✅/❌}
```

### Paso 5 — Decisión Go / No-Go

```
🏁 Release Decision — {versión}

  Bloqueantes encontrados: {N}
  Warnings: {N}

  Decisión: {🟢 GO / 🔴 NO-GO / 🟡 GO con condiciones}

  {Si NO-GO: lista de bloqueantes a resolver}
  {Si GO con condiciones: lista de warnings aceptados}
```

---

## Modo agente (role: "Agent")

```yaml
status: ok
action: release_readiness
project: sala-reservas
version: "2.1.0"
features_ready: 8
features_total: 10
blockers: 1
warnings: 3
decision: "no-go"
blocker_detail: "2 critical bugs open"
```

---

## Restricciones

- **NUNCA** recomendar GO si hay bugs críticos abiertos
- **NUNCA** omitir secciones del checklist — todas son obligatorias
- **NUNCA** aprobar release sin que el PO y Tech Lead confirmen
- Si no hay datos de alguna sección → marcar como ❓ Desconocido (bloqueante)
- La decisión final es del equipo, Savia solo presenta evidencia
