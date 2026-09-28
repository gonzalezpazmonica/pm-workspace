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
| Paridad de gates Python/TS (H07) | Cubierto localmente | `bun test` 26/26 (2026-09-28) |
| Replay/cancel/crash/mismatch seguros | Cubierto localmente | `tests/dual-cli/test_runtime.py` |
| Evidencia no falsificable por self-assertion | **Parcial** | H04 doctor `DEGRADED_SAFE` sin canaries de sesión real; H09 recibo A01c sin método de captura, hashes de salida ni atestación |
| Aislamiento de dominio (H10) | Cubierto localmente | `test_domain_packs.py` |
| Sustitución real documentada o limitaciones explícitas | **Parcial** | Limitaciones documentadas; sustitución real sin procedencia verificable |
| CI verde y revisión requerida | **No cumplido** | CI verde no ejecuta la suite completa; baseline global no demostrado; regresión contract-pin abierta; sin revisión humana registrada |

## Lagunas para el cierre (actualizadas)

1. **Nueva** — contract-pin `settings-hooks`: **en PR #1176.** Revisados los
   3 hooks (edit-ledger, config-snapshot, runs-cost): fail-open, sin red,
   snapshots en `~/.savia` fuera del repo. Re-pin v4, y `.deps-rules.yaml`
   selecciona `test-contract-pin.bats` al cambiar settings o catálogo.
2. H07 — **verificado 2026-09-28**: `bun test` (Bun 1.4.2) en
   `scripts/opencode-plugin/savia-gates`, **26/26**. Cubre nonzero, JSON
   malformado, `continue:false`, deny/ask (caso parametrizado, l. 280-282) y
   la imposibilidad de degradar a fire-and-forget.
3. H04 — **bloqueado por diseño, no por falta de ejecución.**
   `codex_profile.py:probe` fija `REAL_SESSION_CANARIES_MISSING` y
   `autonomy_l0_l2=False` sin ninguna vía de entrada: ningún canary cambia el
   veredicto del doctor. `scripts/codex-day1-canaries.sh` (SE-388) tampoco sirve
   como evidencia: se ejecuta sobre el repo real (L1 con `workspace-write`),
   la aserción de L2 es `*no*` y no emite recibo con procedencia. Cerrar H04
   exige implementar canaries en un workspace temporal con controles positivos
   y negativos, y conectar su recibo al doctor. No se ha ejecutado nada.
4. H09 — cotejo humano del recibo A01c con una captura operacional externa.
5. Baseline global en verde: la suite completa superó 900 s el 24/09 y no se
   ha repetido.
6. Tras 1–5: registrar `completion.merge_pr` y `completion.acceptance_evidence`
   en `planning-state.json` (con aprobación) → `NEEDS_HUMAN_REVIEW` → decisión humana.
