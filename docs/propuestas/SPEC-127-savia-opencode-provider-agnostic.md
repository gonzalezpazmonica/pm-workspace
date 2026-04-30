---
spec_id: SPEC-127
title: Savia ↔ OpenCode provider-agnostic compatibility — inference-independent foundation
status: APPROVED
approved_by: operator (2026-04-30)
slice_1_status: IMPLEMENTED 2026-04-30
origin: Cada usuario de Savia decide su frontend (Claude Code, OpenCode v1.14, Codex, Cursor, otro) y su proveedor de inferencia (Anthropic API, hosted-OSS, LocalAI, Ollama, custom corporate endpoint, vendor-managed, ...). Savia debe operar de forma agnóstica al stack — no asumir un frontend, no asumir un proveedor, no asumir hooks-disponibles. Detect at runtime, ask the user when ambiguous, degrade gracefully.
severity: Crítica — Savia hoy asume Claude Code en silencio y rompe ~75% de su enforcement layer bajo cualquier otro stack
effort: ~80h (5 slices) — Slice 1 mínimo viable, Slices 2-5 incrementales
priority: P0 — desbloquea adopción de Savia bajo cualquier stack del usuario
related_specs:
  - SE-077 (OpenCode v1.14 replatform — IMPLEMENTED 2026-04-26, base genérica para frontends OpenCode-compatibles)
  - SE-055 (.opencode parity generator — superseded por este spec)
  - SE-078 (sovereignty-switch — complementary)
  - SPEC-122 (LocalAI emergency hardening — un caso concreto de provider alternativo)
  - SPEC-SE-001 (Layer Contract — IMPLEMENTED 2026-04-30, foundation arquitectónico)
related_rules:
  - .claude/rules/domain/autonomous-safety.md
  - .claude/rules/domain/zero-project-leakage.md
---

# SPEC-127: Savia ↔ OpenCode provider-agnostic compatibility

> **Principio rector**: cada usuario de Savia decide su stack — frontend +
> proveedor de inferencia + capacidades. El framework no asume vendor X,
> no asume vendor Y, no asume vendor Z. Detecta capacidades en runtime,
> pregunta al usuario sus preferencias en onboarding, degrada gracefully
> cuando un primitivo (hooks, subagent fan-out, slash commands) no está
> disponible. Cualquier referencia a un proveedor concreto en este
> documento es **ejemplo ilustrativo**, no normativo.

## Tesis (one paragraph)

Savia hoy asume Claude Code: 64 hooks hard-codean `CLAUDE_PROJECT_DIR`, 70 agentes declaran `model: claude-X`, 534 commands viven en `.claude/commands/` invocados por `/name`, 4 orchestrators dependen del Task tool. SE-077 (batch 2026-04-26) construyó el puente OpenCode v1.14 — buen primer paso, pero limitado a Claude como backend de inferencia. Cada usuario de Savia conecta OpenCode (o cualquier otro frontend OpenCode-compatible) a su proveedor: Anthropic API directa, hosted vendor-managed, LocalAI on-prem, Ollama local, OSS hosted (Mistral, DeepSeek), endpoint corporativo custom. Esos proveedores difieren en cuatro ejes ortogonales — **hook surface**, **subagent fan-out**, **slash command surface**, **token economy** — y Savia debe detectar cada eje en runtime y degradar gracefully cuando un primitivo no está disponible. **Esta spec no promete parity completo en ningún proveedor concreto** — declara explícitamente qué primitivos no están disponibles y cómo se reroutea (MCP server para slash, git pre-commit + CI para hooks, single-shot fallback para orchestrators). El usuario declara su stack en `~/.savia/preferences.yaml` (entrevista interactiva en `/savia-setup`); el framework respeta esa declaración + autodetect cuando hay señal de env var.

---

## El problema en una frase

