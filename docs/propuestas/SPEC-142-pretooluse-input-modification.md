---
spec_id: SPEC-142
title: Plugin tool.execute.before — auto-redaction de PATs y secrets via mutación de args
status: IMPLEMENTED
implementation_pr: 770
implementation_date: "2026-05-23"
slices_done: "1+2"
origin: Investigación 2026-05-23 (P4) + paridad OpenCode. OpenCode v1.14+ expone `tool.execute.before` en `.opencode/plugin/*.ts` que muta `args` directamente (modelo imperativo). Claude Code v2.0.10+ tiene equivalente funcional via `modifiedInput` — savia es opencode-native, especificamos el patrón OpenCode.
severity: Media — defiende Rule #1 (NUNCA hardcodear PAT) sin penalizar latencia. Hoy bloquea + el modelo reintenta.
effort: ~5h (S) — 1 plugin TS + tests + 1 doc.
priority: P4 — UX y seguridad determinista.
confidence: alta (mecanismo OpenCode confirmado)
bucket: Q2 2026
related_specs:
  - SPEC-127 (provider-agnostic env — el plugin detecta provider antes de aplicar)
  - SPEC-150 (hooks multi-handler — taxonomía OpenCode events)
---

# SPEC-142 — Plugin OpenCode para Auto-Redaction de Secrets

## Why

Rule #1 prohíbe hardcodear PATs. Actualmente los hooks bash que detectan `ghp_...`, `github_pat_...`, `sv=20...` (Azure SAS) emiten `exit 2` para bloquear, forzando al modelo a regenerar el comando — penaliza latencia y a veces el modelo no acierta la corrección.

OpenCode v1.14+ expone el evento `tool.execute.before` en `.opencode/plugin/*.ts` que permite **mutar `args` antes de ejecución**. Es el patrón imperativo equivalente al `modifiedInput` funcional de Claude Code (ver tabla de paridad). El plugin puede sustituir literal `ghp_xxxxxxxxxxxx` por `$(cat $PAT_FILE)` antes de que Bash lo ejecute. Beneficios:

- Determinista (no depende de re-prompt del modelo).
- Sin latencia adicional (el comando ejecuta corregido al primer intento).
- Audit trail explícito: el plugin anota qué sustituyó.
- Compatible con OpenCode v1.14+ sin depender de Claude-Code-only API.

## Scope

### Funcional

1. **Plugin `.opencode/plugin/savia-secret-redaction.ts`**:
   - Suscribe a `tool.execute.before` con matcher `tool === "bash"` (y opcionalmente `write`/`edit`).
   - Detecta PATs/secrets en `args.command` (Bash) o `args.content` (Write/Edit).
   - **Muta `args` directamente** sustituyendo por la expansión `$(cat $FILE)` apropiada según el patrón:
     - `ghp_*` / `github_pat_*` → `$(cat $GITHUB_PAT_FILE)`
     - `sv=20*` (Azure SAS) → `$(cat $AZURE_SAS_FILE)`
     - JWT estilo `eyJ*.eyJ*.*` → `$(cat $JWT_FILE)` con warning
     - DeepSeek `sk-*` → `$(cat $DEEPSEEK_KEY_FILE)`
   - Si la variable de fichero no está definida → **bloquea** vía `output.abort = "secret detected without configured env file"`. Mejor fallar que filtrar.

2. **Audit trail**: cada redacción anota una línea en `output/secret-redactions.jsonl`:
   ```json
   {"ts":"2026-05-23T10:00:00Z","tool":"bash","pattern":"ghp_*","redacted_to":"$(cat $GITHUB_PAT_FILE)","session":"abc"}
   ```

3. **Skill `caveman` integration**: si secret-redactions.jsonl muestra >3 redacciones en una sesión, el orchestrator avisa al usuario "estás pegando secretos crudos, considera env vars".

4. **Fallback Claude Code**: para usuarios todavía en Claude Code, mantener `pretooluse-secret-redaction.sh` legacy en `.claude/hooks/` con la misma lógica vía `hookSpecificOutput.modifiedInput`. Convergerán cuando OpenCode v1.14+ sea el único runtime.

### No funcional

- Cero falsos positivos en strings que no son secretos. Test con corpus de strings ambiguos (`ghp_test_in_docs`, `sk-no-real`).
- Latencia añadida <20ms (el plugin TS arranca con Bun, ya está cargado en la sesión).
- Idempotencia: si dos plugins mutan `args` en cadena, el orden está documentado en `opencode.jsonc` (los plugins corren en orden de declaración).

## Design

### Estructura

```
.opencode/plugin/
└── savia-secret-redaction.ts         # primary: plugin OpenCode

.claude/hooks/
└── pretooluse-secret-redaction.sh    # legacy, mismo comportamiento via hookSpecificOutput.modifiedInput

opencode.jsonc
└── plugin: ["./plugin/savia-secret-redaction.ts"]   # registro

output/
└── secret-redactions.jsonl           # append-only audit

docs/rules/domain/secret-redaction-policy.md   # qué patrones, por qué, qué hace
```

### Algoritmo (plugin TS, primary)

