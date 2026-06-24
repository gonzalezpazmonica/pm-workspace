---
skill_id: sdd-spec-writer-runbook
title: SDD Spec Writer — Runbook de especificacion
status: CALIBRATED
origin_agent: sdd-spec-writer
extracted_by: SE-099
extracted_at: 2026-06-24
sla: agent ≤4096B (Rule #22)
---

# SDD Spec Writer — Runbook

Cargado por el agente `sdd-spec-writer` para estructura completa y checklist.

## Fuentes que consultar antes de escribir

```bash
az boards item show --id $TASK_ID --output json    # Task en AzDO
az boards item show --id $PBI_ID --output json     # PBI padre
```

Tambien:
- `.claude/skills/spec-driven-development/SKILL.md` — metodologia SDD
- `.claude/skills/spec-driven-development/references/spec-template.md` — plantilla canonica
- `.claude/skills/spec-driven-development/references/layer-assignment-matrix.md` — agente vs humano
- `projects/[proyecto]/CLAUDE.md` — contexto del proyecto
- `projects/[proyecto]/RULES.md` — reglas de negocio
- Codigo fuente relevante (interfaces, contratos, tests similares)

## Decision: agente o humano

**Agente Claude si:**
- Task en capas Application, Infrastructure, o Domain con patrones claros
- Sin interaccion UI compleja (MVC/Blazor con logica de estado compleja → humano)
- Sin acceso a sistemas externos no documentados
- Patron repetible (Command Handler, Repository, Service, Unit Test)
- Complejidad ≤8h (SDD_DEFAULT_MAX_TURNS = 40)

**Humano si:**
- Task tipo E1 (Code Review) — SIEMPRE humano
- Requiere decisiones de diseno no documentadas
- Implica UI/UX con criterios esteticos subjetivos
- Requiere conocimiento de sistemas legacy no documentados

## Estructura de la Spec (obligatoria)

```markdown
# Spec: [AB#XXXX] [Titulo de la Task]
## Metadatos
- task_id, pbi_id, proyecto, sprint, developer_type, max_turns, modelo
## Objetivo
## Contexto (codigo existente relevante)
## Contrato de implementacion
  ### Inputs
  ### Outputs / Return values
  ### Efectos secundarios (DB, eventos, logs)
## Ficheros a crear / modificar (paths exactos)
## Tests requeridos (casos especificos con datos)
## Criterios de aceptacion (verificables automaticamente)
## Restricciones y convenciones
## Comandos de verificacion
  dotnet build --configuration Release
  dotnet test --filter "FullyQualifiedName~[NombreTest]"
```

## Checklist de calidad antes de guardar

- [ ] Puede un agente empezar sin leer ningun otro fichero no referenciado?
- [ ] Estan todos los paths de ficheros completos y correctos?
- [ ] Los criterios de aceptacion son verificables con `dotnet test`?
- [ ] El contrato define tipos exactos (no "un objeto" sino `OrderDto`)?
- [ ] Hay al menos 3 test cases con datos concretos (no "ejemplo valido")?
- [ ] El comando de verificacion final puede ejecutarse sin argumentos?

## Decision Trees

- Business rules missing/unclear → escalar a `business-analyst` antes de escribir
- Architecture undefined → escalar a `architect` para propuesta de diseno primero
- Spec falla quality checklist → revisar hasta que todos los items pasen
- Task demasiado grande (>8h) → dividir en multiples specs con orden de dependencias
- Security concern detectado → agregar seccion de seguridad + recomendar `/security-review`

## Handoff Format (SPEC-121)

E1→E2 handoff a `dotnet-developer` o `frontend-developer` tras aprobacion:

```yaml
---
handoff:
  to: dotnet-developer
  spec: SPEC-NNN
  stage: E2
  context_hash: sha256:<8-char-prefix>
  reason: "Spec approved, ready for implementation"
  termination_reason: completed
  artifacts:
    - docs/propuestas/SPEC-NNN-title.md
---
```

Ver `docs/rules/domain/agent-handoff-protocol.md` para campos y validador.

## Context Index

Antes de escribir, verificar `projects/{project}/.context-index/PROJECT.ctx` si existe.
Usar entradas `[location]` para requisitos/arquitectura/reglas.
Usar entradas `[digest-target]` para ubicar la spec generada.
