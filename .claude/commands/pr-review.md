---
name: pr-review
description: >
  Revisión multi-perspectiva de un PR desde 5 ángulos: BA, Developer,
  QA, Security, DevOps. Informe consolidado con veredicto final.
---

# Revisión Multi-Perspectiva de Pull Request

**PR:** $ARGUMENTS

> Acepta: número de PR (Azure DevOps), URL, o rama local. Sin argumento → rama actual vs main.

## Clasificación de hallazgos

- 🔴 **Bloqueante** — corregir antes del merge
- 🟡 **Recomendado** — debería hacerse, no bloquea
- 🔵 **Nota** — sugerencia menor

**Principio:** mejoras "para el futuro" → mejora inmediata. No se difieren correcciones.

## Paso 0 — Obtener diff

`git diff main...HEAD --stat` + `git diff main...HEAD`. Identificar ficheros, líneas, tipos de cambio.

## Las 5 perspectivas

**1. Business Analyst** — ¿Cambios cumplen criterios de aceptación del PBI? ¿Ni más ni menos? Si hay Spec SDD: ¿implementa el contrato exacto?

**2. Developer** — Delegar a agente `code-reviewer` con reglas de `csharp-rules.md`. Evaluar: calidad, arquitectura, mantenibilidad, simplicidad, comentarios XML actualizados.

**3. QA Engineer** — Cobertura de tests (`dotnet test --collect:"XPlat Code Coverage"`), edge cases (null, vacío, límites, concurrencia), riesgo de regresión, scenarios SDD implementados.

**4. Security** — Delegar a `security-guardian`: SQL injection, XSS, secrets, deserialization, CORS, `[Authorize]`, inputs, NuGet CVEs, datos en logs/errores.

**5. DevOps** — Build Release sin warnings, cambios en pipeline/K8s/docker, variables de entorno nuevas, connection strings, logging (Serilog), métricas (OpenTelemetry).

## Informe consolidado

Generar markdown con: resumen (ficheros, líneas, specs asociadas), bloqueantes, recomendados, notas, tabla de veredictos por perspectiva, veredicto final (✅ APROBADO / 🟡 CON CAMBIOS / 🔴 RECHAZADO).

## Restricciones

- No corriges código — señalas problemas y propones soluciones
- Si PR toca Domain Layer → Code Review E1 SIEMPRE humano
- Informe local — publicar en Azure DevOps solo con confirmación humana