Pasar de Claude Code a OpenCode con un proveedor distinto rompe ~75% de los enforcement layers de Savia silenciosamente — los tests siguen pasando porque corren contra el árbol de archivos, no contra el comportamiento real bajo el stack del usuario.

---

## Evidencia (del audit técnico 2026-04-30)

### Counts del workspace actual

| Categoría | Total | Asunción Claude Code | Sin hook surface | Sin Task tool | Sin slash commands |
|---|---:|---:|---:|---:|---:|
| Hooks (`.claude/hooks/*.sh`) | 64 | 46 (`CLAUDE_PROJECT_DIR`) | 64 silenciosamente rotos | 64 quietos | 64 quietos |
| Settings.json hook entries | 65 | 65 | 0 funcionan | 65 quietos | 65 quietos |
| Agents (`.claude/agents/*.md`) | 71 | 70 declaran `claude-X` | 71 quietos | 71 sin fan-out | 71 quietos |
| Skills (`SKILL.md`) | 90 | 0 (~95% portable) | 90 portables | 90 portables | 90 portables |
| Commands (`.claude/commands/*.md`) | 534 | 534 invocados con `/` | 534 quietos | 534 quietos | 534 sin discoverability |
| Tool_input parsing hooks | 26 | 26 | 26 broken | 26 quietos | 26 quietos |

**Lectura**: cada eje (`hook surface`, `Task tool`, `slash commands`) se evalúa **independientemente**. Un proveedor con hooks y sin Task rompe orchestrators pero conserva enforcement. Un proveedor sin hooks y con Task conserva orquestación pero pierde la safety layer. La spec aborda los cuatro ejes ortogonales, no una matriz fija de proveedores conocidos.

### Top 10 archivos por execution weight

1. `.claude/settings.json` (cada hook invocation)
2. `.claude/hooks/session-init.sh` (cada session)
3. `.claude/hooks/validate-bash-global.sh` (cada Bash call)
4. `.claude/hooks/block-credential-leak.sh` (cada Bash/Edit)
5. `.claude/hooks/tdd-gate.sh` (cada code edit)
6. `.claude/hooks/responsibility-judge.sh` (cada PreToolUse)
7. `.claude/hooks/block-gitignored-references.sh` (cada Edit/Write)
8. `.claude/hooks/agent-dispatch-validate.sh` (cada Task call)
9. `.claude/agents/dev-orchestrator.md` (entry point orquestación)
10. `CLAUDE.md` (5 `@import`s — cada turn)

Slice 2 portea estos 10 (cuando el stack del usuario lo permita) o reroutea (cuando no).

### Los 4 ejes de capability (provider-agnostic)

Cada proveedor se evalúa en **4 ejes ortogonales**. La spec define un detector runtime por eje:

| Eje | Pregunta | Detector | Si NO disponible — reroute |
|---|---|---|---|
| **Workspace path env var** | ¿Cómo se obtiene el path del workspace? | `savia_workspace_dir` (fallback chain) | — (siempre resuelve) |
| **Hook events surface** | ¿El frontend expone tool-call telemetry al cliente? | `savia_has_hooks` | git pre-commit (TIER-2) + CI (TIER-3) |
| **Subagent fan-out (Task tool)** | ¿Soporta delegación a subagents? | `savia_has_task_fan_out` | single-shot expanded prompt (Slice 4) |
| **Slash command surface** | ¿Soporta `/command-name` invocation? | `savia_has_slash_commands` | MCP server local (Slice 3) |

Estos ejes se establecen en `~/.savia/preferences.yaml` (preguntado al usuario en onboarding) o se autodetectan via env vars cuando hay señal clara.

### Fricciones operativas — ejemplos de stacks reales (ilustrativos, no exhaustivos)

Cada stack del usuario aporta su set de fricciones. Esto NO es la lista de proveedores soportados — es ilustración del problema multi-vendor:

