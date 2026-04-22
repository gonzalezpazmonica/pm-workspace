# Domain: Workspace Integrity

> Audit document↔reality para detectar drift antes de que rompa CI.
> Spec group: SE-043, SE-046, SE-047, SE-048, SE-052, SE-057.

## Problema

El workspace pm-workspace mantiene contadores, manifests e índices en docs (`CLAUDE.md`, `docs/rules/INDEX.md`, `docs/rules/domain/agents-catalog.md`) que deben coincidir con la realidad del filesystem. Sin audit:

- CI falla con drift triple (CLAUDE.md ≠ ROADMAP ≠ filesystem)
- Agents catalog lista agentes eliminados o no registra nuevos
- Rules domain acumula orphans sin referencias cruzadas
- Agents oversized rompen límites de contexto Claude Code
- Baseline metrics pierden fiabilidad tras refactors masivos

## Solución

Suite de auditores read-only, cada uno con responsabilidad única:

1. **Counter drift** — CLAUDE.md vs filesystem (agents/skills/hooks)
2. **Manifest integrity** — INDEX.md apunta a ficheros que existen
3. **Catalog sync** — agents-catalog vs `.claude/agents/` real
4. **Orphan detection** — reglas sin referencias cruzadas
5. **Size audit** — agents > umbral líneas con plan de split
6. **Baseline metrics** — re-leveling tras cambios estructurales

Todos exit code estables (0 PASS / 1 DRIFT / 2 usage), todos JSON parseable, ninguno auto-fixer.

## Pattern establecido

```
audit:
  1. Leer fuente canónica (filesystem real)
  2. Leer fuente declarativa (docs / manifest)
  3. Diff
  4. Clasificar findings (INFO / WARN / ERROR)
  5. Emit JSON + human output
  6. Exit code consistente
```

## Integración con otros sistemas

| Consumer | Cuando usa auditor |
|---|---|
| `readiness-check.sh` | PASS gate antes de push (include drift-check) |
| `push-pr.sh` | Bloquea PR si drift-check falla |
| CI pipeline | Auditors como pre-merge gate en workflows |
| Drift auditor subagent | Orquesta multi-auditor en modo agente |
| SE-062 Era 184 cierre | Re-run todos los auditores para validar hygiene |

## Tradeoffs del patrón

**Pros**:
- Audit separable: cada script independiente, falla granular
- Auto-documentación: `--json` expone qué se chequea
- Zero side-effects: read-only, safe en cualquier branch
- Paralelizable: ejecución concurrente sin race conditions

**Contras**:
- N scripts separados requieren N invocaciones (mitigado por skill aggregator)
- Overlap conceptual entre catalog-sync y manifest-integrity
- Falsos positivos si el contador usa heurística ambigua (caso batch 24 — ver notas)
- No auto-fixer (SE-062 scope decisión explícita)

## Nota sobre contadores (batch 24 learning)

El contador de "skills" varía según método:
- `ls -d .claude/skills/*/` → 83 (solo directorios)
- `find .claude/skills -maxdepth 1` → incluye ficheros (más alto)
- Drift auditor externo puede contar distinto según implementación

**Canónico**: directorios que contienen `SKILL.md`. `claude-md-drift-check.sh` sigue esta definición. Si otro auditor reporta número distinto, confiar en `claude-md-drift-check.sh` (source of truth).

## Roadmap integrity futuros

- SE-062 Era 184: consolidación de hygiene al cierre de sprint largos
- Futuros auditors deben seguir este patrón: exit 0/1/2, JSON output, read-only
- Potencial: meta-auditor que combine findings y priorice por severidad

## No reemplaza

- Tests (`run-tests.sh`, BATS suites)
- Security audit (`security-audit.sh`)
- Dependency audit (SBOM, license scanning)
- Code quality (ast-quality-gate)

## Métrica de éxito

Adopción: `readiness-check.sh` incluye drift-check → 100% PRs validados.
Cobertura: 6 dimensiones de integridad cubiertas (counter, manifest, catalog, orphan, size, baseline).
Falsos positivos: <5% en muestreo trimestral (medido vía log).
