---
name: playbook-reflect
description: Reflexión post-ejecución de playbooks — framework ACE Reflector
developer_type: all
agent: task
context_cost: high
---

# /playbook-reflect

> 🦉 Aprende de cada ejecución del playbook.

**Reflector del framework ACE**: analiza qué funcionó, qué falló, qué mejorar.
Documenta insights que alimentan la evolución (→ `/playbook-evolve`).

---

## Comando

```
/playbook-reflect {nombre} [--session last|all] [--lang es|en]
```

**Parámetros:**
- `{nombre}` — Nombre del playbook: release, onboarding, audit, deploy
- `--session last` — Reflexionar sobre la última ejecución (por defecto)
- `--session all` — Analizar todas las ejecuciones del playbook
- `--lang es|en` — Idioma (español por defecto)

---

## Análisis de Reflexión

### 1. Ejecución exitosa

```
✅ Ejecución 2026-03-02T14:30:00Z — COMPLETADA (45min)

Paso 1 — Validar artefactos:
  ✅ Passed | 5m | Todos los artefactos presentes

Paso 2 — Notificar stakeholders:
  ✅ Passed | 8m | 12 correos enviados
  
Criterios de éxito:
  ✅ all_tests_pass
  ✅ zero_critical_bugs
  ✅ stakeholders_notified
```

### 2. Paso fallido — Análisis causal

```
❌ Paso 3 — Deploy a PRO: FALLÓ después de 15min

  Error: "Connection timeout (120s) → Server 10.0.1.50"
  
  Análisis:
  - Servidor lento hoy (mantenimiento programado?)
  - Timeout de 120s es muy corto (otros deploys toman 180s)
  - Pasado: falló 1/5 veces por timeout
  
  Recomendaciones:
  - Aumentar timeout de 120s → 240s
  - Añadir retry logic con backoff exponencial
  - Verificar si el servidor está en mantenimiento
```

### 3. Bottleneck detectado

```
⚠️ Paso 2 — Notificar stakeholders: COMPLETADO pero LENTO

  Duración: 28min (últimas 3 ejecuciones: 8m, 12m, 28m)
  
  Análisis:
  - 200 notificaciones (cada email = ~8s)
  - Proceso secuencial → paralelización posible
  - Tendencia: crecimiento de 2x en 3 ejecuciones
  
  Recomendación:
  - Paralelizar envío (batch de 10, máx 2s/batch)
  - Objetivo: 30s en lugar de 28m
```

---

## Generación de Reflection Report

Guardar en `projects/{project}/playbooks/reflections/{nombre}-{fecha}.md`

```markdown
# Reflexión: {nombre}

**Generación del playbook:** g2 (creado 2026-03-02)
**Sesión de ejecución:** 2026-03-09T10:00:00Z
**Duración total:** 45 minutos
**Estado:** ✅ COMPLETADA

## Resumen

- 5 pasos, todos completados
- 1 bottleneck detectado: notificaciones (28min)
- 1 recomendación de mejora: paralelizar

## Análisis detallado

[Detalles de cada paso, errores, bottlenecks]

## Insights para evolución

1. Aumentar timeout (120s → 240s)
2. Paralelizar notificaciones (esperado 30s)
3. Monitorizar tendencia de duración
```

---

## Output

```
📊 Reflexión completada: release

Ejecución: 2026-03-09T10:00:00Z — ✅ COMPLETADA
Duración: 45min
Pasos exitosos: 5/5

🔍 Hallazgos:
  ⚠️  Bottleneck: Paso 2 (notificaciones) 28min → paralelizar
  💡 Aumentar timeout a 240s
  📈 Tendencia: duración creciendo 2x cada ejecución

📄 Informe guardado: projects/PROJ/playbooks/reflections/release-20260309.md

🚀 Siguiente: /playbook-evolve release --conservative
   (aplicar insights con cambios cuidadosos)
```

---

## Métricas capturadas

- **Éxito**: ✅/❌ por paso
- **Duración**: tiempo total y por paso
- **Tendencia**: comportamiento en últimas N ejecuciones
- **Bottleneck**: pasos lentos con análisis causal
- **Errores**: mensajes, frecuencia, soluciones sugeridas
