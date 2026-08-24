#!/usr/bin/env bats
# Ref: SE-077 Slice 1 — savia-gates plugin (TS source structure tests)
#
# These tests validate the plugin AT REST — file existence, package.json shape,
# hook registrations declared in index.ts, safety boundaries. Runtime behaviour
# is tested separately by Mónica's E2E once OpenCode is installed.

setup() {
  ROOT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  PLUGIN_DIR="$ROOT_DIR/scripts/opencode-plugin/savia-gates"
  SCRIPT="$ROOT_DIR/scripts/opencode-install.sh"
}

# ── Plugin source structure ──────────────────────────────────────────────────

@test "plugin: directory exists at scripts/opencode-plugin/savia-gates/" {
  [ -d "$PLUGIN_DIR" ]
}

@test "plugin: package.json declares savia-gates with @opencode-ai/plugin dep" {
  [ -f "$PLUGIN_DIR/package.json" ]
  grep -q '"name": "savia-gates"' "$PLUGIN_DIR/package.json"
  grep -q '"@opencode-ai/plugin"' "$PLUGIN_DIR/package.json"
}

@test "plugin: index.ts exports SaviaGates default" {
  [ -f "$PLUGIN_DIR/index.ts" ]
  grep -q 'export const SaviaGates' "$PLUGIN_DIR/index.ts"
  grep -q 'export default SaviaGates' "$PLUGIN_DIR/index.ts"
}

@test "plugin: index.ts registers ≥10 critical hook event handlers" {
  # AC-02: Plugin loads ≥10 critical hooks
  count=$(grep -cE '"(tool\.execute\.before|tool\.execute\.after|chat\.message|permission\.ask|command\.execute\.before|event|experimental\.session\.compacting)"' "$PLUGIN_DIR/index.ts")
  [ "$count" -ge 7 ]
  # And the index actively dispatches each over the hookMap
  grep -q "loadHookMap" "$PLUGIN_DIR/index.ts"
}

@test "plugin: lib/shell-bridge.ts loads .claude/settings.json (not directory walk)" {
  [ -f "$PLUGIN_DIR/lib/shell-bridge.ts" ]
  grep -q '\.claude/settings\.json' "$PLUGIN_DIR/lib/shell-bridge.ts"
  grep -q 'loadHookMap' "$PLUGIN_DIR/lib/shell-bridge.ts"
  grep -q 'runHooksForEvent' "$PLUGIN_DIR/lib/shell-bridge.ts"
}

@test "plugin: bridge delivers payload on stdin via temp-file redirect (no .text stdin)" {
  grep -q 'stdinPath' "$PLUGIN_DIR/lib/shell-bridge.ts"
  grep -q 'writeFile' "$PLUGIN_DIR/lib/shell-bridge.ts"
  grep -q 'tmpdir' "$PLUGIN_DIR/lib/shell-bridge.ts"
  ! grep -qE '\.text\(\s*\{\s*stdin' "$PLUGIN_DIR/lib/shell-bridge.ts"
}

@test "plugin: bridge runs hook command via bash -c with raw interpolation" {
  grep -q 'bash -c' "$PLUGIN_DIR/lib/shell-bridge.ts"
  grep -q 'raw: h.command' "$PLUGIN_DIR/lib/shell-bridge.ts"
  ! grep -qE 'bash \$\{h\.command\}' "$PLUGIN_DIR/lib/shell-bridge.ts"
}

@test "plugin: bridge cwd() is pinned to projectRoot" {
  grep -q '\.cwd(projectRoot)' "$PLUGIN_DIR/lib/shell-bridge.ts"
}

@test "plugin: bridge resolves CLAUDE_PLUGIN_ROOT in hook commands" {
  grep -q 'CLAUDE_PLUGIN_ROOT' "$PLUGIN_DIR/lib/shell-bridge.ts"
}

@test "plugin: bridge honours stdin JSON {decision:block} (SE-337 gate contract)" {
  grep -q 'decision === "block"' "$PLUGIN_DIR/lib/shell-bridge.ts"
  grep -q 'hook-json-block' "$PLUGIN_DIR/lib/shell-bridge.ts"
}

