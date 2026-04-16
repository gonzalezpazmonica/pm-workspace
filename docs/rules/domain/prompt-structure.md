---
name: prompt-structure
description: Alineación con la estructura de 10 capas de prompt óptimo — reasoning guidance y output templates
auto_load: false
paths: []
---

# Regla: Prompt Structure — Razonamiento guiado y templates de output

> Fuente: AI Engineering Guidebook (2025) + prompt structure image (10-layer model).

---

## Principio

Todo comando complejo debe guiar el razonamiento paso a paso (capa 7)
y definir un template concreto de output esperado (capa 8).
Esto reduce variabilidad entre ejecuciones y mejora la consistencia.

---

## 1. Reasoning Guidance (obligatorio en commands con `context_cost: high/medium`)

Tras los parámetros y antes del flujo de ejecución, incluir:

```markdown
## Razonamiento

Piensa paso a paso antes de actuar:
1. Primero: [qué analizar o recopilar]
2. Luego: [qué evaluar o calcular]
3. Finalmente: [qué generar como output]
```

Esto ancla la cadena de pensamiento del LLM y evita saltos directos a la respuesta.

**Anti-pattern:** No usar para commands triviales (`context_cost: low`) — añade tokens sin valor.

---

## 2. Output Template (obligatorio en commands que generan ficheros)

Además del patrón `output-first` de `context-health.md`, todo command que genere
un fichero de output debe incluir un template concreto del formato esperado:

```markdown
## Template de Output

```markdown
# [Título] — [Fecha]

## Resumen Ejecutivo
[2-3 frases con hallazgo principal]

## Hallazgos
| # | Hallazgo | Severidad | Acción |
|---|----------|-----------|--------|

## Siguiente paso
[Comando recomendado]
```

**Anti-pattern:** No confundir con el banner de fin (que va en chat). El template es para el fichero generado.

---

## 3. Validación

`scripts/validate-commands.sh` debería verificar (como warning):
- Commands con `context_cost: high` → presencia de sección `Razonamiento` o `Paso a paso`
- Commands que mencionan `output/` → presencia de template o formato de salida

---

## 4. Capas cubiertas por pm-workspace

| Capa (10-layer model) | Implementación pm-workspace |
|---|---|
| 1. Task context | CLAUDE.md → Rol, Estructura |
| 2. Tone | Savia personality (profiles/savia.md) |
| 3. Background data | Rules bajo demanda (@), project CLAUDE.md |
| 4. Rules | Reglas Críticas (23 reglas) |
| 5. Examples | **→ Mejora 1: example-patterns.md** |
| 6. Conversation history | Claude Code nativo (auto) |
| 7. Step-by-step | **→ Esta regla: Reasoning Guidance** |
| 8. Output formatting | **→ Esta regla: Output Templates** |
| 9. Prefilled response | Banners UX (command-ux-checklist.md) |
| 10. Task description | Command .md (frontmatter + instrucciones) |
