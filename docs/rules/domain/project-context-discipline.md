# Regla: Project Context Discipline — Marcadores STATIC/DYNAMIC en `projects/*/CLAUDE.md`

> **Aplicacion**: solo a `projects/<slug>/CLAUDE.md`. NO se extiende a
> `_HUB.md`, `GLOSSARY.md` ni al `CLAUDE.md` raiz del workspace (que ya cubre
> Rule #11 con limite de 150 lineas).
>
> **Modo**: siempre informativo. El hook PreToolUse muestra ratio actual pero
> NUNCA bloquea writes. Esta regla complementa Rule #11 anadiendo una
> dimension economica (impacto en prefix cache) a la dimension estructural
> (longitud).

---

## Por que existe

El informe "Context vs Tokens" (108 ejecuciones, 2026-05) demostro que el cache
hit rate no depende de la longitud absoluta del fichero, sino de la **estabilidad
del contenido cargado en cada turno**.

`projects/<slug>/CLAUDE.md` tipicamente mezcla:

- **Bloque estable** (~70%): stack, layers, reglas inmutables, glosario, heuristicas.
- **Bloque volatil** (~30%): sprint actual, backlog del dia, metricas, decisiones recientes.

Cualquier edicion del bloque volatil invalida el prefix cache del bloque
estable que vive en el mismo fichero. Resultado: el cache hit rate del proyecto
cae 10-20pp sin razon estructural aparente.

---

## Convencion de marcadores

### Sintaxis

```markdown
<!-- [STATIC] -->
## Arquitectura del proyecto

Contenido estable: stack, layers, glosario, heuristicas validadas.

<!-- [/STATIC] -->

<!-- [DYNAMIC] -->
## Sprint actual

Contenido volatil: sprint vigente, backlog, metricas del dia.

<!-- [/DYNAMIC] -->
```

### Reglas

1. Marcador apertura en linea propia: `<!-- [STATIC] -->` o `<!-- [DYNAMIC] -->`.
2. Marcador cierre en linea propia: `<!-- [/STATIC] -->` o `<!-- [/DYNAMIC] -->`.
3. NO se permite anidar bloques.
4. NO se permite mezclar STATIC dentro de DYNAMIC ni viceversa.
5. Marcadores aplican a bloques delimitados por `##` o `###`.
6. Bloques <3 lineas se ignoran (ruido).
7. Una seccion sin marcador se reporta como `[UNMARKED]` y cuenta como dynamic.

---

## Ejemplos canonicos

### Ejemplo 1 — Stack tecnico (STATIC)

Cambia menos de 1 vez por trimestre. Pertenece al bloque estable.

```markdown
<!-- [STATIC] -->
## Stack tecnico

- Backend: .NET 8 + EF Core + PostgreSQL
- Frontend: Angular 18 + Tailwind
- Infra: Azure (App Service, Storage, Service Bus)
- CI: Azure Pipelines + SonarCloud

<!-- [/STATIC] -->
```

### Ejemplo 2 — Sprint actual (DYNAMIC)

Cambia cada 2 semanas. Pertenece al bloque volatil. Candidato natural a
extraerse a `projects/<slug>/context/current-sprint.md`.

```markdown
<!-- [DYNAMIC] -->
## Sprint actual

- Sprint: 2026-09 (06 may - 19 may)
- Objetivo: cerrar D02 + revisar incidencias BBMM
- Pendientes top 3: AB#1234, AB#1240, AB#1251

<!-- [/DYNAMIC] -->
```

### Ejemplo 3 — Heuristicas validadas (STATIC)

Reglas que el equipo aprendio y consolido. Cambian a ritmo de retro
(cada 2-4 sprints), no diario. Pertenecen al bloque estable.

```markdown
<!-- [STATIC] -->
## Heuristicas del proyecto

- T1: Toda migracion EF Core requiere script de rollback en el mismo PR.
- T2: Los seeders nunca corren en PRO; solo DEV y PRE.
- T3: WIQL queries SIEMPRE filtran IterationPath salvo peticion explicita.

<!-- [/STATIC] -->
```

---

## Como auditar

Comando: `/project-context-audit <slug>`.

Salida ejemplo:

```
Project: trazabios_main
File:    projects/trazabios_main/CLAUDE.md  (471 lines)
Ratio:   static=312 (66%), dynamic=98 (21%), unmarked=61 (13%)
Status:  WARNING (target: static >=80%)
```

- **OK**: ratio static >= 80%. El fichero ayuda al prefix cache.
- **WARNING**: ratio static < 80%. Considerar extraer bloques DYNAMIC o UNMARKED
  a `projects/<slug>/context/<nombre>.md` y referenciarlos por @import.

---

## Interaccion con otras reglas

- **Rule #11 (150 lineas max)**: aplica solo al `CLAUDE.md` raiz del workspace.
  `projects/<slug>/CLAUDE.md` puede superar 150 lineas si el contenido es
  legitimamente estable y aporta valor. Esta regla anade el criterio de
  estabilidad (ratio) al criterio de longitud.
- **SPEC-CACHE-HIT-TRACKING**: cuando `~/.savia/usage.db` tiene >=200 turns en
  los ultimos 14d para el path del proyecto, el comando cruza el ratio teorico
  con el hit rate observado.
- **SPEC-CONTEXT-OPT-GATE**: opera a nivel workspace y proyecto agregado. Esta
  regla opera a nivel fichero individual (`projects/<slug>/CLAUDE.md`).

---

## Que NO hace esta regla

- NO bloquea writes ni commits.
- NO obliga a anadir marcadores. Es una recomendacion auditable.
- NO modifica contenido de `projects/<slug>/CLAUDE.md`. Esa labor la asumen
  specs privadas por proyecto (ej. `projects/trazabios_main/specs/SPEC-D02-*`).
- NO aplica a otros ficheros del proyecto (`_HUB.md`, `GLOSSARY.md`, etc).

---

## Limites conocidos

- El threshold del 80% es heuristico inicial. Se recalibrara tras 30d de datos
  reales (futura `SPEC-CONTEXT-METRICS-DASHBOARD`).
- Falsos positivos UNMARKED en secciones muy cortas: el parser ignora bloques
  <3 lineas.
- Drift (bloque marcado STATIC pero editado semanalmente) se detectara cuando
  el comando cruce marcadores con `git log` (mejora futura).