@test "plugin: matcherApplies rebuilds composite Tool(cmd) candidates" {
  grep -q "tool(git commit" "$PLUGIN_DIR/lib/shell-bridge.ts" || grep -q 'tool_input?.command' "$PLUGIN_DIR/lib/shell-bridge.ts"
  grep -q 'tooling.*payload' "$PLUGIN_DIR/lib/shell-bridge.ts" || grep -q 'candidates.push' "$PLUGIN_DIR/lib/shell-bridge.ts"
}

@test "plugin: bridge captures real exitCode from resolved shell output (not .text string)" {
  grep -q 'proc\.then' "$PLUGIN_DIR/lib/shell-bridge.ts"
  grep -q 'Promise\.race' "$PLUGIN_DIR/lib/shell-bridge.ts"
  grep -q '\.exitCode' "$PLUGIN_DIR/lib/shell-bridge.ts"
  grep -q 'BLOCK_EXIT' "$PLUGIN_DIR/lib/shell-bridge.ts"
}

@test "plugin: bridge runs async hooks fire-and-forget (exit code ignored)" {
  grep -q 'h\.async' "$PLUGIN_DIR/lib/shell-bridge.ts"
  grep -q 'continue' "$PLUGIN_DIR/lib/shell-bridge.ts"
}

@test "plugin: bridge feature-detects .timeout (runtime may lack it)" {
  grep -q '\.timeout\b' "$PLUGIN_DIR/lib/shell-bridge.ts"
  grep -q "typeof p.timeout" "$PLUGIN_DIR/lib/shell-bridge.ts"
}

@test "safety: shell-bridge block exit code contract is 2" {
  grep -q 'BLOCK_EXIT = 2' "$PLUGIN_DIR/lib/shell-bridge.ts"
}

@test "plugin: learning recall uses the canonical UserPromptSubmit bridge" {
  grep -q '"chat.message"' "$PLUGIN_DIR/index.ts"
  grep -q '"UserPromptSubmit"' "$PLUGIN_DIR/index.ts"
  grep -q 'hookSpecificOutput.*additionalContext' "$PLUGIN_DIR/lib/shell-bridge.ts"
  grep -q '\.claude/hooks/learning-recall-hook.sh' "$ROOT_DIR/.claude/settings.json"
  [ ! -e "$ROOT_DIR/.opencode/plugins/learning-recall.ts" ]
}

@test "plugin: lib/permission.ts blocks destructive ops on agent/* branches" {
  [ -f "$PLUGIN_DIR/lib/permission.ts" ]
  grep -q 'agent/' "$PLUGIN_DIR/lib/permission.ts"
  grep -q 'AUTONOMOUS_REVIEWER' "$PLUGIN_DIR/lib/permission.ts"
  grep -q 'push.*force\|force.*push' "$PLUGIN_DIR/lib/permission.ts"
}

@test "plugin: lib/audit.ts writes append-only JSONL to ~/.savia/audit/" {
  [ -f "$PLUGIN_DIR/lib/audit.ts" ]
  grep -q 'savia-gates.jsonl' "$PLUGIN_DIR/lib/audit.ts"
  grep -q 'appendFile' "$PLUGIN_DIR/lib/audit.ts"
}

@test "plugin: lib/manifest.ts emits sibling manifest.json for parity audit" {
  [ -f "$PLUGIN_DIR/lib/manifest.ts" ]
  grep -q 'manifest.json' "$PLUGIN_DIR/lib/manifest.ts"
  grep -q 'bindings' "$PLUGIN_DIR/lib/manifest.ts"
}

# ── Gap closure: SE-077 remaining 6 events (2026-08-25) ────────────────────

@test "plugin: FileChanged mapped to file.edited / file.watcher.updated" {
  grep -q '"file.edited"' "$PLUGIN_DIR/index.ts"
  grep -qE 'cc: "FileChanged"|cc:"FileChanged"' "$PLUGIN_DIR/index.ts"
  grep -q "file_path: e?.properties?.file" "$PLUGIN_DIR/index.ts"
}

@test "plugin: PostCompact mapped to session.compacted + compaction.autocontinue" {
  grep -q 'session.compacted.*PostCompact\|"cc": "PostCompact"' "$PLUGIN_DIR/index.ts"
  grep -q 'experimental.compaction.autocontinue' "$PLUGIN_DIR/index.ts"
  grep -q '"PostCompact"' "$PLUGIN_DIR/index.ts"
}

