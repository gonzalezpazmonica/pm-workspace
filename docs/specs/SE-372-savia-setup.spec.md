# SE-372 — Savia Setup: inicializador interactivo de configuración completa

**Status:** APPROVED (2026-09-03, orden operadora: instalador configura Savia con todas las funciones actuales, interactivo: vaults local/remoto, federación, MCPs on/off)
**Fecha:** 2026-09-03
**Área:** Bootstrap / Configuración / Instalación
**Criterio humano aplicable:** CRIT-001 (todo local; remoto solo infraestructura propia; N3+ jamás a proveedor cloud)

---

## 1. Motivación — el problema

`pm-workspace` (Savia) pasó de ~75 agentes/104 skills a **88 agentes, 133 skills, 119 hooks, 5 domes de conocimiento (vaults), 3 servidores MCP locales** y config multi-proveedor (model-registry, `~/.savia/preferences.yaml`). Pero el "instalador" no ha crecido con ella:

- `.opencode/install.sh` (el de una línea vía curl) hace 8 pasos **no interactivos** (OS, git/curl, clone, npm, symlinks, smoke test) y solo **informa** de CodeGraph. No configura nada de lo actual: no pregunta por vaults, ni MCPs, ni proveedor/modelos, ni identidad, ni backend, ni autonomía.
- La configuración real se hace hoy a mano, pieza a pieza (`mcp-server-config`, `chat-setup`, editar `opencode.json`, `~/.savia/preferences.yaml`, `.claude/rules/pm-config.local.md`), sin un flujo único que garantice coherencia.
- Un usuario nuevo no tiene una guía ejecutable que le pregunte lo esencial y le genere una instalación **coherente y validada**.

**Objetivo**: un inicializador interactivo (`savia setup`) que configure Savia con todas sus funciones actuales, preguntando en orden lógico y con defaults seguros (CRIT-001), y que sea reproducible (headless con fichero de respuestas) y re-ejecutable (idempotente).

## 2. Alcance

**Dentro:**
- `scripts/savia-setup.sh`: wizard interactivo por módulos + subcomandos por módulo + modo headless `--answers <file>`.
- Módulos M0-M8 (ver §4): detección, identidad/frontend, modelos/proveedor, MCPs, vaults local/remoto, federación, backends, autonomía/seguridad, aplicar+validar.
- Persistencia del estado de configuración en `~/.savia/savia-setup.json` (gitignored, resume).
- Generación/actualización de superficies reales: `opencode.json` (mcp + providers), `~/.savia/preferences.yaml`, `.claude/profiles/active-user.md`, `.claude/rules/pm-config.local.md` (si procede), domes de vault (directorio + INDEX + git remote), `CLAUDE.local.md` (backends, si procede).
- Validación post-aplicación y resumen.
- Tests BATS headless en sandbox (`--root` + `SAVIA_HOME_OVERRIDE`).
- Integración: `install.sh` (bootstrap) termina ofreciendo `savia setup`; `savia-install.sh` ejecuta sub-módulos idempotentes.

**Fuera:**
- No reescribe `.claude/settings.json` (118 hooks): el repo ya lo trae; el setup solo toca config personal/local no versionada.
- No es un gestor de paquetes de skills/agentes (eso es el repo).
- No migra instalaciones v1 de otros formatos.

## 3. Principios de diseño

1. **Interactivo por defecto, headless por contrato**: mismo motor; las preguntas del wizard se serializan en un fichero de respuestas reutilizable.
2. **Defaults seguros (CRIT-001)**: local-first (Ollama o proveedor con cuota local) salvo que el usuario elija otra cosa; vaults local por defecto; remoto solo con URL de **infraestructura propia** (git SSH/HTTPS del propio usuario/org), con aviso N1-N4.
3. **Estado único**: `~/.savia/savia-setup.json` es la fuente del estado del setup; las superficies (opencode.json, preferences.yaml…) se **derivan** de él (idempotente, no destructivo: merge sobre config existente).
4. **Por módulos**: cada módulo es invocable solo (`savia setup vaults`) y el wizard completo los recorre.
5. **Validable**: tras aplicar, corre comprobaciones (JSON parsea, mcp presente, dome indexado, preferences parseable, autoreviewer resoluble) y reporta.
6. **CRIT-001**: nunca contacta un proveedor cloud para telemetría; el único tráfico posible es el que el usuario pide (clone, git remote propio, descarga de binario opencode opcional).

