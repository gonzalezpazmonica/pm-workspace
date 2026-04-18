# Bounded Concurrency — doctrina pm-workspace

> **Regla**: cualquier codigo que spawnee procesos/goroutines/threads en paralelo DEBE tener un limite explicito en el codigo del llamante. La ausencia de limite no es "default razonable", es bug latente.

## Origen de la regla

- **Bluesky AppView outage 2026-04-14** (8 horas, ~50% de usuarios afectados). Root cause: linea `group.SetLimit(50)` comentada en un endpoint → 15-20k goroutines simultaneas por request → agotamiento TCP `TIME_WAIT` → death spiral. Post-mortem: https://pckt.blog/b/jcalabro/april-2026-outage-post-mortem-219ebg2
- **pm-workspace fork bomb 2026-04-18**. Root cause: heredoc `python3 <<PY` (sin quoted) + backticks en el cuerpo python → bash los expandio como command substitution → 15.245 procesos bash fork-bombed la maquina. Mismo patron: "el limite estaba implicito, no explicito".

## Principio

Si tu script/hook produce N procesos en paralelo:

- **N FIJO** (ej. 3 checks predefinidos) → safe; documenta el N en un comentario.
- **N ACOTADO por parametro** (ej. `PARALLEL=8`) → safe si el parametro es hardcoded o validado al leer.
- **N DERIVADO de input externo** (ej. longitud de una lista recibida) → **peligroso**. Necesita semaphore explicito en el codigo del llamante, NO confianza en que el productor respetara el contrato.

## Patron canonico (bash)

```bash
MAX_PARALLEL=5
for item in $items; do
  # Block until a slot is free
  while [ "$(jobs -rp | wc -l)" -ge "$MAX_PARALLEL" ]; do
    wait -n 2>/dev/null || break
  done
  process_item "$item" &
done
wait 2>/dev/null || true   # drain lo pendiente antes de salir
```

Claves:
- `jobs -rp` cuenta procesos en background del shell actual.
- `wait -n` bloquea hasta que cualquiera termine (bash 4.3+).
- `wait` final sin args drena lo pendiente antes de salir — critico en hooks para no dejar zombies.

## Alternativas por herramienta

| Herramienta | Patron bounded | Peligro si omites |
|---|---|---|
| `xargs` | `xargs -P N` | `-P 0` = ilimitado |
| `parallel` | `parallel -j N` | default: 1 CPU → ok, pero `-j 0` = ilimitado |
| `find ... -exec` | `find ... -exec cmd {} +` (batch) o `{} \;` (1 a 1) | ambos safe — no spawnea en paralelo |
| `make` | `make -j N` | `make -j` sin N = ilimitado |
| `while read ... & done` | **requiere semaphore manual** | unbounded si la lista lo es |

## Auditoria pm-workspace 2026-04-18

Escaneado `.claude/hooks/*.sh` y `scripts/*.sh` buscando patrones `&$` en loops:

**Safe (N fijo o semaphore explicito)**:
- `scripts/fork-agents.sh` — semaphore `PARALLEL` con batches.
- `scripts/wave-executor.sh` — itera grafo bounded, `wait` entre waves.
- `scripts/validate-ci-local.sh` — 7 checks predefinidos con `wait`.
- `scripts/verification-middleware.sh` — 3 checks predefinidos con `wait`.
- `scripts/savia-shield-setup.sh`, `scripts/emergency-plan.sh` — daemon starters (1 proceso).

**Endurecido en esta auditoria**:
- `.claude/hooks/memory-prime-hook.sh` — bounded a `MAX_PARALLEL=5` explicito + drain final con `wait`. Antes: bounded implicitamente por `--top 3` upstream. Defense-in-depth.

**Sin findings criticos adicionales** — la arquitectura actual de hooks/scripts no tiene puntos con fan-out unbounded derivado de input externo.

## Checklist para nuevos hooks/scripts paralelos

- [ ] ¿Hay `&` al final de alguna linea? → identifica el llamante.
- [ ] ¿Ese llamante esta dentro de un loop cuyo N depende de input externo? → necesita semaphore.
- [ ] ¿Hay un `wait` final que drene procesos antes de `exit 0`? → si no, zombies.
- [ ] ¿El limite (`MAX_PARALLEL`) esta hardcoded o validado contra un upper bound? → si no, falla-por-diseno.
- [ ] ¿Hay logging dentro del loop? → evita "death spiral" (millones de logs/segundo — leccion Bluesky).

## Referencias

- `docs/rules/domain/autonomous-safety.md` (Rule #24: limites operacionales)
- `tests/test-query-lib.bats` ("index script heredoc is quoted" — regresion fork-bomb)
- `.claude/external-memory/auto/feedback_bounded_concurrency.md` (memoria persistida)
- `.claude/external-memory/auto/feedback_heredoc_quoted.md` (memoria del fork-bomb 2026-04-18)
- Post-mortem Bluesky: https://pckt.blog/b/jcalabro/april-2026-outage-post-mortem-219ebg2
