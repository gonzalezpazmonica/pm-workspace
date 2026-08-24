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
- [ ] Test manual pendiente (requiere reiniciar la sesión activa): en rama main, `git commit` → bloqueado por hook bash. En esta misma sesión ya no se recarga la config.
- [ ] Parity audit SE-077 pendiente (script dedicado), contra manifest 20:59Z.

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