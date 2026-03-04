# Guía para CLAUDE.md de Proyecto

## Propósito

Cada proyecto en `projects/{nombre}/` necesita su propio `CLAUDE.md`. Este fichero configura el contexto específico del proyecto sin duplicar las reglas globales del workspace.

## Límites

- **Máximo 150 líneas** (validado por CI)
- **No duplicar** contenido de `CLAUDE.md` raíz ni de reglas de dominio
- **Referenciar** con `@` en vez de copiar

## Plantilla Mínima (~50 líneas)

```markdown
# Proyecto: {Nombre}

## Stack
- Backend: {tecnología}
- Frontend: {tecnología}
- Infraestructura: {cloud + servicios}

## Equipo
@projects/{nombre}/equipo.md

## Convenciones
- Branch naming: feature/{id}-{descripcion}
- Commits: conventional commits
- PR: requiere 1 review + tests passing

## Sprint Actual
- Sprint: {N} ({fecha-inicio} → {fecha-fin})
- Objetivo: {descripción breve}

## Reglas Específicas
- {Regla 1 del proyecto}
- {Regla 2 del proyecto}
```

## Plantilla Completa (~120 líneas)

Añade sobre la mínima:

```markdown
## Arquitectura
@projects/{nombre}/arquitectura.md

## Entornos
- DEV: {url}
- PRE: {url}
- PRO: {url}

## Integraciones
- CI/CD: {pipeline}
- Azure DevOps: {org}/{proyecto}
- Monitoring: {herramienta}

## Decisiones Activas
- ADR-001: {decisión vigente}
- ADR-002: {decisión vigente}

## SDD Config
- Max parallel agents: {N}
- Review mode: {human|agent|hybrid}
- Spec template: @.claude/skills/spec-driven-development/

## Vertical
- Sector: {general|banking|healthcare|education|legal}
- Compliance: {GDPR|PCI-DSS|HIPAA|none}
```

## Errores Comunes

- **Copiar todas las reglas globales** → son heredadas automáticamente
- **Listar los 360+ comandos** → referencia `pm-workflow.md`
- **Incluir datos sensibles** → usar `CLAUDE.local.md` (git-ignorado)
- **Superar 150 líneas** → dividir en ficheros referenciados con `@`

## Jerarquía de Carga

```
CLAUDE.md (raíz, 120 líneas)     ← Siempre se carga
  └── projects/{nombre}/CLAUDE.md  ← Se carga al operar en proyecto
       └── CLAUDE.local.md          ← Datos sensibles (git-ignorado)
```

El `CLAUDE.md` de proyecto complementa al global; nunca lo sustituye.

## Checklist Pre-Commit

- [ ] ≤ 150 líneas
- [ ] No duplica reglas globales
- [ ] Usa `@` para referencias
- [ ] Sin datos sensibles (PAT, URLs reales, nombres reales)
- [ ] Stack y entornos actualizados
- [ ] Sprint actual es el correcto
