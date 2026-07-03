---
id: SE-252
title: "Bus Factor Shield — Context Domes + Dependency Detection + Knowledge Distribution"
status: IMPLEMENTED
author: Savia
date: 2026-06-30
resolved_at: "2026-07-02"
implementation_pr: "#893"
priority: P0
origin: "Microsiervos 2026-06-29 — Factor autobús; investigación AVL/CST/RIG algorithms"
related: SE-248, ubiquitous-language, codebase-memory-mcp, human-code-map
tags: [bus-factor, knowledge-graph, context-dome, resilience, dependency-detection]
---

# SE-252 — Bus Factor Shield

## Problema

El bus factor de un proyecto es el número mínimo de personas cuya pérdida
lo dejaría incapacitado. El 65% de proyectos OSS tienen BF ≤ 2 (Avelino
et al., ICPC 2016, 133 proyectos). En entornos empresariales la situación
es peor: el conocimiento tácito no está en git — está en la cabeza de
quien lleva años tocando ese módulo.

Los riesgos son reales y no necesitan un autobús: jubilación, baja, cambio
de empresa, o simplemente que alguien "se cansó de ser quien sabe cómo
funciona el tinglado". El coste no es solo técnico: es organizativo,
económico y de velocidad de entrega.

**Savia no detecta este riesgo hoy.** No hay ningún mecanismo que:
- Calcule el BF por módulo en un proyecto
- Avise cuando una persona se convierte en único conocedor de algo
- Genere automáticamente artefactos consultables que sustituyan ese conocimiento tácito
- Sugiera acciones concretas para distribuir el conocimiento antes de que sea urgente

## Solución: tres capas

### Capa 1 — Detección (bus-factor-scan.sh)
Script Python+bash que implementa el algoritmo CST(change-size-cos) sobre
`git blame` + `git log`. Produce un JSON con BF por módulo y por archivo,
con lista de "knowledge owners" y score de riesgo.

### Capa 2 — Cúpulas de contexto (context-dome-generate.sh)
Para cada módulo con BF ≤ 2, genera automáticamente un `CONTEXT_DOME.md`
con:
- Propósito del módulo (extraído de comentarios + CONTEXT.md si existe)
- Decisiones no obvias (ADRs relacionados + commits con "why:" o "because")
- Dependencias externas y puntos de fallo
- Runbook mínimo (comandos de arranque, test, deploy)
- Knowledge owners actuales + sugerencia de backup owner

### Capa 3 — Distribución activa (bus-factor-distribute.sh)
Dado un developer objetivo, genera un plan de knowledge transfer: qué
módulos aprender, en qué orden (por riesgo × complejidad), y las cúpulas
de contexto como material de estudio.

## Artefactos a crear

### Scripts
- `scripts/bus-factor-scan.sh` — orquestador; llama al motor Python
- `scripts/bus-factor-scan.py` — motor CST(change-size-cos); DOA por archivo
- `scripts/context-dome-generate.sh` — genera CONTEXT_DOME.md por módulo
- `scripts/bus-factor-distribute.sh` — plan de knowledge transfer por dev
- `scripts/bus-factor-report.sh` — informe ejecutivo (markdown + JSON)

### Skills
- `.claude/skills/bus-factor-analysis/SKILL.md` + `DOMAIN.md`
- `.claude/skills/context-dome/SKILL.md` + `DOMAIN.md`

### Regla de dominio
- `docs/rules/domain/bus-factor-protocol.md` — cuándo ejecutar, umbrales,
  qué hacer cuando BF=1 se detecta

### Hook
- `.claude/hooks/bus-factor-warn.sh` — PostToolUse: si se modifica un
  archivo con BF=1 y el autor es el único owner, emite warning

### Tests
- `tests/test-se252-bus-factor-scan.bats` — ≥25 tests
- `tests/test-se252-context-dome.bats` — ≥20 tests
- `tests/test-se252-distribute.bats` — ≥15 tests
- `tests/test-se252-hook.bats` — ≥10 tests

## Algoritmo CST(change-size-cos)

Para cada archivo `f` y developer `d`:

```
changes(d, f) = suma de líneas añadidas/eliminadas por d en f (git log -p)
total_changes(f) = suma de changes de todos los developers en f

knowledge_score(d, f) = changes(d, f) / total_changes(f)
                        (coseno normalizado, no simple ratio)

is_owner(d, f) = knowledge_score(d, f) ≥ THRESHOLD  (default: 0.5)
```

El BF de un módulo M = tamaño del menor conjunto de developers C tal que:
```
|{f ∈ M : ∃d ∈ C, is_owner(d, f)}| / |M| ≥ 0.5
```

Es NP-hard en general (set cover), pero en la práctica con BF≤5 la
búsqueda exhaustiva es eficiente.

## Estructura CONTEXT_DOME.md

```markdown
---
module: {nombre}
bus_factor: {N}
risk_level: CRITICAL|HIGH|MEDIUM|LOW
knowledge_owners: [{dev1}, {dev2}]
generated_at: {ISO8601}
spec: SE-252
---

# Context Dome — {nombre}

## Propósito
{extraído de comentarios, README, CONTEXT.md}

## Decisiones no obvias
{commits con "why:", "because", "NOTE:", ADRs referenciados}

## Dependencias críticas
{imports externos, servicios, configuraciones secretas}

## Runbook mínimo
{comandos para: arrancar, testear, desplegar, depurar}

## Knowledge owners actuales
| Developer | Score | Módulos conocidos |
|-----------|-------|------------------|
| ...       | ...   | ...              |

## Plan de distribución sugerido
{próximo developer a onboardear + módulos prioritarios}

## Historial de cambios relevantes
{últimos 10 commits con impacto semántico significativo}
```

