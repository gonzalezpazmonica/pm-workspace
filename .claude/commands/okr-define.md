---
name: okr-define
description: Definir Objectives y Key Results vinculados a proyectos
developer_type: all
agent: task
context_cost: medium
---

# /okr-define

> 🦉 Savia te guía para definir ambiciosos OKRs alineados con tus proyectos.

---

## Cargar perfil

Grupo: **Company Intelligence** — cargar:

- `company/identity.md` — nombre, sector, tamaño
- `company/strategy.md` — OKRs existentes (si los hay)
- `company/structure.md` — departamentos y equipos (para alineación)

---

## Subcomandos

- `/okr-define` — creación guiada de OKRs (Objective + Key Results)
- `/okr-define --template {tipo}` — usar plantilla: `sales`, `product`, `engineering`, `operations`
- `/okr-define --import {file}` — importar OKRs de documento existente

---

## Flujo

### Paso 1 — Verificar perfil de empresa

Leer `company/identity.md`. Si no existe → sugerir `/company-setup` primero.

### Paso 2 — Crear OKRs guiados

Para cada Objective (máx 5 por empresa):

```
🦉 Vamos a definir tus Objectives para este ciclo.

  Objetivo 1 — Cualitativo, ambicioso, memorable
  ├─ ¿Cómo se llama? (ej: "Dominar el mercado de SaaS en LATAM")
  ├─ ¿Cuál es tu ámbito? (empresa, departamento, equipo)
  ├─ ¿Duración? (por defecto: 1 año)
  └─ ¿Descripción? (contexto y motivación)

  Key Result 1 — Métrica cuantificable, ambiciosa pero alcanzable
  ├─ ¿Métrica? (ej: "Ingresos MRR")
  ├─ ¿Unidad? (% de crecimiento, números absolutos, etc.)
  ├─ ¿Valor actual? (baseline)
  ├─ ¿Target? (meta final del ciclo)
  └─ ¿Cómo mides? (fuente de verdad)

  [Repetir KR 2-5 por Objective]
```

### Paso 3 — Vincular a proyectos

Para cada Key Result, proponer qué proyectos contribuyen a conseguirla:

```
🦉 ¿Qué proyectos ayudan a lograr este KR?

  Búsqueda: "proyectos que generan ingresos"
  Candidatos: backend-api, mobile-app, payment-gateway

  Selecciona los que contribuyen (multi-select)
```

### Paso 4 — Guardar en company/strategy.md

Estructura generada:

```markdown
# OKRs 2026

## Objetivo 1: {nombre}
- **Ámbito**: {empresa|departamento|equipo}
- **Duración**: {período}
- **Descripción**: {contexto}

### Key Result 1.1 — {métrica}
- Baseline: {valor actual}
- Target: {meta}
- Fuente: {cómo se mide}
- Proyectos contribuidores: {proyecto1, proyecto2}
- Progress: 0% (sin datos)

### Key Result 1.2 — ...

## Objetivo 2 ...
```

---

## Modo agente (role: "Agent")

```yaml
status: ok
action: okr_definition
objectives_created: {n}
key_results_total: {n}
projects_linked: {n}
file_path: ".claude/profiles/company/strategy.md"
```

---

## Restricciones

- **NUNCA** guardar datos financieros reales o confidenciales
- **NUNCA** guardar emails o nombres de personas individuales
- Los OKRs deben ser públicos (accesibles a todo el equipo)
- Máximo 5 Objectives por ciclo (enfoque)
- Cada Objective debe tener 2-5 Key Results
- Key Results deben ser medibles y con fuente de verdad conocida
- Cada KR debe estar vinculada a ≥1 proyecto (si no, es un candidato para eliminar)
