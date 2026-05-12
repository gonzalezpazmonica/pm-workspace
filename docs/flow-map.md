# Flow Map — Índice canónico de flujos operativos

> Fuente única de verdad sobre qué comando/skill/script gestiona cada acción
> operativa. Antes de improvisar tool-calls, **consultar esta tabla**.
> Ver `docs/rules/domain/check-flows-before-improvising.md`.

## Cómo se lee

| Acción | Canónico | Lo que hace internamente | NO hacer |
|---|---|---|---|

## Git · Commits · PRs

| Acción | Canónico | Lo que hace internamente | NO hacer |
|---|---|---|---|
| Crear commit con cambios staged | `commit-guardian` (agente, auto-trigger) | Verifica reglas workspace, security-guardian, confidentiality-scan, PII | `git commit` directo saltando hooks |
| Pre-flight antes de push/PR | `/pr-plan` → `scripts/pr-plan.sh` | 15 gates (G0-G14): firma, PII, force-push, conventional-commits, gates dinámicos, push opcional, PR creation | Improvisar `git push` o `gh pr create` |
| Push tras gates | `scripts/pr-plan.sh` (dentro) o `scripts/push-pr.sh` | Verifica `.pr-plan-ok`, push, crea PR Draft | `git push` directo (regla #25) |
| Firmar audit de confidencialidad | `scripts/confidentiality-sign.sh sign` | Calcula diff_hash, HMAC, escribe `.confidentiality-signature` | Editar `.confidentiality-signature` a mano |
| Verificar audit | `scripts/confidentiality-sign.sh verify` | Recalcula y compara | Suponer que está firmado |
| Escanear PII pre-commit | `scripts/confidentiality-scan.sh` | Allowlist/blocklist + regex | grep ad-hoc |
| Force-push | **PROHIBIDO** (plugin `block-force-push.ts`) | — | Nunca. Si commit es incorrecto: commit lineal de corrección |
| Validar CI local | `scripts/validate-ci-local.sh` | Reproduce workflow CI en local | Push y esperar a ver qué falla |

## Sprints · Reporting

| Acción | Canónico |
|---|---|
| Estado sprint actual | `/sprint-status` |
| Planning automático | `/sprint-plan`, `/sprint-autoplan` |
| Forecast | `/sprint-forecast` |
| Retro | `/sprint-retro` |
| Review | `/sprint-review` |
| Release notes | `/sprint-release-notes` |
| Informe semanal | `/weekly-report` |
| Auditoría incidencias | `/incidencias-audit` |

## SDD (Spec-Driven Development)

| Acción | Canónico |
|---|---|
| Generar spec desde Task | `/spec-generate` |
| Slice planning | `/spec-slice` |
| Implementar slice | `/spec-implement` |
| Review spec | `/spec-review` |
| Verify implementation | `/spec-verify`, `/spec-verify-ui` |
| Status | `/spec-status` |
| Skill orquestadora | `spec-driven-development` |

## Memoria

| Acción | Canónico |
|---|---|
| Guardar entrada | `scripts/memory-store.sh save --type T --title T [...]` o `/memory-save` |
| Buscar | `scripts/memory-store.sh search "query"` o `/memory-search` |
| Stats | `scripts/memory-store.sh stats` o `/memory-stats` |
| Rebuild index | `scripts/memory-store.sh rebuild-index` |
| Consolidar | `/memory-consolidate` |
| Comprimir | `/memory-compress` |
| Sync entre máquinas | `/memory-sync` |

## Perfil de usuario

| Acción | Canónico |
|---|---|
| Setup nuevo perfil | `/profile-setup` |
| Editar perfil activo | `/profile-edit` |
| Mostrar perfil | `/profile-show` |
| Cambiar usuario activo | `/profile-switch` |

## Project & Meetings

| Acción | Canónico |
|---|---|
| Actualización integral proyecto | `/project-update` (skill: `project-update`) |
| Extraer transcripción Teams | skill `meeting-transcript-extract` |
| Agenda reunión | `/meeting-agenda` |
| Resumen reunión | `/meeting-summarize` |

## Confidencialidad · Soberanía

| Acción | Canónico |
|---|---|
| Activar/desactivar Shield | `/savia-shield enable|disable|status` |
| Setup Shield (deps, modelos, daemons) | `scripts/savia-shield-setup.sh` |
| Pre-commit sovereignty scan | `scripts/pre-commit-sovereignty.sh` |
| Switch a LocalAI | `/emergency-mode` (skill: `emergency-mode`) |

## Modos autónomos (Rule #8 + autonomous-safety)

| Acción | Canónico | Restricción |
|---|---|---|
| Sprint nocturno | skill `overnight-sprint` | PR Draft + AUTONOMOUS_REVIEWER obligatorio |
| Loop mejora código | skill `code-improvement-loop` | Idem |
| Investigación técnica | skill `tech-research-agent` | Notifica humano, no aplica cambios |

## Cómo añadir un flujo nuevo a este mapa

1. Implementar el flujo como comando (`.opencode/commands/`) o script (`scripts/`).
2. Añadir fila en la tabla correspondiente.
3. Si es transversal, añadir referencia desde la regla que lo regule.
4. Si reemplaza un flujo previo, marcar el antiguo como **DEPRECATED** aquí.

## Mantenimiento

Este fichero se actualiza:

- Cuando se añade/renombra/borra un comando crítico.
- Cuando una sesión detecta que un flujo se ha improvisado por no estar
  indexado (auto-corrección de `check-flows-before-improvising.md`).
- En cada release que toque comandos operativos.
