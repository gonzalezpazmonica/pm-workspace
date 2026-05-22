# RESUME — Sesión 2026-05-23

## Rama activa
`feat/incorporate-savia-evolution`

## Objetivo
Incorporar evoluciones de saviabios a savia, sanitizar, testear, documentar y preparar PR.

## Estado al cerrar

### Completado en esta sesión
- Auditoría de confidencialidad completa — 0 ocurrencias de repsol/trazabios/vass/N4-VASS/N4c-MONICA en ficheros públicos
- `remote_host.py` SyntaxError corregido (docstring partido líneas 4-15)
- `test_survival.py` — TestPhaseRespiracion y TestPhaseDespertar reescritos para arquitectura local (run_llm_fn, sin SSH)
- `test_savia_paths.py` — expectativa -monica → -pm corregida
- `test_vault_validate.py` — test N1-in-vault alineado con SPEC-128
- pytest: 190/190 passed
- CI local: 7/7 passed
- Commit aa61f45a — sanitize(pii)
- Fix ProviderModelNotFoundError: hook config en savia-foundation.ts mapea tiers heavy/mid/fast a modelos Copilot
- Commit 49f5a33e — fix(plugin): model tier mapping
- PENDIENTE: reiniciar opencode para que el plugin cargue el hook config

### Pendiente — docs (auditados, no corregidos)

| Prioridad | Fichero | Issue |
|---|---|---|
| BLOQUEANTE | docs/savia-claw-bridge.md | Describe arquitectura SSH como activa. Reescribir con arquitectura HTTPS local. |
| BLOQUEANTE | zeroclaw/host/remote_host.py:101 | wake_claude() sin aviso DEPRECATED explícito en la función |
| RECOMENDADO | docs/ARCHITECTURE.md | Conteos desactualizados (454/67/33/17 → real 545/97/70/69) |
| RECOMENDADO | docs/SETUP.md:88,92,111 | Binario claude → opencode |
| RECOMENDADO | docs/savia-shield.*.md (7 traducciones) | Capa 7 sovereignty-mask marcada activa, debe ser DEPRECATED |
| RECOMENDADO | docs/ROADMAP.md | SPEC-SE-089 Slice 3 marcar completado [x] |
| COSMÉTICO | scripts/vass_persistent.py, scripts/vass_ref.py | Mover a scripts/_legacy-daemons/ |

### Siguiente paso inmediato
1. Reiniciar opencode (cargar plugin con model tier mapping)
2. Verificar fix ProviderModelNotFoundError con subagente drift-auditor
3. Reescribir docs/savia-claw-bridge.md (SSH → HTTPS local)
4. Corregir issues RECOMENDADOS
5. Lanzar /pr-plan

## Contexto técnico crítico

### Arquitectura ZeroClaw post-migración (Era 193, 2026-05-02)
- survival_phases.py usa run_llm_fn callback local — NO SSH
- remote_host.py está DEPRECATED (líneas 1-3 del módulo)
- wake_claude() en remote_host.py llama claude -p via SSH — código muerto, necesita aviso DEPRECATED
- Bridge verificado por HTTPS loopback (curl -sk https://localhost:8922/health), no SSH

### Niveles de confidencialidad canónicos
- N4-SUPPLIER (antes N4-VASS)
- N4c-PM-ONLY (antes N4c-MONICA-ONLY)
- N4b-PM (sin cambio)

### Tests excluidos permanentemente
- tests/scripts/test_extract-teams-transcripts.py — dep websocket no instalada

### Plugin model tier mapping
Fichero: .opencode/plugins/savia-foundation.ts
Hook config mapea: heavy→github-copilot/claude-opus-4.7, mid→github-copilot/claude-sonnet-4.6, fast→github-copilot/claude-haiku-4.5
Requiere reinicio de opencode para activarse.
