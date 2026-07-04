# Hooks Integration Strategy for OpenCode

> **Estado actual (2026-05-27, SE-100)**: superado el modelo "wrappers manuales".
> OpenCode v1.14+ con symlinks compartidos ejecuta los hooks del `.claude/settings.json`
> de forma nativa cuando se invoca vía `claude` shell, y vía `plugins/` TS cuando
> se invoca como frontend OpenCode puro.

---

## Modelo actual

```
.opencode/hooks    → symlink a ../.claude/hooks    (101 hooks .sh — ver hooks-coverage-matrix.md)
.opencode/.claude  → symlink a ../.claude          (settings.json incluido)
```

Por tanto **no hay duplicación**: los 101 hooks son los mismos en ambos frontends.
La diferencia está en **quién los dispara**:

| Frontend | Mecanismo de disparo | Cobertura |
|---|---|---|
| Claude Code nativo | `.claude/settings.json` directo | 100% (PreToolUse, PostToolUse, Stop, ...) |
| OpenCode v1.14+ | Plugin TS en `.opencode/plugins/` mapea eventos a hooks | ver `docs/hooks-coverage-matrix.md` |
| OpenCode-Copilot Enterprise | **Sin hooks** (no hay surface de eventos) | Degradación a git pre-commit + CI |
| LocalAI emergency (SPEC-122) | `.claude/settings.json` directo (shell Claude con base URL local) | 100% |

---

## Capas de defensa (de mayor a menor cobertura)

### 1. Hooks runtime (PreToolUse / PostToolUse / Stop)

Cubren todo el ciclo de vida de una herramienta. Fuente: `.claude/settings.json`.

- **Seguridad bloqueante**: `block-credential-leak.sh`, `block-force-push.sh`, `block-infra-destructive.sh`, `validate-bash-global.sh`.
- **Calidad bloqueante**: `tdd-gate.sh`, `stop-quality-gate.sh`, `data-sovereignty-gate.sh`.
- **Calidad warning**: `plan-gate.sh`, `scope-guard.sh`, `agent-dispatch-validate.sh`, `cognitive-debt-*`.

Total: ver `docs/hooks-coverage-matrix.md` (scripts y registros auditados por SE-253).

Auditoría: `bash scripts/hooks-integrity-check.sh` (SE-094).

### 2. Git hooks (pre-commit / pre-push / commit-msg)

Defensa de **última línea** cuando los hooks runtime no se disparan (por ejemplo, OpenCode-Copilot Enterprise o ediciones manuales).

Instalación: `bash scripts/install-git-hooks.sh`.

Cubren: secretos staged, force-push a main, mensajes de commit malformados, escaneo Savia Shield, firma `.pr-plan-ok`.

### 3. CI (validación post-push)

`scripts/validate-ci-local.sh` ejecuta los gates equivalentes a CI en local.
GitHub Actions / Azure Pipelines ejecutan el mismo conjunto en remoto.

Cubre: lint, tests con cobertura, drift checks, confidentiality scan.

---

## Degradación bajo OpenCode-Copilot Enterprise

Sin hooks runtime ni slash commands, el flujo queda:

```
Edición → Git pre-commit (capa 2) → CI (capa 3) → Manual review
```

La capa 1 (runtime) se pierde. Compensación:

- `scripts/savia-env.sh` detecta el frontend y emite WARNING si la capa 1 está ausente.
- Hooks reescritos bajo SPEC-127 Slice 2 usan `SAVIA_WORKSPACE_DIR` y degradan a no-op silencioso si `savia_has_hooks` retorna falso, dejando la responsabilidad a capas 2/3.

---

## Mantenimiento

1. **Añadir un hook nuevo**: crear `.sh` en `.claude/hooks/`, registrar en `.claude/settings.json`, ejecutar `bash scripts/hooks-integrity-check.sh` para verificar detección bidireccional.
2. **Detectar drift**: `bash scripts/hooks-integrity-check.sh` lista phantom (registrados sin fichero) y orphan (fichero sin registro).
3. **Counters**: `bash scripts/claude-md-drift-check.sh` valida `hooks=N (Mregs)` en CLAUDE.md.

---

## Histórico

- **2025-03-10** (Fase 1-2): wrappers manuales en `scripts/opencode-hooks/wrappers/`. Modelo: usuario invoca wrapper antes de tool nativo. Reemplazado en SE-100.
- **2026-04-09**: symlinks `.opencode/{hooks,commands,skills}` → `.claude/*` unifican fuentes. Hooks runtime disponibles cross-frontend.
- **2026-05-27 (SE-094)**: detector `hooks-integrity-check.sh` con soporte symlink y búsqueda en `scripts/`. Registrados 4 hooks huérfanos (android-adb, cognitive-debt-*, project-isolation-gate).
- **2026-05-27 (SE-100)**: este documento reescrito reflejando el modelo unificado.

---

## Referencias

- `../CLAUDE.md` § Hooks · Memoria
- `docs/rules/domain/autonomous-safety.md`
- `docs/rules/domain/provider-agnostic-env.md`
- `scripts/hooks-integrity-check.sh`
- `scripts/claude-md-drift-check.sh`

---

## Cobertura OpenCode real (SE-253)

La cifra real de guards TS activos en `.opencode/plugins/savia-foundation.ts` frente a los
hooks registrados en `.claude/settings.json` está auditada y versionada en:

**[docs/hooks-coverage-matrix.md](../docs/hooks-coverage-matrix.md)**

Resumen a 2026-07-03 (SE-253 Slice 2):

| Metrica | Valor |
|---|---|
| Registraciones totales en settings.json | 103 |
| Guards TS activos en savia-foundation.ts | 17 (16.5%) |
| Mitigados via git hook | 4 |
| Mitigados via CI | 5 |
| Sin cobertura (degradacion documentada) | 77 |
| Bloqueantes sin cobertura ni mitigacion | 0 |

La degradacion en OpenCode puro (vs Claude Code nativo) es **conocida y documentada** por evento.
Los 21 hooks bloqueantes sin TS guard tienen degradacion documentada en la matriz.
Eventos no disponibles en OpenCode (Stop, SubagentStop, SessionStart, etc.): 19 eventos —
estos hooks solo ejecutan en Claude Code nativo y en LocalAI emergency mode (SPEC-122).

Para regenerar: `bash scripts/hooks-coverage-matrix.sh`
Para verificar drift: `bash scripts/hooks-coverage-matrix.sh --check`
