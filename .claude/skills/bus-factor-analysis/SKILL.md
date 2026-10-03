---
layer: peripheral
name: bus-factor-analysis
description: >
  Detecta el Bus Factor por modulo en un repositorio git usando el algoritmo
  CST(change-size-ratio). Genera JSON con BF, owners, riesgo, y avisa cuando
  un solo dev conoce un modulo critico.
metadata:
  # --- metadata.savia.* (SE-333) ---
  savia.category: resilience
  savia.maturity: beta
  savia.context: L2
  savia.se: SE-252
  savia.summary: Skill de deteccion de riesgo de conocimiento. Analiza git history para identificar modulos con un unico conocedor y genera planes de mitigacion.
  savia.tags: "bus-factor, knowledge-graph, git-analysis, risk, resilience"
---

# Bus Factor Analysis

## Descripcion

Detecta el Bus Factor (BF) de cada modulo de un proyecto analizando el
historial git con el algoritmo CST(change-size-ratio). Un dev es owner de un
fichero si firma al menos `BF_OWNERSHIP_THRESHOLD` (0.50) de las lineas
anadidas+eliminadas (`git log --numstat --follow`). El BF de un modulo es el
menor numero de owners que cubren al menos el 50% de sus ficheros (greedy set
cover; detalle en `DOMAIN.md`):
- BF=0 → UNKNOWN: ningun fichero tiene historial atribuible (sin commits o solo bots)
- BF=1 → CRITICAL: un solo dev es owner de al menos la mitad de los ficheros
- BF=2 → HIGH: hacen falta dos devs para cubrir la mitad
- BF=3 → MEDIUM
- BF>3 → LOW

Ojo: BF=1 no significa que nadie mas haya tocado el modulo. Con 3 ficheros,
2 de Ana y 1 de Bob, el BF es 1 aunque Bob conozca su fichero.

Identidad de autor: el email tras aplicar `.mailmap` del repo (`%aE`); dos
emails de la misma persona cuentan como uno solo si el `.mailmap` los une.
Se excluyen bots: `[bot]`, `dependabot`, `renovate`, `github-actions`,
`snyk-bot`, `automated` (buscados en nombre y email, asi que una persona con
uno de esos terminos en el nombre tambien se excluye), `action@github.com`, y
partes locales `ci@`, `noreply@` o `no-reply@` como segmento propio (al inicio
o tras `-`, `_`, `.`, `+`: `gitlab-ci@`, `build-noreply@`). `marci@`,
`marcinoreply@` y `*@users.noreply.github.com` son humanos y SI cuentan.

## Cuando usar

- Pre-sprint si hay devs de vacaciones o baja
- Tras la salida de cualquier miembro del equipo
- Mensualmente como revision de riesgo organizativo
- Cuando un nuevo dev se incorpora (para generar su plan de onboarding)
- Cuando se detecta siloizacion de conocimiento

## Rutas criticas

- Motor Python:   `scripts/bus-factor-scan.py`
- Orquestador:    `scripts/bus-factor-scan.sh`
- Cupulas:        `scripts/context-dome-generate.sh`
- Distribucion:   `scripts/bus-factor-distribute.sh`
- Informe:        `scripts/bus-factor-report.sh`
- Hook PostWrite: `.claude/hooks/bus-factor-warn.sh`
- Protocolo:      `docs/rules/domain/bus-factor-protocol.md`
- DOMAIN:         `.claude/skills/bus-factor-analysis/DOMAIN.md`

## Flujo de uso

```bash
# 1. Escanear proyecto
bash scripts/bus-factor-scan.sh --project <path>

# 2. Generar cupulas para modulos criticos
bash scripts/context-dome-generate.sh --project <path> --min-risk HIGH

# 3. Plan de distribucion para un dev
bash scripts/bus-factor-distribute.sh --project <path> --target <dev-email>

# 4. Informe ejecutivo
bash scripts/bus-factor-report.sh --project <path> --format markdown
```

