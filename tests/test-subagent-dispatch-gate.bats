#!/usr/bin/env bats
# BATS tests for scripts/subagent-dispatch-gate.sh
# SE-313 S7c — gate de resolución de tiers + telemetría.
# Ref: docs/propuestas/SE-313-observabilidad-trazabilidad-agentes-eu-ai-act.md

SCRIPT="scripts/subagent-dispatch-gate.sh"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  export SAVIA_TELEMETRY_FILE="${BATS_TEST_TMPDIR:-/tmp}/telemetry-events.jsonl"
  rm -f "$SAVIA_TELEMETRY_FILE" 2>/dev/null || true
  # Registrar path de config (no depende del runtime)
  export SAVIA_WORKSPACE_DIR="$(pwd)"
  # Simular un provider configurado sin depender de ~/.savia/preferences.yaml
  # (CI no tiene prefs locales). mid resuelve a deepseek/deepseek-v4-pro.
  export SAVIA_MODEL_HEAVY="deepseek/deepseek-v4-pro"
  export SAVIA_MODEL_MID="deepseek/deepseek-v4-pro"
  export SAVIA_MODEL_FAST="deepseek/deepseek-v4-flash"
  # savia_resolve_model also reads the provider from ~/.savia/preferences.yaml
  # to prefix bare IDs; isolate HOME so the operator's real provider never leaks in.
  export HOME="${BATS_TEST_TMPDIR}/home"
  mkdir -p "$HOME/.savia"
  printf 'provider: deepseek\n' > "$HOME/.savia/preferences.yaml"
}

teardown() {
  rm -f "${SAVIA_TELEMETRY_FILE:-}" 2>/dev/null || true
  cd /
}

@test "script exists and is executable" {
  [[ -f "$SCRIPT" ]]
  [[ -x "$SCRIPT" ]]
}

@test "passes bash -n syntax" {
  run bash -n "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "tier mid resuelve con prefijo de provider y emite dispatch.resolved" {
  run bash "$SCRIPT" --agent dotnet-developer --tier mid
  [ "$status" -eq 0 ]
  [[ "$output" == *"deepseek/deepseek-v4-pro"* ]]
  [[ -f "$SAVIA_TELEMETRY_FILE" ]]
  run jq -e '.event == "dispatch.resolved" and .agent_name == "dotnet-developer"' "$SAVIA_TELEMETRY_FILE"
  [ "$status" -eq 0 ]
}

@test "modelo inexistente en registry emite dispatch.failed (exit 1)" {
  run bash "$SCRIPT" --agent fake-agent --model claude-3-7-sonnet-20250219
  [ "$status" -eq 1 ]
  [[ -f "$SAVIA_TELEMETRY_FILE" ]]
  run jq -e '.event == "dispatch.failed" and .error' "$SAVIA_TELEMETRY_FILE"
  [ "$status" -eq 0 ]
}

@test "sin tier ni model no bloquea (WARN, exit 0)" {
  run bash "$SCRIPT" --agent code-twin-agent
  [ "$status" -eq 0 ]
}

@test "ID sin prefijo se auto-prefija via savia_resolve_model" {
  run bash "$SCRIPT" --agent x --model deepseek-v4-pro
  [ "$status" -eq 0 ]
  [[ "$output" == *"deepseek/deepseek-v4-pro"* ]]
}

@test "isolation: bare ID prefixing follows the fixture provider, not the operator's prefs" {
  printf 'provider: other\n' > "$HOME/.savia/preferences.yaml"
  run bash "$SCRIPT" --agent x --model deepseek-v4-pro
  [ "$status" -ne 0 ]
  [[ "$output" == *"'deepseek-v4-pro' no existe"* ]]
}

@test "native alias: sonnet resolves as valid under Claude Code (default tiers since #1139)" {
  run env -u CLAUDE_CODE_ENTRYPOINT -u OPENCODE_PROVIDER -u OPENCODE_PROJECT_DIR -u CODEX_HOME -u SAVIA_FRONTEND \
    CLAUDECODE=1 SAVIA_MODEL_MID=sonnet bash "$SCRIPT" --agent x --tier mid
  [ "$status" -eq 0 ]
}

@test "reject: the claude alias is not valid under OpenCode (needs provider/model)" {
  run env -u CLAUDECODE -u CLAUDE_CODE_ENTRYPOINT -u CODEX_HOME -u SAVIA_FRONTEND \
    OPENCODE_PROVIDER=x SAVIA_MODEL_MID=sonnet bash "$SCRIPT" --agent x --tier mid
  [ "$status" -eq 1 ]
  [[ "$output" == *"'sonnet' no existe"* ]]
}

@test "empty: unknown frontend does not accept frontend-native aliases" {
  run env -u CLAUDECODE -u CLAUDE_CODE_ENTRYPOINT -u OPENCODE_PROVIDER -u OPENCODE_PROJECT_DIR -u CODEX_HOME -u CODEX_SANDBOX -u CODEX_THREAD_ID -u SAVIA_FRONTEND \
    SAVIA_MODEL_MID=sonnet bash "$SCRIPT" --agent x --tier mid
  [ "$status" -eq 1 ]
}

@test "safety: gate runs under set -uo pipefail and registry declares native aliases" {
  grep -q 'set -uo pipefail' "$SCRIPT"
  jq -e '.native_aliases.claude | index("sonnet")' config/model-registry.json >/dev/null
}

@test "nonexistent: unknown flag exits 2" {
  run bash "$SCRIPT" --bogus
  [ "$status" -eq 2 ]
}