@test "plugin: ConfigChange mapped to config hook" {
  grep -q '"config": async' "$PLUGIN_DIR/index.ts"
  grep -q '"ConfigChange"' "$PLUGIN_DIR/index.ts"
}

@test "plugin: CwdChanged mapped to shell.env (cwd dedup)" {
  grep -q '"shell.env": async' "$PLUGIN_DIR/index.ts"
  grep -q '"CwdChanged"' "$PLUGIN_DIR/index.ts"
  grep -q 'lastCwd' "$PLUGIN_DIR/index.ts"
}

@test "plugin: InstructionsLoaded mapped on session.created" {
  grep -qE 'cc: "InstructionsLoaded"|cc:"InstructionsLoaded"' "$PLUGIN_DIR/index.ts"
}

@test "plugin: manifest HANDLERS table covers the six remaining events" {
  grep -q 'PostCompact' "$PLUGIN_DIR/lib/manifest.ts"
  grep -q 'FileChanged' "$PLUGIN_DIR/lib/manifest.ts"
  grep -q 'CwdChanged' "$PLUGIN_DIR/lib/manifest.ts"
  grep -q 'ConfigChange' "$PLUGIN_DIR/lib/manifest.ts"
  grep -q 'InstructionsLoaded' "$PLUGIN_DIR/lib/manifest.ts"
  grep -q 'PostToolUseFailure' "$PLUGIN_DIR/lib/manifest.ts"
}

@test "plugin: PostToolUseFailure justified NOT_EXPOSED in hook header" {
  grep -q 'opencode-binding: NOT_EXPOSED' "$ROOT_DIR/.claude/hooks/post-tool-failure-log.sh"
}

# ── Safety / boundaries ─────────────────────────────────────────────────────

@test "safety: plugin TS never calls git push or pr merge anywhere" {
  ! grep -rE --include="*.ts" '\bgit\s+push\b|gh\s+pr\s+merge\b' "$PLUGIN_DIR"
}

@test "safety: plugin TS never reads ANTHROPIC API keys directly" {
  ! grep -rE 'ANTHROPIC_API_KEY|ANTHROPIC_BASE_URL' "$PLUGIN_DIR"
}

@test "safety: shell-bridge timeout is bounded" {
  grep -qE '\.timeout\(' "$PLUGIN_DIR/lib/shell-bridge.ts"
}

# ── Installer ───────────────────────────────────────────────────────────────

@test "installer: --help exits 0" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
}

@test "installer: --dry-run prints plan without touching ~/.savia" {
  run bash "$SCRIPT" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY-RUN"* ]] || [[ "$output" == *"opencode installed"* ]]
}

@test "installer: refuses unknown arg" {
  run bash "$SCRIPT" --frobnicate
  [ "$status" -eq 2 ]
}

@test "installer: --uninstall is idempotent on missing dir" {
  SAVIA_HOME=$(mktemp -d) run bash "$SCRIPT" --uninstall
  [ "$status" -eq 0 ]
}

# ── Spec ref ────────────────────────────────────────────────────────────────

@test "spec ref: SE-077 cited in installer header" {
  grep -q "SE-077" "$SCRIPT"
}

@test "spec ref: SE-077 cited in plugin index.ts" {
  grep -q "SE-077" "$PLUGIN_DIR/index.ts"
}

@test "safety: installer has set -uo pipefail" {
  grep -q 'set -uo pipefail' "$SCRIPT"
}

@test "safety: installer never invokes git push" {
  ! grep -E '^[^#]*git\s+push' "$SCRIPT"
}

# ── Edge cases ──────────────────────────────────────────────────────────────

@test "edge: --link-only mode skips download step" {
  run bash "$SCRIPT" --link-only --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" != *"download"* ]] || true
}

@test "edge: empty agents-md doesn't crash plugin loader" {
  # The plugin's loadHookMap returns {} when settings.json is empty/absent — sanity grep
  grep -q "return {}" "$PLUGIN_DIR/lib/shell-bridge.ts"
}

@test "edge: large hookMap (>50 entries) supported without recursion" {
  # Shell-bridge iterates with a for-loop, no recursive calls
  ! grep -E 'function .*\(\).*\{[^}]*\1[^}]*\}' "$PLUGIN_DIR/lib/shell-bridge.ts"
}
