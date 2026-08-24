---
title: "Causa raíz: savia-gates no carga en OpenCode (snap) — 116 hooks bash inactivos"
date: 2026-08-24
severity: HIGH
category: infrastructure
related: docs/incidents/2026-08-24-commits-main-guard.md
status: open
---

# Causa raíz: savia-gates no carga — 116 entradas hook inactivas en OpenCode

## Resumen

El plugin `savia-gates` — que traduce los hooks bash de `.claude/settings.json`
al runtime de OpenCode (SE-077) — **nunca se ha cargado en la instalación en uso**.
Como resultado, **ninguno de los 116 comandos hook del workspace se ejecuta** en
esta sesión de OpenCode, incluido `block-commit-to-main.sh` cuyo fallo motivó
este análisis (ver `2026-08-24-commits-main-guard.md`).

## Datos de evidencia

| Dato | Valor | Fuente |
|---|---|---|
| Binario en uso | `/snap/bin/opencode` → snap v1.18.16 | `/proc/<pid>/cmdline` |
| Config global leída por el snap | `~/.config/opencode/opencode.jsonc` | contenido: sin key `plugin` (vacío) |
| Config de proyecto | `./opencode.json` | `"plugin": ["opencode-sandbox"]` |
| Config donde vive `savia-gates` | `~/.savia/opencode/opencode.json` | `"plugin": ["savia-gates"]` — **ruta no canónica** |
| Manifest del plugin | `~/.savia/opencode/plugins/savia-gates/manifest.json` | **no existe** (nunca escrito) |
| Entradas hook en settings.json | 116 comandos en 17 eventos | `.claude/settings.json` |
| Hooks `.sh` del workspace referenciados | 111 | ídem |
| Plugin que SÍ carga | `opencode-sandbox` (npm 0.3.0) | cache opencode, sandboxing de comandos con @anthropic-ai/sandbox-runtime |

## Causa raíz (cadena completa)

1. `scripts/opencode-install.sh` (SE-077 S1) instala opencode en `~/.savia/opencode/`
   y escribe `~/.savia/opencode/opencode.json` declarando `plugin: ["savia-gates"]`,
   además de un symlink del plugin. Con **ese** binario (`~/.savia/opencode/bin/opencode`)
   el plugin cargaría SI la config se resolviera.

2. Sin embargo, la sesión real usa el **snap** (`/snap/bin/opencode`), no el binario
   de `~/.savia`. El snap NO lee `~/.savia/opencode/opencode.json`: OpenCode lee
   la config global desde `$XDG_CONFIG_HOME/opencode/opencode.json(c)`
   (= `~/.config/opencode/`, vacío de plugins) y la config de proyecto
   (= `./opencode.json`, que declara `opencode-sandbox`).

3. Consecuencia: `savia-gates` nunca está en el `plugin[]` de ninguna config que
   el snap lea → el plugin nunca se instancia → `writeManifest()` nunca corre →
   no existe `manifest.json` → **ningún hook de settings.json se ejecuta**.

## Implicaciones — impacto completo

La línea de defensa de hooks del workspace depende ENTERA de `savia-gates`.
Con él caído en OpenCode:

**PREVENCIÓN DE RIESGO (PreToolUse) — GRAVE:**
- `block-commit-to-main.sh` — commitear en main (el incidente de anoche)
- `block-force-push.sh`, `block-branch-switch-dirty.sh`, `block-infra-destructive.sh`
- `block-credential-leak.sh`, `block-pat-file-write.sh`
- `block-project-whitelist.sh`, `project-isolation-gate.sh`
- `data-sovereignty-gate.sh`, `vault-frontmatter-gate.sh`
- `pr-summary-gate.sh` (abre PR sin `.pr-summary.md`)
- `prompt-injection-guard.sh`, `context-sanitize-input.sh`
- `agent-git-discipline.sh`, `delegation-guard.sh`, `scope-guard.sh`

**GATES DE CALIDAD (pre/post) — debilitados:**
- `recursion-guard.sh`, `repeat-tool-guard.sh`, `speculative-pre-execute.sh`
- `tdd-gate.sh`, `plan-gate.sh`, `compliance-gate.sh`, `contract-test-guard.sh`
- `sycophancy-strip.sh` (anti-adulación), `responsibility-judge.sh`
- `memory-verified-gate.sh`, `memory-write-sanitize.sh`

**TELEMETRÍA / MEMORIA (Stop/PostToolUse) — todos mudos:**
- `memory-auto-capture.sh`, `session-end-memory.sh`, `stop-memory-extract.sh`
- `cognitive-debt-telemetry.sh`, `agent-trace-log.sh`, `competence-tracker.sh`
- `agents-md-auto-regenerate.sh`, `token-tracker-middleware.sh`