- **Vendor-managed con cuota mensual**: tool attachments inflan request count → Slice 5 implementa quota guard configurable per-stack.
- **Vendor con context cap**: caps difieren por modelo (32K, 128K, 256K, 1M+). La capa adapter respeta el cap del stack del usuario.
- **OSS hosted (Mistral, DeepSeek, Qwen, ...)**: distintas APIs, distintos shapes. La capa de provider abstrae.
- **LocalAI / Ollama**: cero red externa, cero auth, cero cuota. Slice 5 detecta y skip quota tracker.
- **Endpoint corporativo custom**: auth bespoke (mTLS, OAuth corp, API key con header custom). Onboarding pregunta el shape.
- **Anthropic API directa**: similar a Claude Code pero sin frontend hooks. Slice 2 portea via OpenCode plugin TS.

Ningún stack se hardcodea en source. Las preferencias viven en `~/.savia/preferences.yaml` per-user.

---

## Solución: 5 slices de adaptación incremental

### Slice 1 (S, 8h) — Provider-agnostic foundation + onboarding

**Objetivo**: cada usuario puede arrancar Savia sobre cualquier frontend × proveedor sin que el framework asuma el stack equivocado. Mínimo viable: detector de env, registro de preferencias, schema user-extensible para alias de modelo.

Artefactos:
- `scripts/savia-env.sh` — single-source loader. Exporta `SAVIA_WORKSPACE_DIR` (fallback chain) + `SAVIA_PROVIDER` (detect chain) + capability probes (`savia_has_hooks`, `savia_has_slash_commands`, `savia_has_task_fan_out`). Source desde cualquier hook.
- `docs/rules/domain/provider-agnostic-env.md` — rule canonical. Define el contrato cross-frontend sin atar a vendor.
- `scripts/savia-preferences.sh` — gestor de `~/.savia/preferences.yaml`. Subcomandos: `init` (entrevista interactiva), `show`, `set <key> <value>`, `get <key>`, `reset`, `validate`. Source-of-truth de las preferencias del usuario.
- `.claude/commands/savia-setup.md` — comando que invoca el onboarding. Hace 8 preguntas neutrales (frontend, provider, modelos por tier, capabilities, budget, auth — todas con campo libre, sin lista cerrada de vendors).
- `docs/rules/domain/model-alias-schema.md` — schema YAML user-extensible (NO tabla cerrada). Cada usuario añade sus mappings en `preferences.yaml`. El doc documenta el schema + ≥3 ejemplos genéricos (default Anthropic API, LocalAI/Ollama-hosted, vendor-managed-hosted).
- BATS tests sobre los 5 artefactos.

Acceptance criteria Slice 1:
- AC-1.1: cada hook que use `CLAUDE_PROJECT_DIR` puede source `savia-env.sh` y obtener `SAVIA_WORKSPACE_DIR` con fallback funcional bajo cualquier shell. ✅ IMPLEMENTED.
- AC-1.2: `~/.savia/preferences.yaml` schema permite a cualquier usuario declarar su stack (frontend × provider × capabilities × budget × auth). El comando `/savia-setup` entrevista interactivamente y persiste. Re-ejecutable idempotentemente. ✅ IMPLEMENTED.
- AC-1.3: `model-alias-schema.md` documenta el schema YAML user-extensible con ≥3 ejemplos genéricos. Cero hardcoded vendor IDs en scripts — los mappings vienen de preferences.yaml. ✅ IMPLEMENTED.
- AC-1.4: framework respeta preferences.yaml cuando existe; autodetect cuando no existe; `unknown` provider permitido y NO bloqueante. ✅ IMPLEMENTED.

### Slice 2 (M, 16-20h) — Hook portability classifier + critical TS plugin

**Objetivo**: trasplantar los 10 hooks más críticos a un equivalente que funcione bajo el stack del usuario (cuando lo permita) o reroute (cuando no).

