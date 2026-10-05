---
layer: peripheral
name: understand-anything
description: Usar cuando se necesita analizar un codebase con Understand-Anything para generar knowledge graphs estructurales y de dominio.
allowed-tools: [Bash, Read, Glob]
metadata:
  # --- metadata.savia.* (SE-333) ---
  savia.category: analysis
  savia.maturity: beta
  savia.context: project
  savia.priority: medium
  savia.summary: "Understand-Anything (Lum1104/Understand-Anything) analiza codebases via pipeline multi-agente y genera knowledge-graph.json con nodos estructurales, de dominio y de conocimiento. Compatible con 13 lenguajes y OpenCode nativo. Bridge: scripts/ua-bridge.sh. Si UA no está instalado, degrada sin error (exit 0). Ref: SPEC-SE-088-UA-ADOPT."
  savia.tags: "knowledge-graph, codebase, domain, onboarding, diff-impact, ua"
  savia.user-invocable: True
---

# Understand-Anything — Knowledge Graphs para Savia

Plugin externo [Understand-Anything](https://github.com/Lum1104/Understand-Anything)
(MIT, TypeScript/pnpm) que analiza codebases via pipeline multi-agente y genera
`knowledge-graph.json` con tres capas:

- **Grafo estructural**: archivos, funciones, clases, dependencias
- **Grafo de dominio**: procesos de negocio, flujos, steps
- **Grafo de conocimiento**: entidades, claims, relaciones (Karpathy-pattern)

Compatible con 13 lenguajes. Dashboard interactivo React con force-directed
layout, búsqueda semántica y tours guiados.

## Bridge

Savia accede a UA exclusivamente via `scripts/ua-bridge.sh`:

```bash
bash scripts/ua-bridge.sh check          # UA instalado?
bash scripts/ua-bridge.sh analyze [path] # generar knowledge-graph.json
bash scripts/ua-bridge.sh diff --count   # ficheros versionados cambiados (staged + unstaged)
bash scripts/ua-bridge.sh domain [path]  # extraer conceptos de negocio
bash scripts/ua-bridge.sh dashboard      # lanzar dashboard interactivo
bash scripts/ua-bridge.sh onboard [path] # guía de onboarding
```

## Comandos Savia

| Comando | Función |
|---------|---------|
| `/ua-analyze [path]` | Analizar codebase y generar knowledge-graph.json |
| `/ua-domain [path]` | Extraer dominios de negocio |
| `/ua-diff` | Impacto de cambios no commiteados |
| `/ua-chat {query}` | Preguntas sobre el grafo |
| `/ua-dashboard` | Lanzar dashboard interactivo |
| `/ua-onboard [path]` | Generar guía de onboarding |
| `/ua-install` | Instalar o actualizar UA plugin |

## Activación

UA no se instala con Savia. Es opt-in:

```bash
# 1. Instalar
bash scripts/ua-install.sh

# 2. Verificar
bash scripts/ua-bridge.sh check
```

Si `check` retorna exit 1, todos los comandos degradan gracefully:
- `diff --count` → imprime `0`, exit 0
- `analyze`, `domain`, `onboard`, `chat`, `dashboard` → "UA not installed" en stderr, exit 0

Con UA instalado, los fallos se reportan, no se maquillan:

| Exit | Significado |
|------|-------------|
| 0 | OK, o UA no instalado (degradación) |
| 1 | Entrada inválida (ruta inexistente, `chat` sin query, opción o subcomando desconocido) o el comando UA falló |
| 2 | `opencode` no está en el PATH |

`diff` cuenta ficheros versionados cambiados (staged + unstaged, sin duplicar),
no nodos: es una aproximación del impacto. Fuera de un repo git imprime `0` y
avisa en stderr.

## Integración con sistemas Savia

### Memory Feed

```
knowledge-graph.json → memory-agent
  DOMAIN_ENTITY edges → memoria episódica
  DEPENDS_ON edges    → dependencias técnicas
  IMPLEMENTS edges    → funciones → specs/requisitos
```

### Aviso de impacto en CI (snippet, no cableado)

No está integrado en `pr-plan` (allí G16 es eval-lint). Snippet para un gate propio:

```bash
ua_diff_count=$(bash scripts/ua-bridge.sh diff --count)
[[ $ua_diff_count -gt 50 ]] && echo "WARN: diff impact >50 files changed"
```

## Fallback

Si UA no está disponible, no hay análisis de codebase equivalente. Lo más
cercano es el grafo de memoria de Savia (`scripts/knowledge-graph.py`), que no
recibe una ruta: ingiere `output/.memory-store.jsonl`, `docs/ROADMAP.md`,
`docs/rules/domain/*.md` y `~/.savia/memory-cache.db` del workspace:

```bash
python3 scripts/knowledge-graph.py build
python3 scripts/knowledge-graph.py query "SE-162"
```

El bridge nunca ejecuta este fallback por su cuenta: si `opencode` falta o el
comando UA falla, sale con error para que no pase por éxito.

## Cuándo usar

- Onboarding de proyecto nuevo (>500 ficheros)
- Análisis de impacto antes de refactoring mayor
- Extracción de dominio de negocio de codebase legacy
- Gate de CI para estimar scope de un PR

## Cuándo NO usar

- Proyectos N4b (PM-Only) — el grafo mezcla código y no puede viajar al repo
- Proyectos pequeños (<100 ficheros) — overhead supera el beneficio
- Sesiones one-shot sin instalación previa de UA

## Referencias

- Upstream: <https://github.com/Lum1104/Understand-Anything> (MIT)
- Bridge: `scripts/ua-bridge.sh`
- Spec: `docs/specs/SPEC-SE-088-UA-ADOPT.spec.md`
- Skills relacionadas: `knowledge-graph`, `codegraph`, `agent-code-map`
