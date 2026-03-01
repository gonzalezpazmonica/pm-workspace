---
name: team-onboarding
description: >
  Genera una guía de onboarding personalizada para un nuevo programador que se incorpora
  a un proyecto. Cubre las Fases 1-2: carga de contexto del proyecto y tour guiado
  del codebase. El mentor humano valida cada checkpoint.
---

# Onboarding de Nuevo Miembro

**Nuevo miembro:** $ARGUMENTS

> Uso: `/team-onboarding "Laura Sánchez" --project GestiónClínica`
>
> Prerequisito: la nota informativa RGPD debe estar firmada antes de registrar

## 1. Cargar perfil de usuario

1. Leer `.claude/profiles/active-user.md` → obtener `active_slug`
2. Si hay perfil activo, cargar (grupo **Team & Workload** del context-map):
   - `profiles/users/{slug}/identity.md`
   - `profiles/users/{slug}/projects.md`
   - `profiles/users/{slug}/tone.md`
3. Adaptar output según `tone.alert_style` (calibrar alertas de sobrecarga)
4. Si no hay perfil → continuar con comportamiento por defecto
> datos del trabajador. Si no existe, sugerir `/team-privacy-notice` primero.

---

## Protocolo

### 1. Leer la skill de referencia

Leer `.claude/skills/team-onboarding/SKILL.md` para entender el flujo completo de 5 fases.
Leer `.claude/skills/team-onboarding/references/onboarding-checklist.md` para el checklist día a día.

### 2. Identificar el proyecto

- Leer `projects/{proyecto}/CLAUDE.md` — constantes, stack, configuración SDD
- Leer `projects/{proyecto}/equipo.md` — miembros actuales, roles, especialización
- Leer `projects/{proyecto}/reglas-negocio.md` — reglas que el nuevo miembro debe conocer

Si el `--project` no se especifica, preguntar al usuario qué proyecto.

### 3. Verificar nota informativa RGPD

Comprobar si existe `projects/{proyecto}/privacy/{nombre}-nota-informativa-*.md`.

- Si existe → continuar
- Si no existe → informar al usuario que debe ejecutar `/team-privacy-notice` primero.
  No bloquear el onboarding (la nota es necesaria para Fase 4, no para Fases 1-2),
  pero recordar que es **obligatoria antes de ejecutar `/team-evaluate`**.

### 4. Fase 1 — Contexto inmediato

Ejecutar el equivalente de `/context-load` pero orientado al nuevo miembro:

**a) Arquitectura general:**
- Leer la estructura de carpetas del source (`projects/{proyecto}/source/`)
- Identificar capas (Domain, Application, Infrastructure, API)
- Listar los módulos/bounded contexts principales
- Explicar los patrones usados (CQRS, MediatR, Clean Architecture, EF Core, etc.)

**b) Convenciones del equipo:**
- Leer `.claude/rules/languages/dotnet-conventions.md` — naming, estructura, reglas de código
- Leer `.claude/rules/github-flow.md` — branching, commits, PRs
- Resumir las 5 convenciones más importantes para el nuevo miembro

**c) Equipo y roles:**
- Presentar los miembros del equipo (de equipo.md) con roles y especialización
- Identificar quién es el mentor asignado y el Tech Lead
- Explicar el concepto de agentes Claude como "developer" (developer_type: agent)

### 5. Fase 2 — Tour del codebase

Generar un tour guiado siguiendo un request típico de principio a fin:

**a) Entry point → Response:**
- Seleccionar un endpoint representativo del proyecto (preferir GET simple)
- Mostrar: Controller → Handler/Query → Repository → Entity → DB
- Explicar cada capa que atraviesa y qué responsabilidad tiene

**b) Patrones con ejemplo real:**
- Un Command + CommandHandler (escritura)
- Un Query + QueryHandler (lectura)
- Un Validator (FluentValidation)
- Una Entity Configuration (Fluent API)
- Un Unit Test (xUnit + Moq)

**c) Dónde encontrar las cosas:**
- Estructura de carpetas del solution
- Dónde viven los tests y cómo ejecutarlos
- Dónde están las specs SDD (si el proyecto usa SDD)
- Cómo funciona el CI/CD (pipeline YAML)

### 6. Generar guía personalizada

Crear un documento Markdown que consolide Fases 1-2 con:
- Diagrama de arquitectura (ASCII art o descripción de capas)
- Listado de módulos con descripción de 1 línea
- 5 convenciones clave del equipo
- Tour del codebase con snippets reales del proyecto
- Próximos pasos (Fase 3: primera task)

Guardar en: `projects/{proyecto}/onboarding/{nombre}-guia.md`

### 7. Presentar al humano

Mostrar la guía generada y preguntar:
- ¿El mentor quiere ajustar algo?
- ¿Está listo para la Fase 3 (primera task asistida)?
- Recordar que tras la Fase 3, el siguiente paso es `/team-evaluate`

---

## Formato del output

```
══════════════════════════════════════════════════════
  ONBOARDING · {nombre} · {proyecto}
══════════════════════════════════════════════════════

  📋 Proyecto: {nombre_proyecto}
  👥 Equipo: {N} miembros + agentes Claude
  🏗️ Stack: .NET 8 / Clean Architecture / CQRS / EF Core
  👤 Mentor: {nombre_mentor} ({rol_mentor})

  ═══ FASE 1: CONTEXTO ═══

  [Arquitectura, módulos, convenciones]

  ═══ FASE 2: TOUR DEL CÓDIGO ═══

  [Flujo request, patrones, estructura]

  ═══ PRÓXIMOS PASOS ═══

  → Fase 3: Mentor asigna primera task (complejidad B/C)
  → Fase 4: /team-evaluate "{nombre}" --project {proyecto}

  📄 Guía guardada en: projects/{proyecto}/onboarding/{nombre}-guia.md

══════════════════════════════════════════════════════
```

---

## Restricciones

- **No asignar tasks** — eso es responsabilidad del mentor (Fase 3)
- **No evaluar competencias** — eso es `/team-evaluate` (Fase 4)
- **No modificar equipo.md** — solo lectura en esta fase
- **No mostrar datos de competencias de otros miembros** — privacidad (RGPD)
- Si el source del proyecto no está clonado, informar y sugerir cómo clonarlo