Artefactos:
- `.opencode/plugins/savia-critical-hooks.ts` — Plugin TS para stacks que exponen `tool.execute.before`/`tool.execute.after`. Activado solo si `savia_has_hooks` es true.
- Para stacks sin hook surface: mover lo que NO se puede portear a `.husky/` (git pre-commit). Caveat documentado: solo intercepta cambios commiteados.
- `scripts/hook-portability-classifier.sh` — clasifica cada hook en TIER independiente del stack:
  - **TIER-1 portable**: TS plugin equivalente directo
  - **TIER-2 git-pre-commit**: rerouteable vía .husky
  - **TIER-3 ci-only**: solo en CI (GitHub Actions / GitLab CI / Jenkins / etc.)
  - **TIER-4 lost**: no portable bajo el stack del usuario — declarar pérdida explícita
- BATS tests para classifier + plugin TS skeleton.

Acceptance criteria Slice 2:
- AC-2.1: los 10 hooks top execution-weight tienen plan de portabilidad explícito por stack-class.
- AC-2.2: ≥5 hooks top-10 portados a TIER-1 (TS plugin) con tests.
- AC-2.3: `prompt-injection-guard`, `block-credential-leak` cubiertos en TIER-1 o TIER-2 — son safety-critical, PV-02.
- AC-2.4: clasificación de los 64 hooks documentada en `output/hook-portability-classification.md`.

### Slice 3 (M, 12-16h) — Slash command MCP shim

**Objetivo**: si el stack del usuario no tiene slash command mechanism (`savia_has_slash_commands == false`), los 534 commands de Savia perderían descubribilidad. Reroute via MCP server local.

Artefactos:
- `scripts/savia-commands-mcp-server.ts` (Node/TS) — expone los 534 commands como MCP tools. Cada `.claude/commands/<name>.md` se traduce a un MCP tool.
- `docs/rules/domain/savia-commands-mcp.md` — registry contract.
- Configuración MCP genérica (instrucciones para cualquier MCP-supporting frontend).
- BATS tests sobre el server (subset de 10 commands canary).

Acceptance criteria Slice 3:
- AC-3.1: MCP server arranca y expone ≥50 commands.
- AC-3.2: 10 commands canary ejecutables vía MCP desde un frontend MCP-compatible.
- AC-3.3: Si la política MCP del usuario bloquea servers locales, doc de pivot a publicar el server en su registry corporativo o degradación documentada.

### Slice 4 (M, 8-12h) — Subagent fallback (single-shot mode)

**Objetivo**: si el stack del usuario no tiene Task tool / subagent fan-out, los orchestrators de Savia (`recommendation-tribunal-orchestrator`, `truth-tribunal-orchestrator`, `court-orchestrator`, `dev-orchestrator`) fallan silenciosamente sin fallback.

Artefactos:
- `docs/rules/domain/subagent-fallback-mode.md` — patrón "single-shot expanded prompt".
- Patch de 4 orchestrators críticos para detectar `savia_has_task_fan_out == false` y pivotar.
- Regression test: cada orchestrator produce el mismo veredicto-shape bajo Task (cuando disponible) y single-shot (cuando no) sobre 3 fixture inputs.

Acceptance criteria Slice 4:
- AC-4.1: 4 orchestrators críticos detectan capability y pivotan.
- AC-4.2: Single-shot mode preserva el JSON output schema del orchestrator (audit trail compatible).
- AC-4.3: BATS tests verifican equivalencia funcional sobre 3 inputs por orchestrator.

### Slice 5 (S, 6h) — Quota / budget guard

**Objetivo**: si el stack del usuario tiene cuota (request count, token count, dollar cap), Savia necesita visibilidad y guard rails antes de consumirla. Si el stack no tiene cuota (e.g. LocalAI), Slice 5 detecta y skip.