## 4. Módulos (flujo del wizard)

### M0 — Preflight y detección
Detecta y muestra (no pregunta todavía): frontend (opencode/claude/ninguno), `~/.savia/preferences.yaml` (¿existe?), providers en `opencode.json`/model-registry, MCPs actuales en `opencode.json.mcp`, domes presentes en `vaults/`, git remotes de cada dome. Salida: estado "configurado/falta" por área → guía las preguntas.

### M1 — Identidad y frontend
- Operadora: nombre, rol → escribe `.claude/profiles/active-user.md` (slug derivado).
- Frontend: `opencode` | `claude-code` | `ambos` | ninguno. Si `opencode` y no está el binario → ofrecer `scripts/opencode-install.sh`.
- Persiste en `~/.savia/preferences.yaml` (`frontend`, `has_hooks`, `has_task_fan_out`, `has_slash_commands`).

### M2 — Modelos y proveedor
- Proveedor: `ollama (local)` | `zai-coding-plan` | `deepseek` | `azure-openai` | `otro openai-compat`. Default sugerido: el detectado; si ninguno, `ollama` si hay demonio local, si no `zai-coding-plan`.
- Modelos por tier (heavy/mid/fast) con valores por defecto del catálogo del proveedor.
- Escribe `~/.savia/preferences.yaml` (`provider`, `model_heavy/mid/fast`, `auth_kind`, `budget_kind`).

### M3 — MCP servers (conectar o no)
- Lista los MCP conocidos con su estado actual (leído de `opencode.json.mcp` + catálogo local): `codegraph`, `codebase-memory-mcp`, `savia-vaults`, y los opcionales de `mcp-templates/` que el usuario quiera habilitar (github, linear, knowledge-graph, savia-recall…).
- Por cada uno: habilitar/deshabilitar (merge en `opencode.json.mcp.enabled`). **CRIT-001**: `savia-vaults`/`knowledge-graph`/`savia-*` son locales; los externos (github/linear/sentry) avisan "este MCP puede enviar contexto a un tercero — solo si el usuario lo confirma".

### M4 — Vaults (SaviaVaults) local o remoto
- Modo de cada dome (`vaults/<Dome>`): crear si falta (directorio + `INDEX.md` con frontmatter N1/N2 por catálogo), conservar existente, o adjuntar remoto.
- **Local** (default): sin remote; backups `local` (tar.gz a `~/.savia/backups`).
- **Remoto**: URL git de infraestructura propia (git@host:user/repo o https propio); init git del dome + remote + push opcional; backups `remote`.
- Catálogo de domes conocido: SaviaDomains(N1), SaviaLabs(N2), savia-docs(N2), SaviaLearning(N2), Fronesia(N2). Permite añadir dome nuevo (nombre + nivel N1-N4).
- Escribe en estado; registra el MCP `savia-vaults` apuntando a la raíz de vaults.

### M5 — Federación
- Habilitar federación (on/off). Si on: añadir endpoints remotos de otros domes (URL A2A/MCP de **infra propia**) + registrar dome local como servible. Guarda en estado y en config del vault (vía `savia-vaults federate` si hay CLI, o fichero de federación del dome).

### M6 — Backends (PM)
- Azure DevOps (org + ruta al PAT **local**, `~/.azure/devops-pat` o similar) on/off; Jira; Savia Flow. Escribe en `CLAUDE.local.md` (valores reales) / limpia si off. CRIT-001: PAT en fichero local gitignored, nunca en repo.

### M7 — Autonomía y seguridad local
- `AUTONOMOUS_REVIEWER` handle, `AUTONOMOUS_RESEARCH_NOTIFY`, umbrales si el usuario quiere (si no, quedan sin configurar → los modos autónomos se auto-bloquean, correcto por defecto).
- Escribe `.claude/rules/pm-config.local.md` (gitignored) con la cadena de resolución de `savia-env.sh`.

### M8 — Aplicar + validar + resumen
- Aplica todo (writes), corre validaciones: `python3 -c json.load(opencode.json)`, mcp enabled consistentes, dome indexado (savia-vaults search devuelve), preferences YAML parsea, reviewer resoluble si se pidió.
- Reporte: tabla área → hecho/omitido; next steps.

## 5. Config y superficies (diseño técnico)