```typescript
// .opencode/plugin/savia-secret-redaction.ts
import { plugin } from "@opencode-ai/plugin";
import { appendFileSync } from "node:fs";

const PATTERNS = [
  { re: /ghp_[A-Za-z0-9]{36}/g, envFile: "GITHUB_PAT_FILE", name: "github_pat" },
  { re: /github_pat_[A-Za-z0-9_]{82,}/g, envFile: "GITHUB_PAT_FILE", name: "github_fine_pat" },
  { re: /sv=20[0-9]{2}-[0-9-]{8}T[0-9:%]{8}/g, envFile: "AZURE_SAS_FILE", name: "azure_sas" },
  { re: /eyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/g, envFile: "JWT_FILE", name: "jwt" },
  { re: /sk-[A-Za-z0-9]{32,}/g, envFile: "DEEPSEEK_KEY_FILE", name: "deepseek_key" },
];

export default plugin(({ on, output }) => {
  on("tool.execute.before", async (event) => {
    if (event.tool !== "bash") return;
    let cmd = event.args.command as string;
    if (!cmd) return;

    for (const { re, envFile, name } of PATTERNS) {
      if (re.test(cmd)) {
        const file = process.env[envFile];
        if (!file) {
          output.abort = `Secret detected (${name}) but \$${envFile} not set. Set it before running.`;
          return;
        }
        cmd = cmd.replace(re, `$(cat ${file})`);
        appendFileSync("output/secret-redactions.jsonl",
          JSON.stringify({ ts: new Date().toISOString(), tool: "bash", pattern: name, redacted_to: file, session: event.session?.id }) + "\n");
      }
    }
    event.args.command = cmd;  // mutación imperativa
  });
});
```

### Algoritmo (legacy Claude Code, fallback)

```bash
# .claude/hooks/pretooluse-secret-redaction.sh
input_json=$(cat)
cmd=$(echo "$input_json" | jq -r '.tool_input.command')
# ... misma lógica regex ...
if [[ "$modified" != "$cmd" ]]; then
  jq -n --arg cmd "$modified" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      modifiedInput: { command: $cmd }
    }
  }'
fi
```

## Acceptance Criteria

- [ ] AC-01: Plugin `.opencode/plugin/savia-secret-redaction.ts` intercepta `ghp_AAAABBBBCCCC...` en un bash call y muta `event.args.command` para que ejecute con `$(cat $GITHUB_PAT_FILE)`.
- [ ] AC-02: Si `$GITHUB_PAT_FILE` no está definido, plugin setea `output.abort` con mensaje claro y la ejecución se cancela.
- [ ] AC-03: Cero falsos positivos en corpus de 50 strings ambiguos (`ghp_in_docstring`, `sk-not-a-key`).
- [ ] AC-04: Audit append-only en `output/secret-redactions.jsonl` con timestamp, pattern, fichero destino, session_id.
- [ ] AC-05: Latencia p95 <20ms (plugin TS ya cargado).
- [ ] AC-06: Plugin registrado en `opencode.jsonc` bajo `plugin: [...]`.
- [ ] AC-07: Documentación `docs/rules/domain/secret-redaction-policy.md` con tabla pattern → var → fichero y nota sobre orden de mutación con otros plugins.
- [ ] AC-08: Tests TypeScript con vitest cubren los 5 patterns + 5 escenarios negativos.
- [ ] AC-09: Legacy hook `.claude/hooks/pretooluse-secret-redaction.sh` mantenido funcional para usuarios Claude Code (mismas semánticas).

## Agent Assignment

- **Capa**: Infrastructure
- **Agente principal**: `security-guardian`
- **Skills**: `caveman` (post-hoc audit), `verification-lattice` (gate quality)

## Slicing

- **Slice 1** (2h) — Plugin TS básico para `ghp_*` + audit + vitest. Registro en `opencode.jsonc`.
- **Slice 2** (1h) — Resto de patterns (Azure SAS, JWT, DeepSeek).
- **Slice 3** (1h) — Legacy hook bash equivalente para Claude Code users.
- **Slice 4** (1h) — Skill `caveman` warning + docs.

## Feasibility Probe

Slice 1: confirmar que la mutación de `event.args.command` se propaga al ejecutor de bash en OpenCode v1.14+ instalado localmente. Si el comportamiento difiere (eg. OpenCode lee args antes del hook), abrir issue upstream + documentar versión mínima que sí lo soporta.

## Riesgos

- **Falsos positivos en docstrings/comments**: mitigación — regex con `\b` y contexto. Excluir bloques con `<!-- ` o `# ` previo si patrón parece doc.
- **API change upstream**: la API de plugins OpenCode aún evoluciona (`tool.execute.before` confirmado mayo 2026). Pin a versión OpenCode mínima en `opencode.jsonc.experimental` o doc de prerequisites.
- **Sigilo malo**: si redactamos sin avisar, el modelo no sabe que su PAT fue cambiado. Solución: el plugin anota un comentario en el comando: `# [shield] PAT redacted to $(cat $FILE)`.
- **Orden de plugins**: si otro plugin también muta `args.command` en `tool.execute.before`, el resultado depende del orden de declaración en `opencode.jsonc.plugin: [...]`. Documentar el orden recomendado: secret-redaction PRIMERO, otros plugins después.
