# SE-396 — revisión de cierre, delta (2026-09-28)

**Estado: `IMPLEMENTING`; no graduar.** Delta sobre
`SE-396-closure-review-20260924.md` (mapa H01–H12 y lagunas 1–4). Esta
revisión re-ejecuta la verificación en `main@156f6d5e` y contrasta con el DoD
de la spec. La decisión de cierre es humana.

## Re-verificación

| Comprobación | 2026-09-24 | 2026-09-28 |
|---|---|---|
| `unittest tests/dual-cli` (H01–H06, H08–H10) | 127/127 | 127/127 |
| `bats` planning-transition + roadmap-validate (H11) | 18/18 | 18/18 |
| `bats tests/bats/test-contract-pin.bats` | 20/20 | **19/20 — regresión** |
| `roadmap.sh validate` | OK | OK |
| `planning-transition.sh check SE-396` | NOT_READY | NOT_READY (sin `completion`) |
| CI de `main` | — | verde; no incluye `test-contract-pin.bats` |

**Regresión nueva (AC-6 de contract-pin).** `settings-hooks` cambió sin bump:
el pin coincide hasta `8312f3d0` (#1139) y falla desde `598a0117` (#1168,
SE-402), que añadió hooks a `.claude/settings.json` sin re-pinear;
`36652663` (#1169) añade más. La CI no ejecuta esta suite, por eso el merge
pasó en verde. Re-pinear (`contract-pin.sh pin settings-hooks`) es un bump de
contrato y requiere revisar los hooks añadidos; no se ha hecho en esta revisión.

## DoD de la spec frente a evidencia

| Criterio del DoD | Estado | Evidencia / laguna |
|---|---|---|
| Todos los hallazgos con regresión | Cubierto localmente | Tabla H01–H12 del 24/09; re-ejecutada arriba |
| Paridad de gates Python/TS (H07) | **No verificado** | Suite `bun:test`; sin Bun en el host. Sigue abierta |
| Replay/cancel/crash/mismatch seguros | Cubierto localmente | `tests/dual-cli/test_runtime.py` |
| Evidencia no falsificable por self-assertion | **Parcial** | H04 doctor `DEGRADED_SAFE` sin canaries de sesión real; H09 recibo A01c sin método de captura, hashes de salida ni atestación |
| Aislamiento de dominio (H10) | Cubierto localmente | `test_domain_packs.py` |
| Sustitución real documentada o limitaciones explícitas | **Parcial** | Limitaciones documentadas; sustitución real sin procedencia verificable |
| CI verde y revisión requerida | **No cumplido** | CI verde no ejecuta la suite completa; baseline global no demostrado; regresión contract-pin abierta; sin revisión humana registrada |

## Lagunas para el cierre (actualizadas)

1. **Nueva** — contract-pin `settings-hooks`: revisar los hooks de #1168/#1169
   y re-pinear con bump, o revertirlos; añadir la suite a CI para que no se repita.
2. H07 — ejecutar `http-gate.test.ts` con Bun (requiere instalar Bun).
3. H04 — canaries positivos y negativos de sesión Codex real; es un efecto
   externo con coste de proveedor y queda para la operadora.
4. H09 — cotejo humano del recibo A01c con una captura operacional externa.
5. Baseline global en verde: la suite completa superó 900 s el 24/09 y no se
   ha repetido.
6. Tras 1–5: registrar `completion.merge_pr` y `completion.acceptance_evidence`
   en `planning-state.json` (con aprobación) → `NEEDS_HUMAN_REVIEW` → decisión humana.