- **Estado**: `~/.savia/savia-setup.json` → `{version, updated_at, profile, frontend, models, mcp, vaults, federation, backends, autonomy}`. `SAVIA_HOME_OVERRIDE` para tests.
- **opencode.json**: merge de `mcp.<name>.enabled` y alta de MCP vaults; preserva el resto. Escritura atómica (tmp+rename) con python json.
- **preferences.yaml**: se regenera si no existe o se hace merge campo a campo (python).
- **Domes**: `vaults/<Dome>/INDEX.md` con frontmatter `entity.type: cupula` (mismo formato que las existentes).
- **Sanidad**: helpers `read_answer`, `ask_yn`, `ask_menu`, `save_state`, `apply_*`.

## 6. Criterios de aceptación

- **AC-0** `savia-setup.sh --help` documenta módulos y flags; `--check` muestra estado por área (test).
- **AC-1** Wizard headless (`--answers` mínimo: frontend=ninguno, proveedor=ollama, mcp=savia-vaults on, vaults=local) sobre `--root` sandbox + `SAVIA_HOME_OVERRIDE` produce: `opencode.json` con savia-vaults enabled, `preferences.yaml` creado, dome `vaults/SaviaLearning/INDEX.md` creado, estado `savia-setup.json` escrito (test).
- **AC-2** Re-ejecución con el mismo answers es idempotente (sin duplicar entradas MCP, sin duplicar domes) (test).
- **AC-3** `savia setup mcp --off codegraph` deshabilita codegraph en opencode.json sin tocar los demás (test).
- **AC-4** Vault **remoto**: answers con `vaults.remote_url` propia → el dome tiene `git remote` configurado y estado `mode=remote` (test en sandbox con repo local como "remoto" bare). CRIT-001: rechaza URL de dominio no propio salvo confirmación explícita `--allow-any-remote` (test negativo).
- **AC-5** Vault **nivel N3+** sin remote o con remote propio no validado → WARN y requiere confirmación (test).
- **AC-6** `savia setup --check` tras aplicar reporta "configurado" en las áreas aplicadas y "falta" en las no (test).
- **AC-7** No regresión: `savia-install.sh --dry-run` y JSON de opencode.json siguen válidos tras el merge (test).
- **AC-8** BATS: suite `tests/bats/test-savia-setup.bats` ≥ 10 tests verdes.

## 7. OpenCode Implementation Plan

### Bindings touched
- `scripts/savia-setup.sh` (nuevo, wizard + módulos + headless)
- `tests/bats/test-savia-setup.bats` (nuevo)
- `.opencode/install.sh` (fin: ofrecer `savia setup`)
- `scripts/savia-install.sh` (paso opcional `setup --apply-last`)
- `CHANGELOG.md` · spec nueva

### Verification protocol
```bash
bats tests/bats/test-savia-setup.bats
bash scripts/savia-setup.sh --check
bash scripts/savia-setup.sh --answers tests/fixtures/setup-answers.min.json --root /tmp/sandbox
bash scripts/savia-setup.sh mcp --off codegraph
```

### Portability classification
- Bash + python3 (json/yaml merge); local; portable; CRIT-001.

## 8. Iteraciones de la spec (self-review)

- **v1 → v2**: añadido M0 (detección guía las preguntas — sin estado no se puede preguntar bien); M5 federación delimitado a endpoints propios; AC-4/AC-5 casos negativos CRIT-001 (remoto solo propio salvo override explícito); tests piden ≥10 y sandbox con `--root`/`SAVIA_HOME_OVERRIDE`.
- **v2 → v3**: M7 separado de M6 (autonomía ≠ backend); "ambos frontends" como opción en M1; merge no destructivo en preferences.yaml (no regenerar a ciegas); idempotencia explícita (AC-2).
- **v3 → v4 (final)**: sin cambios de alcance; se fijan los ficheros tocados y el orden de aplicación M1→M8 con un único apply al final; validación incluye reviewer resoluble condicional.

## 9. Referencias
- `.opencode/install.sh` (actual) · `scripts/savia-install.sh` · `scripts/opencode-install.sh`
- `~/.savia/preferences.yaml` (SPEC-127) · `.claude/rules/pm-config.local.md` (Rule #20)
- `.opencode/skills/savia-identity/` · `docs/rules/domain/profile-onboarding.md`
- SaviaVaults (`.opencode/skills/savia-vaults/`) · CRIT-001