## Criterios de aceptación

### CA-1: Detección básica
```gherkin
Dado un repositorio git con historial de al menos 10 commits
Cuando ejecuto bus-factor-scan.sh --project {path}
Entonces obtengo un JSON con {modules: [{name, bus_factor, owners, risk}]}
Y el JSON es válido (jq . pasa sin error)
Y cada módulo tiene bus_factor ≥ 1
```

### CA-2: Detección de BF=1
```gherkin
Dado un archivo modificado exclusivamente por un developer
Cuando ejecuto el scan
Entonces ese archivo aparece con bus_factor=1 y risk_level=CRITICAL
```

### CA-3: Generación de cúpula
```gherkin
Dado un módulo con BF ≤ 2
Cuando ejecuto context-dome-generate.sh --module {path}
Entonces se crea CONTEXT_DOME.md con todas las secciones requeridas
Y la sección knowledge_owners lista los developers correctos
Y la sección runbook_minimo no está vacía
```

### CA-4: Plan de distribución
```gherkin
Dado un developer objetivo {dev}
Cuando ejecuto bus-factor-distribute.sh --target {dev}
Entonces obtengo una lista ordenada de módulos a aprender
Ordenada por (risk_level DESC, bus_factor ASC, complexity ASC)
Con referencia a la CONTEXT_DOME.md de cada módulo
```

### CA-5: Hook de aviso
```gherkin
Dado que se está modificando un archivo con BF=1
Y el modificador es el único owner
Cuando se activa el hook PostToolUse (Write/Edit)
Entonces se emite un warning con: módulo, BF actual, acción sugerida
Y el hook NO bloquea la operación (modo warn-only)
```

### CA-6: Idempotencia
```gherkin
Dado un repo sin cambios entre dos ejecuciones
Cuando ejecuto el scan dos veces
Entonces los JSONs de output son idénticos (bit-exact en scores)
```

### CA-7: Escala
```gherkin
Dado un repo con 500+ archivos y 50+ developers
Cuando ejecuto el scan
Entonces completa en menos de 120 segundos
```

### CA-8: Sin dependencias externas bloqueantes
```gherkin
El scan funciona con solo: git, python3 (stdlib), bash
jq es opcional (fallback python3 -m json.tool)
No requiere: pip install, npm, ruby gems
```

## Umbrales y configuración

Variables de entorno / `.bus-factor.yml` en raíz del proyecto:

| Variable | Default | Descripción |
|---|---|---|
| `BF_OWNERSHIP_THRESHOLD` | `0.50` | Score mínimo para ser "owner" |
| `BF_RISK_CRITICAL` | `1` | BF ≤ N → CRITICAL |
| `BF_RISK_HIGH` | `2` | BF ≤ N → HIGH |
| `BF_RISK_MEDIUM` | `3` | BF ≤ N → MEDIUM |
| `BF_MIN_COMMITS` | `5` | Ignorar archivos con < N commits (evita noise) |
| `BF_EXCLUDE_PATTERNS` | `vendor/,node_modules/,*.lock` | Dirs/patrones a ignorar |
| `BF_OUTPUT_DIR` | `output/bus-factor/` | Dónde escribir JSONs y reportes |

## Integración con el ecosistema Savia

### Con codebase-memory-mcp
Si el KG está indexado, el scan puede enriquecer los nodos `Function` y
`Module` con propiedades `bus_factor` y `knowledge_owners`. Query Cypher:
```cypher
MATCH (f:File) WHERE f.bus_factor = 1
RETURN f.path, f.knowledge_owners ORDER BY f.path
```

### Con ubiquitous-language skill
El context dome reutiliza el CONTEXT.md generado por el skill
`ubiquitous-language` como fuente del "Propósito del módulo". Si no existe,
lo genera en modo básico.

### Con human-code-map skill
El plan de distribución generado por `bus-factor-distribute.sh` es
el input natural para que el skill `human-code-map` genere sesiones
de onboarding estructuradas.

### Con overnight-sprint skill
En modo `--mode bus-factor-reduction`, overnight-sprint puede ejecutar
autónomamente: generar cúpulas de contexto para los módulos más críticos
y crear PRs con los artefactos para revisión humana.

## Limitaciones explícitas

1. **El score es una aproximación**: git blame mide contribución en líneas,
   no comprensión real. Alguien puede entender un módulo sin haberlo
   modificado (code review, documentación).

2. **Merges y rebases distorsionan**: blame history reescrita pierde
   contexto. El script detecta esto y añade `warning: rebase_detected`.

3. **No detecta conocimiento organizativo**: quién sabe la contraseña,
   quién tiene el contacto del proveedor, quién entiende los requisitos
   de negocio. Eso es labor de `org-stakeholder-mapper`.

4. **Human decides**: el script nunca auto-rota tareas ni envía emails.
   Genera findings y planes. La acción correctiva es humana.

## Ejecución de referencia

```bash
# Análisis completo de un proyecto
bash scripts/bus-factor-scan.sh --project projects/trazabios --output output/bus-factor/

# Generar cúpulas para módulos críticos
bash scripts/context-dome-generate.sh --project projects/trazabios --min-risk HIGH

# Plan de distribución para onboardear a un nuevo dev
bash scripts/bus-factor-distribute.sh --project projects/trazabios --target "nuevo-dev"

# Informe ejecutivo
bash scripts/bus-factor-report.sh --project projects/trazabios --format markdown
```

## Riesgo de implementación: MEDIO

- Solo requiere git + python3 stdlib + bash
- No modifica el repositorio del proyecto analizado (read-only)
- Output en `output/bus-factor/` (gitignored)
- Hook en modo warn-only (no bloquea)
- BATS tests reproducibles sin acceso a repositorios externos
