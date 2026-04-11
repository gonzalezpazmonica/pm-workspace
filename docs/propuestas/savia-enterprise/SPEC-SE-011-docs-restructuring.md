# SPEC-SE-011 — Documentation Restructuring & Narrative Realignment

> **Prioridad:** P0 · **Estima:** 6 días · **Tipo:** información + narrativa

## Objetivo

Reestructurar la documentación completa del repositorio (`docs/`, README,
CLAUDE.md, CHANGELOG, traducciones) para que refleje de forma coherente la
evolución Savia → Savia Enterprise. El objetivo no es reescribir por reescribir:
es que **un visitante nuevo entienda en 60 segundos** que Savia es una
arquitectura agentic soberana con capa Enterprise opt-in, y que un usuario
actual pueda seguir encontrando lo que ya sabía sin rupturas.

## Principios afectados

- #3 Honestidad radical (la doc dice lo que el código hace, sin inflar)
- #7 Protección de identidad (Savia sigue siendo Savia; Enterprise no borra Core)

## Diseño

### 1. Taxonomía nueva de `docs/`

```
docs/
├── README.md                      ← índice navegable del directorio
├── getting-started/               ← primeros pasos (Core + Enterprise)
│   ├── community.md               ← usuario Core
│   ├── enterprise.md              ← usuario Enterprise
│   └── developer.md               ← contribuir
├── core/                          ← conceptos de Savia Core
│   ├── principles.md              ← los 7 principios
│   ├── spec-driven-development.md
│   ├── memory-system.md
│   ├── savia-shield.md            ← consolida guías existentes
│   └── best-practices.md
├── enterprise/                    ← módulos Enterprise
│   ├── overview.md                ← qué es y qué no es
│   ├── foundations.md             ← arquitectura de capas (SE-001)
│   ├── multi-tenant.md            ← SE-002
│   ├── mcp-catalog.md             ← SE-003
│   ├── agent-interop.md           ← SE-004
│   ├── sovereign-deployment.md    ← SE-005
│   ├── governance.md              ← SE-006
│   ├── onboarding.md              ← SE-007
│   ├── licensing.md               ← SE-008
│   ├── observability.md           ← SE-009
│   └── migration.md               ← SE-010
├── adapters/                      ← capa agnóstica
│   ├── mcp-servers.md
│   ├── agent-runtimes.md
│   ├── llm-providers.md
│   └── observability-backends.md
├── operations/                    ← día a día
│   ├── flow.md                    ← savia-flow (reubicado)
│   ├── models.md                  ← savia-models (reubicado)
│   ├── bridge.md                  ← savia-claw-bridge (reubicado)
│   └── emotional-regulation.md    ← reubicado
├── reference/                     ← material denso
│   ├── agents-catalog.md
│   ├── commands-catalog.md
│   ├── skills-catalog.md
│   └── rules-catalog.md
├── propuestas/                    ← RFCs (sin cambios)
└── i18n/                          ← traducciones consolidadas
    ├── en/
    ├── fr/
    ├── de/
    ├── it/
    ├── pt/
    ├── ca/
    ├── eu/
    └── gl/
```

### 2. README.md rewrite (lead statement)

Los primeros 3 párrafos deben contestar:

- **Qué es:** "Arquitectura agentic soberana, MIT, con capa Enterprise opcional"
- **Para quién:** "PMs, arquitectos e ingenieros en sectores regulados"
- **Qué la diferencia:** "Datos del cliente nunca salen. Sin vendor lock-in. Honestidad radical por defecto"

Debajo: tabla Core vs Enterprise, diagrama de capas de SE-001, enlaces a
`getting-started/`. Los 496 comandos, 82 skills, 46 agentes bajan al
`reference/` — siguen existiendo pero no dominan la portada.

### 3. CLAUDE.md realineado

