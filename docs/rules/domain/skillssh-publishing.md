---
paths:
  - "**/skillssh-*"
  - "**/skills-publish*"
---

# skills.sh Publishing — Adaptación de Skills PM-Workspace

> Marketplace agnóstico: Claude Code, Copilot, Cursor, Gemini.
> Fuente: skills.sh — Instalación con `npx skillsadd <owner/repo>`

---

## Formato skills.sh

Cada skill publicado en skills.sh es un repositorio GitHub con:

```
repo-raíz/
├── .claude/
│   └── commands/
│       └── {skill-name}.md    ← Prompt del skill (formato Claude Code)
├── README.md                  ← Documentación para marketplace
├── package.json               ← Metadata npm-compatible
└── LICENSE                    ← MIT o Apache 2.0
```

### package.json requerido

```json
{
  "name": "@pm-workspace/{skill-slug}",
  "version": "1.0.0",
  "description": "One-line description",
  "keywords": ["claude-code", "pm", "scrum", "skill-category"],
  "author": "pm-workspace",
  "license": "MIT",
  "repository": {
    "type": "git",
    "url": "https://github.com/gonzalezpazmonica/pm-workspace"
  }
}
```

---

## Skills Core para Publicar (5)

| Skill | Slug | Categoría | Keywords |
|---|---|---|---|
| sprint-management | pm-sprint | project-management | sprint, scrum, agile |
| capacity-planning | pm-capacity | planning | capacity, team, forecast |
| pbi-decomposition | pm-pbi-decompose | planning | pbi, user-stories, decomposition |
| spec-driven-development | pm-sdd | development | spec, tdd, agents |
| diagram-generation | pm-diagrams | architecture | diagrams, mermaid, architecture |

---

## Adaptación de Formato

### De pm-workspace a skills.sh

1. Extraer el SKILL.md y convertir a command format
2. Eliminar referencias internas (`@docs/rules/...`)
3. Hacer self-contained: incluir contexto necesario inline
4. Añadir README.md con uso, ejemplos, screenshots
5. Generar package.json con metadata

### Restricciones de privacidad

- NUNCA incluir referencias a proyectos reales
- NUNCA incluir configuración de Azure DevOps específica
- NUNCA incluir PATs, tokens o credenciales
- Solo contenido genérico y reutilizable

---

## Validación Pre-Publicación

| Check | Criterio |
|---|---|
| Self-contained | No refs externas sin resolver |
| Privacy | Sin datos privados (validate_privacy) |
| Size | Comando ≤ 150 líneas |
| Docs | README con uso + ejemplos |
| License | MIT o Apache 2.0 |
| Keywords | ≥ 3 keywords relevantes |

---

## Estructura de Output

```
output/skillssh/
├── pm-sprint/
│   ├── .opencode/commands/sprint-management.md
│   ├── README.md
│   ├── package.json
│   └── LICENSE
├── pm-capacity/
│   └── ...
└── ...
```