## Output esperado

JSON en `output/bus-factor/<proyecto>-<YYYYMMDD>T<HHMMSS>Z.json` con estructura:
```json
{
  "generated_at": "2026-10-03T05:17:17Z",
  "project": "...",
  "modules": [{"name": "...", "bus_factor": 1, "risk_level": "CRITICAL", "owners": [...], "files": [...], "warnings": []}],
  "summary": {"total_modules": 11, "critical": 2, "high": 3, "medium": 1, "low": 4, "unknown": 1},
  "warnings": []
}
```

Rutas de fichero y nombres de modulo son relativos al directorio escaneado
(se puede escanear un subdirectorio de un repo). Rutas con espacios o no
ASCII se tratan literalmente.

`bus-factor-report.sh` y `bus-factor-distribute.sh` solo leen el scan de ese
proyecto: `<proyecto>.json` o `<proyecto>-<timestamp>.json` en
`BF_OUTPUT_DIR` (el mas reciente). Nunca caen al scan de otro proyecto. Un
scan guardado con `scan.sh --output` y otro nombre no se encuentra: usa el
nombre por defecto o `--output "$BF_OUTPUT_DIR/<proyecto>.json"`.

### Codigos de salida

| Script | 0 | 1 | 2 |
|--------|---|---|---|
| `bus-factor-scan.py` | JSON emitido (tambien repo sin commits: `no_tracked_files`) | directorio inexistente o no es repo git | — |
| `bus-factor-scan.sh` | scan escrito | argumentos invalidos, `--format` distinto de `json`, o fallo del motor | — |
| `bus-factor-report.sh` / `-distribute.sh` | informe emitido | argumentos invalidos o no hay scan del proyecto | scan JSON ilegible |

## Configuracion

Solo variables de entorno (no hay fichero de configuracion por proyecto):

| Variable | Default | Descripcion |
|----------|---------|-------------|
| `BF_OWNERSHIP_THRESHOLD` | `0.50` | Score minimo para ser owner |
| `BF_RISK_CRITICAL` | `1` | 1 <= BF <= N es CRITICAL |
| `BF_RISK_HIGH` | `2` | BF <= N es HIGH |
| `BF_RISK_MEDIUM` | `3` | BF <= N es MEDIUM |
| `BF_MAX_HISTORY_DEPTH` | `0` | Commits maximos por fichero (0 = todo el historial) |
| `BF_MODULE_DEPTH` | `2` | Profundidad de agrupacion |
| `BF_EXCLUDE_PATTERNS` | `vendor/,node_modules/,*.lock` | Patrones a excluir |
| `BF_EXCLUDE_GENERATED_PATTERNS` | `*.pb.go,*_generated*,*auto_generated*,*.min.js,*.min.css` | Ficheros generados a excluir |
| `BF_EXCLUDE_BINARY` | `1` | Excluir ficheros marcados binarios en `.gitattributes` |
| `BF_OUTPUT_DIR` | `output/bus-factor/` | Directorio de salida |

## Limitaciones

1. Se miden lineas cambiadas (`git log --numstat`), no comprension real
2. Los commits de merge no suman cambios (su autor no se vuelve owner); un
   squash-merge atribuye todo el trabajo a quien lo firma
3. Sin `.mailmap`, la misma persona con dos emails cuenta como dos devs
4. Los owners se identifican por email: el JSON y los informes contienen
   datos personales. Se quedan en `output/` (gitignored); no pegarlos en
   issues, PRs ni canales publicos
5. No detecta conocimiento organizativo (ver org-stakeholder-mapper)
6. Human decides: el script solo genera findings, no actua

## Integraciones

- `context-dome` skill: genera CONTEXT_DOME.md con conocimiento tacito
- `human-code-map` skill: usa el plan de distribucion para onboarding
- `codebase-memory-mcp`: enriquece nodos File con bus_factor property
