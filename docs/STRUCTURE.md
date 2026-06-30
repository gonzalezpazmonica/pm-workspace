---
title: "docs/ — Estructura oficial"
category: meta
order: 0
stale: null
---

# docs/ — Estructura oficial

Taxonomía canónica del directorio `docs/` en pm-workspace.
Este fichero es la fuente de verdad para decidir dónde va cada documento nuevo.

## Nivel 1 (raíz de docs/)

Solo estos ficheros viven en la raíz de `docs/`:

| Fichero | Propósito |
|---|---|
| `ROADMAP.md` | Roadmap unificado del workspace — todas las eras y specs |
| `RESOLVER.md` | Dispatch de intent → skill / agente (SE-160) |
| `ARCHITECTURE.md` | Arquitectura del workspace: capas, patrones, decisiones de diseño |
| `STRUCTURE.md` | Este fichero — taxonomía oficial de docs/ |
| `INDEX.md` | Índice navegable de los documentos más importantes |

Cualquier otro `.md` en la raíz de `docs/` es candidato a reubicación.
El script `scripts/docs-audit.sh` detecta automáticamente estos casos.

## Subcarpetas

### `docs/core/` — Conceptos fundamentales

Documentos que explican **qué es** Savia y cómo funciona internamente.

| Contenido esperado |
|---|
| Principios fundacionales (los 7) |
| Memory system |
| Spec-Driven Development (SDD) |
| Savia Shield |
| Best practices Claude Code / OpenCode |
| Context engineering |

### `docs/guides/` — Guías de uso por rol

Documentación orientada a **cómo hacer** algo. Una guía = un objetivo concreto.
Formato: `guide-{tema}.md` para castellano, `guide-{tema}.{lang}.md` para otras lenguas.

### `docs/rules/` — Reglas y políticas

Reglas que rigen el comportamiento del workspace.

```
docs/rules/
├── domain/    ← reglas de dominio (CLAUDE.md lazy-refs)
├── languages/ ← language packs
└── learned/   ← reglas aprendidas de experiencia
```

Cada regla tiene frontmatter `context_tier: L0..L4`.

### `docs/specs/` — Specs ejecutables de alto nivel

Specs en estado PROPOSED/APPROVED/IMPLEMENTED que NO son propuestas de SE-*.
Formato: `SPEC-{id}-{slug}.spec.md` o `SE-{id}-{slug}.spec.md`.

### `docs/propuestas/` — Backlog de specs (RFC)

Specs en fase exploratoria o de propuesta. No tocar el contenido existente.
Subdirectorios por temática: `savia-enterprise/`, `core/`, etc.

### `docs/decisions/` — ADRs y decisiones de arquitectura

Architecture Decision Records. Formato:
`adr-{NNN}-{slug}.md` con frontmatter `status: proposed|accepted|deprecated|superseded`.

### `docs/operations/` — Runbooks y procedimientos

Documentación operacional del día a día: procedimientos, runbooks, playbooks.
Ficheros que antes vivían en raíz (`savia-flow/`, `savia-models/`, etc.) migran aquí.

### `docs/learning/` — Investigación y hallazgos

Resultados de investigación técnica, autoresearch, casos de estudio.
No son guías ni reglas — son hallazgos y análisis.

### `docs/enterprise/` — Módulos Enterprise (opt-in)

Documentación de la capa Enterprise. Un fichero por módulo SE-*.
Solo se escribe cuando el módulo correspondiente está IMPLEMENTED o APPROVED.

### `docs/getting-started/` — Primeros pasos

Documentación de onboarding para distintos perfiles:
`community.md`, `enterprise.md`, `developer.md`.

### `docs/adapters/` — Capa agnóstica (MCP, runtimes, LLMs)

Documentación de integraciones con herramientas externas.
No acoplada a ningún proveedor específico.

### `docs/reference/` — Material de referencia denso

Catálogos exhaustivos: agentes, comandos, skills, reglas.
Generados automáticamente o actualizados por scripts.

### `docs/i18n/` — Traducciones

```
docs/i18n/
├── en/   ← inglés (prioritario)
├── fr/   ← francés (comunidad)
├── de/   ← alemán (comunidad)
├── it/   ← italiano (comunidad)
├── pt/   ← portugués (comunidad)
├── ca/   ← catalán (comunidad)
├── eu/   ← euskera (comunidad)
└── gl/   ← gallego (comunidad)
```

Canónica: castellano (`docs/`). Política de stale: si la canónica cambia >20%,
marcar `stale: YYYY-MM-DD` en frontmatter de la traducción.

### `docs/archive/` — Documentos obsoletos

Documentos reemplazados o ya no relevantes. No eliminar — mantener para histórico.
Añadir frontmatter `archived: YYYY-MM-DD` y enlace al sustituto si existe.

## Reglas de clasificación

1. **¿Explica qué es Savia?** → `docs/core/`
2. **¿Enseña a hacer algo concreto?** → `docs/guides/`
3. **¿Es una regla que el workspace aplica?** → `docs/rules/domain/`
4. **¿Es una spec ejecutable?** → `docs/specs/`
5. **¿Es una propuesta en exploración?** → `docs/propuestas/`
6. **¿Es una decisión arquitectónica registrada?** → `docs/decisions/`
7. **¿Es un procedimiento operacional?** → `docs/operations/`
8. **¿Es un hallazgo de investigación?** → `docs/learning/`
9. **¿Es una traducción?** → `docs/i18n/{lang}/`
10. **¿Ya no es relevante?** → `docs/archive/`

## Auditoría automática

```bash
# Detecta orphans, candidatos a reubicación y subdirs grandes
bash scripts/docs-audit.sh

# Informe JSON
bash scripts/docs-audit.sh --json

# Guardar en output/
bash scripts/docs-audit.sh --output auto
```

Ver también: [docs/INDEX.md](INDEX.md) para los documentos más importantes.