Artefactos:
- `scripts/savia-quota-tracker.sh` — wrapper genérico. Lee tipo de cuota y límite desde preferences.yaml. Cuenta consumo via heurísticas configurables.
- `.claude/hooks/savia-budget-guard.sh` — PreToolUse o equivalente que warns cuando consumo > 70%/85%/95% del budget.
- Integración con `cognitive-debt.sh summary`.
- Tests BATS sobre tracker.

Acceptance criteria Slice 5:
- AC-5.1: tracker detecta el tipo de cuota declarada en preferences.yaml y mide en consecuencia.
- AC-5.2: budget guard avisa (no bloquea) en thresholds 70%/85%/95%.
- AC-5.3: si no hay cuota declarada, tracker skip silenciosamente.

---

## Lo que esta spec NO hace (declaración explícita)

- **NO promete parity completo en ningún stack concreto.** Las 3 capacidades estructurales (hook events real-time, subagent fan-out, workspace slash commands) se reroutean — el reroute tiene costes funcionales documentados.
- **NO hardcodea ningún proveedor en source.** Todo nombre de vendor en este documento es ejemplo ilustrativo. Las preferencias viven en `~/.savia/preferences.yaml` per-user.
- **NO migra los 534 commands a TS plugins.** MCP server cubre el 90% de uso real.
- **NO sustituye Claude Code como frontend principal.** Si un usuario prefiere Claude Code, sigue funcionando 100% — toda la infraestructura nueva es opt-in y backward-compatible.
- **NO portea hooks que dependan de telemetry específica de un vendor.** Si no hay equivalente, el hook se declara TIER-4 lost.
- **NO modifica el modelo de Savia subyacente** — solo capa de adaptación.
- **NO genera context files vendor-específicos por defecto.** Si un usuario declara un frontend que requiere context file (e.g. AGENTS.md ya existe para frontends OpenCode-compatibles), el generador correspondiente corre. Otros provider-context generators son opt-in en Slice 2+.

---

## Restricciones inviolables

- **PV-01 Backward compat absoluto**: ningún cambio puede romper la operación actual de Savia bajo Claude Code.
- **PV-02 Safety layer crítica**: las 3 capas de seguridad (`block-credential-leak`, `prompt-injection-guard`, `block-gitignored-references`) deben tener cobertura equivalente bajo cualquier stack — TIER-1/2 obligatorio. Si no se puede, ese stack queda bloqueado para Slice 2 ramp.
- **PV-03 Zero data exfiltration**: los datos sensibles confidenciales (PII, credenciales, hardware specs) NO pueden exfiltrarse al provider del usuario sin opt-in explícito. La capa shield existente se extiende al endpoint declarado en preferences.yaml.
- **PV-04 Opt-in puro**: cualquier provider activo distinto al default (Claude Code) requiere `~/.savia/preferences.yaml` explícito. Sin preferences, Savia opera bajo Claude Code.
- **PV-05 Visibilidad de pérdidas**: cualquier hook TIER-4 (lost bajo el stack del usuario) requiere alerta documentada. La pérdida de seguridad debe ser visible, no silenciosa.
- **PV-06 No vendor lock-in**: cero referencias hard-coded a vendors específicos en source-controlled files. Schema YAML extensible es la única source-of-truth de mappings.

---

## Aprobación

Status APPROVED 2026-04-30 (operator review). Slice 1 IMPLEMENTED 2026-04-30. Slices 2-5 incrementales — cada slice arranca cuando el operador (o cualquier usuario futuro) confirma decisiones específicas vía `/savia-setup` o equivalente.

## Decisiones del usuario (capturadas en preferences.yaml, no en source)

A diferencia de specs anteriores, no hay "decisiones operador pendientes" hardcodeadas en este documento. Cada usuario declara las suyas en `~/.savia/preferences.yaml` cuando ejecuta `/savia-setup`. La spec define el schema + el detector + los reroutes; las elecciones concretas (qué stack, qué modelos, qué auth, qué budget) son privadas del usuario y nunca se commitean al repo.
