# skills-marketplace

## Descripción
Publica, descubre e instala habilidades de PM en formato estándar. Crea un ecosistema de habilidades reutilizables para el workspace.

## Fases de la Pipeline

### 1. Empaquetar Habilidad
Estructura estándar obligatoria:
- `SKILL.md` — Definición y documentación (120 líneas máx)
- `DOMAIN.md` — Contexto y restricciones (40 líneas máx)
- `references/` — Archivos de referencia y ejemplos
- `metadata.json` — Información de catalogación

### 2. Validar
Verifica:
- Estructura de directorios correcta
- Límites de líneas respetados
- Metadata completa y válida
- Sin datos personales identificables (PII)
- Compatibilidad de versiones (habilidades base + dependencias)

### 3. Publicar a Registry
- **Local first**: `data/marketplace/registry.json` mantiene catálogo local
- **GitHub releases**: Distribución futura a través de releases
- Versioning semántico (major.minor.patch)
- Audit trail de publicaciones

### 4. Descubrir
Búsqueda por:
- Palabra clave (nombre, descripción, tags)
- Categoría (planning, development, testing, operations, reporting, compliance, communication)
- Tags adicionales personalizados
- Autor y dependencias

### 5. Instalar
- Descargar desde registry
- Validar integridad y seguridad
- Integrar en `.claude/skills/`
- Resolver dependencias automáticamente
- Actualizar metadata del workspace

## Metadata.json Estándar

```json
{
  "name": "skill-name",
  "version": "1.0.0",
  "author": "nombre-autor",
  "category": "planning|development|testing|operations|reporting|compliance|communication",
  "tags": ["tag1", "tag2"],
  "description": "Breve descripción de la habilidad",
  "dependencies": ["skill1", "skill2"],
  "compatibility": ">=2.0.0",
  "license": "MIT",
  "repository": "https://github.com/user/repo"
}
```

## Categorías de Habilidades

- **planning** — Planificación, roadmaps, sprints
- **development** — Codificación, arquitectura, refactoring
- **testing** — QA, test cases, coverage
- **operations** — Deployment, monitoring, SRE
- **reporting** — Dashboards, analytics, insights
- **compliance** — Auditoría, seguridad, regulación
- **communication** — Documentación, presentaciones, feedback

## Registry Local

Ubicación: `data/marketplace/registry.json`

Estructura:
```json
{
  "skills": [
    {
      "name": "skill-name",
      "version": "1.0.0",
      "category": "planning",
      "installed": false,
      "installed_version": null,
      "path": ".claude/skills/skill-name",
      "published_at": "2026-03-07T12:00:00Z"
    }
  ]
}
```

## Comandos Principales

- `/marketplace-publish {skill}` — Empaquetar y publicar
- `/marketplace-search {query}` — Buscar habilidades
- `/marketplace-install {skill}` — Instalar habilidad