- Mantener ≤150 líneas (regla #11)
- Añadir una línea en "Estructura" que refleje `.claude/enterprise/`
- Nueva sección "Capas" con 4 líneas: Core / Adapters / Enterprise / Principios inmutables
- Los 7 principios fundacionales explícitos (hoy están en archivo aparte)

### 4. CHANGELOG narrativo — hito "Savia Enterprise"

Crear entrada de hito antes de la próxima versión:

```markdown
## [X.Y.Z] — YYYY-MM-DD — Savia Enterprise

Hito narrativo: Savia se consolida como arquitectura agentic soberana con
capa Enterprise opt-in, MIT, sin vendor lock-in. Ver docs/enterprise/overview.md.

### Added
- docs/enterprise/ con 10 módulos documentados
- .claude/enterprise/ estructura opt-in (SE-001)
...
```

Los Eras existentes NO se tocan — el histórico es inmutable.

### 5. Regla `readme-update.md` extendida

Añadir sección:
- Al tocar módulo Enterprise → actualizar `docs/enterprise/{modulo}.md`
- Al tocar Core → actualizar `docs/core/*`
- Las traducciones siguen alineadas con la versión canónica (castellano)
- Nueva sección en la regla: "Separación Core vs Enterprise en ejemplos"

### 6. Política de traducciones

- **Canónica:** castellano (`docs/`)
- **Prioritarias:** inglés (activa el mercado internacional)
- **Comunidad:** el resto (fr, de, it, pt, ca, eu, gl) — best effort
- **Política de stale:** si la canónica cambia >20% en una sección, la
  traducción se marca `stale: YYYY-MM-DD` en frontmatter y no bloquea release
- **Savia Shield guides** (9 idiomas actuales) → migran a `i18n/{lang}/savia-shield.md`

### 7. Navegabilidad como sitio

Preparar `docs/` para ser renderizable por MkDocs, Docusaurus o similares
**sin acoplamiento**. Solo añadir:
- `mkdocs.yml` opcional (no obligatorio)
- Frontmatter YAML en cada página: `title`, `order`, `category`, `stale`
- Enlaces relativos consistentes

Esto habilita el posicionamiento público (apuesta 5.3 del informe: "Savia
como portfolio ejecutable") sin casarse con ningún generador estático.

### 8. Metadatos públicos del repo GitHub

Actualizar también los elementos visibles fuera del repo:

- **Descripción del repo** (`gh repo edit --description`) — hoy dice "PM
  automatizada con IA"; debe reflejar la tesis Enterprise en una frase corta.
  Propuesta: *"Sovereign agentic architecture. MIT. Zero vendor lock-in. Core
  + opt-in Enterprise modules."*
- **Topics** (`gh repo edit --add-topic`) — añadir: `agentic`, `mcp`,
  `ai-sovereignty`, `spec-driven-development`, `ai-act`, `enterprise-ai`,
  `agent-framework`. Mantener los existentes que sigan siendo ciertos.
- **Homepage URL** — apunta a `docs/enterprise/overview.md` o al futuro sitio
  público cuando exista.
- **About section** — revisar que refleja la nueva narrativa.
- **Social preview image** — si existe, refresh con diagrama de capas de SE-001.
- **Pinned repositories** (en el perfil de la autora) — considerar fijar los
  MCP servers de SE-003 como repos destacados cuando existan.

Esto se hace con `gh` CLI en un script idempotente
(`scripts/sync-github-metadata.sh`) para que sea reproducible y revisable.

### 9. Redirects de compatibilidad

Los ficheros movidos mantienen un stub en la ruta antigua durante 60 días:

```markdown
# Moved
This document has moved to [docs/core/savia-shield.md](core/savia-shield.md).
```

Evita romper enlaces externos existentes.

## Criterios de aceptación

1. Nueva taxonomía `docs/` implementada con los 5 subdirectorios principales
2. README.md reescrito con los 3 párrafos lead + diagrama de capas
3. CLAUDE.md actualizado ≤150 líneas con sección "Capas"
4. Hito "Savia Enterprise" añadido en CHANGELOG sin tocar historial
5. `readme-update.md` extendido con política Core vs Enterprise
6. Política de traducciones documentada y aplicada a los 9 idiomas existentes
7. Stubs de redirección creados para los ficheros movidos
8. Frontmatter de navegación en todas las páginas nuevas
9. Test manual: visitante llega al README y en 60s sabe qué es, para quién y qué la diferencia
10. Test manual: usuario actual busca `savia-shield` en el README viejo y llega a la nueva ubicación sin fricción
11. Descripción, topics y homepage del repo GitHub actualizados vía `scripts/sync-github-metadata.sh`
12. About section del repo reescrita para reflejar tesis Enterprise
13. Script `sync-github-metadata.sh` idempotente, revisable, versionado en repo

## Out of scope

- Elección de generador estático (MkDocs / Docusaurus / Hugo)
- Publicación como sitio público (`savia.dev`, etc.)
- Campaña de marketing
- Reescritura de las propuestas existentes (SPEC-003..010) — intocables

## Dependencias

- SE-001 (layering) — necesita estar aprobado antes de escribir `foundations.md`
- SE-008 (licensing) — necesita estar aprobado antes de escribir `licensing.md`
- El resto de specs (SE-002 a SE-010) pueden documentarse en paralelo a su implementación

## Impacto estratégico

Esta spec ejecuta directamente tres apuestas del informe:

- **5.2** Reposicionamiento AI Solutions Architect → README y `docs/` son la
  cara pública del reposicionamiento
- **5.3** Savia como portfolio ejecutable → sin doc navegable no hay portfolio
- **5.10** Manifiesto técnico → `docs/core/principles.md` + README son el
  ancla del manifiesto

Sin SE-011 el resto de specs son técnicamente correctas pero **ilegibles
desde fuera**, y eso es el problema que el informe identifica como número 1:
*"Tu mayor riesgo no es competencia técnica; es indefinición estratégica."*