El guard **TS** `block-commit-to-main.ts` añadido ayer a `savia-foundation.ts`
(plugin TS del proyecto que SÍ carga por ser `**/*.ts` en `.opencode/plugins/`)
es la ÚNICA barrera actualmente activa contra commit en main. El resto de la
capa bash está muerta.

## Fix necesario

Dos opciones, ordenadas por robustez (criterio CRIT-001: no enviar datos fuera):

**OPCIÓN A (recomendada) — registrar savia-gates en la config global real.**
Editar `~/.config/opencode/opencode.jsonc` (la que lee el snap) para declarar
el plugin por ruta absoluta:

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "plugin": [
    "opencode-sandbox",
    "/home/monica/.savia/opencode/plugins/savia-gates"
  ]
}
```

Al instanciarse, `savia-gates` escribe su manifest (SE-077 parity audit) y
los 116 hooks de settings.json vuelven a ejecutarse. Verificación:
reiniciar opencode y comprobar que existe
`~/.savia/opencode/plugins/savia-gates/manifest.json`.

**OPCIÓN B — añadir savia-gates al plugin[] del config del proyecto.**
Añadir la ruta a `~/savia/opencode.json`. Menos robusto: exige editar un
fichero versionado y hace dependiente al proyecto de un path del usuario.

**Complemento — no depender de un solo cargador.**
La capa TS (`.opencode/plugins/*.ts`) se carga SIEMPRE porque opencode la
descubre por convención de directorio. Migrar los guards críticos (commit-main,
force-push, credential-leak, data-sovereignty) a guards TS en
`.opencode/plugins/guards/`, dejando los hooks bash como segunda capa.

## Fix aplicado y verificado (2026-08-24 22:59Z)

- [x] `~/.config/opencode/opencode.jsonc` declara `plugin: ["opencode-sandbox", "/home/monica/.savia/opencode/plugins/savia-gates"]` (config global que el snap SÍ lee).
- [x] Dependencias instaladas (npm, 27 paquetes) en `~/.savia/opencode/plugins/savia-gates/node_modules` — el snap no resolve import de `@opencode-ai/plugin` sin ellas.
- [x] Tras run headless del snap, existe `manifest.json` con **108 bindings / 105 scripts** (generado 2026-08-24T20:59:10Z).
- [x] **Verificación de carga en el proceso activo (2026-08-24T21:03:17Z):** el audit log `~/.savia/audit/savia-gates.jsonl` registra `plugin-loaded` desde pid **2822565** (= proceso opencode del snap en vivo, padre de esta sesión) con `events: 17`, y `manifest.json` se regeneró en ese mismo instante. La config global corregida SÍ se resuelve.
- [ ] **Hallazgo posterior — el plugin carga pero su pipeline PreToolUse es FUNCIONALMENTE INERTE.** Sonda en vivo: comando que dispara la regla SPEC-SE-036 de `block-credential-leak.sh` (bloquea `exit 2` probado manualmente con el mismo JSON por stdin) **NO bloquea** en runtime. Instrumentación temporal (`before-debug`): `tool.execute.before` se invoca, `output.args` contiene `["command"]`, `$` existe, `blocked=false`. Mismo resultado en run headless. Causa probable en `lib/shell-bridge.ts`: (1) `proc.text({ stdin: payload })` no entrega el payload por stdin (el hook lee stdin vacío → `COMMAND=""` → `exit 0`), y (2) `.text()` devuelve un string y `(r as any).exitCode` es siempre `undefined` → `exit=0` aunque un hook devuelva 2. Ambas enmascaran cualquier bloqueo. **Consecuencia: la capa bash de savia-gates es auditoría muda en OpenCode; solo los guards TS de `savia-foundation.ts` bloquean de verdad.**
- [x] **Fix del bridge APLICADO y VERIFICADO (2026-08-24T21:46Z).** Causa raíz completa del hot path encontrada y corregida en `lib/shell-bridge.ts` + `index.ts`:
  1. **`.timeout()` no existe** en el `$` del runtime embebido → TODA la cadena tiraba `TypeError` → ningún hook llegaba a ejecutarse. Fix: feature-detect de `.timeout()`/`.nothrow()` + timeout manual vía `Promise.race`.
  2. **stdin muerto**: `.text({ stdin })` ignora el payload → los hooks leían stdin vacío → `exit 0`. Fix: payload entregado por redirección `<` a fichero temporal en `$tmpdir` (CRIT-001: todo local, ephemeral, cleanup garantizado).
  3. **exit code nunca capturado**: `.text()` devuelve string. Fix: `await` la promesa a `BunShellOutput { stdout, stderr, exitCode }` real.
  4. **Hooks `async` (35)**: ahora fire-and-forget (semántica Claude Code), sin espera ni interpretación de su stdout.
  5. **`chat.message` inyectaba `{type:"text"}` sin `id/sessionID/messageID`** → crash `SchemaError` al guardar part. Fix: part schema-válido (`prt_*`, `msg_` real vía `output.message.id`; si no hay id real, no inyecta).
- [x] **Evidencia de bloqueo real (2026-08-24T21:46:25Z, pid 2843335):** sonda `echo "probe_auth=ZZZ…(44x)"` vía `opencode run` → tool bash **BLOQUEADA** con `Error: savia-gates: BLOQUEADO [SPEC-SE-036]: PAT-shaped string detectada…` y audit `tool-blocked` registrado. Sonda benigna de control pasó sin crash. BATS estructurales 28/28.
- [ ] **Pendiente:** reiniciar la sesión OpenCode activa (inicia con el plugin corregido) y re-test del gate `git commit` en main en vivo+TUI; parity audit SE-077; gap de 6 eventos sin binding nativo.

### Gap descubierto: 6 de 17 eventos sin binding nativo

El `HANDLER` del plugin mapea solo 11 de los 17 eventos de settings.json.
Los eventos **sin bindings** quedan fuera del manifest (gap candidates de SE-077):

| Evento sin binding | Hooks afectados (muestra) |
|---|---|
| `PostToolUseFailure` | post-tool-failure-log.sh |
| `CwdChanged` | cwd-changed-hook.sh |
| `FileChanged` | file-changed-staleness.sh |
| `PostCompact` | post-compaction.sh |
| `InstructionsLoaded` | instructions-tracker.sh (2) |
| `ConfigChange` | config-reload.sh (2) |

Impacto: la capa bash de esos 6 eventos NO corre en OpenCode aunque savia-gates
cargue. No son críticos de seguridad (mayormente telemetría/estado), pero deben
traducirse a bindings de OpenCode v1.18 (stale-table) o migrarse a guards TS.

## Gap CERRADO + gate verificado (2026-08-25 00:30Z)

- [x] **Gap 0/113**: los 6 eventos sin binding ahora tienen binding nativo:
  | Evento | Binding OpenCode v1.18 |
  |---|---|
  | `FileChanged` | `event:file.edited` + `event:file.watcher.updated` |
  | `PostCompact` | `event:session.compacted` + `experimental.compaction.autocontinue` |
  | `ConfigChange` | `config` |
  | `CwdChanged` | `shell.env` (dedup por cambio de cwd) |
  | `InstructionsLoaded` | `event:session.created` (con payload sintético) |
  | `PostToolUseFailure` | `NOT_EXPOSED` justificado (sin hook point nativo de tool-failure) |
  `opencode-parity-audit.sh` → `matched 112, justified 1, gap 0`. Baseline `.ci-baseline/opencode-parity-gap.count = 0`, `--check` PASS.
- [x] **3 fix adicionales del bridge descubiertos al re-testear el gate commit:**
  1. **Matcher `Bash(git commit*)` / `Bash:gh pr create*` no matcheaba**: OpenCode pasa el tool lowercased (`bash`) y el comando dentro de `tool_input.command`. Fix: `matcherApplies` reconstruye los candidatos compuestos `bash(<command>)`, `bash:<command>`, `bash <command>`.
  2. **`bash ${h.command}` rompía comando con comillas internas**: Bun escapeaba la interpolación → `EOF inesperado` en los 17 hooks con prefijo `bash "..."` y los 6 con args. Fix: `bash -c ${{raw: h.command}}` (ShellExpression `{raw}`) + `.cwd(projectRoot)` (los hooks ejecutaban `git branch` sobre el repo del proceso, no el del proyecto).
  3. **Contrato SE-337 (exit 0 + `{decision:"block"}` en stdout) no bloqueaba**: el bridge solo entendía exit 2. Fix en `runHooksForEvent`: parsea stdout JSON y bloquea si `parsed.decision === "block"` (usa `reason` como mensaje; audit `hook-json-block`).
- [x] **Re-test del gate `git commit` en main en vivo (headless, repo temporal en main):** hook `block-commit-to-main.sh` emite `{decision:"block"}` → `Error: savia-gates: Commit en rama humana (main) bloqueado…` y la tool NO se ejecuta. Evidencia audit `tool-blocked`. BATS estructurales 40/40 + `test-se337-commit-guard.bats` 7/7 verdes.