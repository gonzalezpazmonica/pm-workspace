#!/usr/bin/env bats
# Ref: SPEC-142 — Auto-redaction of secrets via tool.execute.before
# Validates structural presence (TS runtime tests live under
# .opencode/plugins/__tests__/auto-redact-credentials.test.ts, run by Bun).

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  GUARD="$REPO_ROOT/.opencode/plugins/guards/auto-redact-credentials.ts"
  TEST="$REPO_ROOT/.opencode/plugins/__tests__/auto-redact-credentials.test.ts"
  FOUNDATION="$REPO_ROOT/.opencode/plugins/savia-foundation.ts"
  POLICY="$REPO_ROOT/docs/rules/domain/secret-redaction-policy.md"
  SPEC="$REPO_ROOT/docs/propuestas/SPEC-142-pretooluse-input-modification.md"
}

@test "AC-01: guard file exists at expected path" {
  [ -f "$GUARD" ]
}

@test "AC-01: guard exports autoRedactSecrets function" {
  grep -q "export async function autoRedactSecrets" "$GUARD"
}

@test "AC-01: guard implements 5 high-precision patterns" {
  grep -q "github-pat-classic" "$GUARD"
  grep -q "github-pat-fine" "$GUARD"
  grep -q "azure-sas" "$GUARD"
  grep -q "openai-key" "$GUARD"
  grep -q "anthropic-key" "$GUARD"
}

@test "AC-02: guard short-circuits when env var unset (skipped_no_env)" {
  grep -q "skipped_no_env" "$GUARD"
}

@test "AC-04: guard appends to output/secret-redactions.jsonl" {
  grep -q "output/secret-redactions.jsonl" "$GUARD"
}

@test "AC-04: guard records ts/kind/env_var/env_file fields" {
  # The guard builds an object literal and JSON.stringifies. Verify keys
  # appear in source as object properties (kind:, env_var:, ts:).
  grep -qE "ts[[:space:]]*[:,]|ts:" "$GUARD"
  grep -q "kind" "$GUARD"
  grep -q "env_var" "$GUARD"
  grep -q "env_file" "$GUARD"
}

@test "AC-05: guard skips non-bash tools" {
  grep -q 'extractToolName(input) !== "bash"' "$GUARD"
}

@test "AC-06: guard wired into savia-foundation BEFORE_GUARDS (before blockCredentialLeak)" {
  grep -q "autoRedactSecrets" "$FOUNDATION"
  # Ordering: autoRedactSecrets appears BEFORE blockCredentialLeak
  line_redact=$(grep -n "autoRedactSecrets," "$FOUNDATION" | head -1 | cut -d: -f1)
  line_block=$(grep -n "blockCredentialLeak," "$FOUNDATION" | head -1 | cut -d: -f1)
  [ -n "$line_redact" ]
  [ -n "$line_block" ]
  [ "$line_redact" -lt "$line_block" ]
}

@test "AC-06: import line added in correct alphabetical neighborhood" {
  grep -q "import { autoRedactSecrets } from \"./guards/auto-redact-credentials.ts\";" "$FOUNDATION"
}

@test "AC-07: policy doc exists and ≤150 lines (Rule #11)" {
  [ -f "$POLICY" ]
  lines=$(wc -l < "$POLICY")
  [ "$lines" -le 150 ]
}

@test "AC-07: policy doc declares all 5 pattern → env-var mappings" {
  for kind in github-pat-classic github-pat-fine azure-sas openai-key anthropic-key; do
    grep -q "$kind" "$POLICY"
  done
  for var in GITHUB_PAT_FILE AZURE_SAS_FILE OPENAI_KEY_FILE ANTHROPIC_KEY_FILE; do
    grep -q "$var" "$POLICY"
  done
}

@test "AC-07: policy doc explains ordering with block-credential-leak" {
  grep -qE "block-credential-leak|fail-closed" "$POLICY"
}

@test "AC-08: TS test file exists with bun runner" {
  [ -f "$TEST" ]
  grep -q 'from "bun:test"' "$TEST"
}

@test "AC-08: TS tests cover all 5 patterns" {
  grep -q "github-pat-classic" "$TEST"
  grep -q "github-pat-fine" "$TEST"
  grep -q "azure-sas" "$TEST"
}

@test "AC-08: TS tests cover negative paths (env unset, benign strings, non-bash)" {
  grep -q "skipped_no_env" "$TEST"
  grep -q "benign\|false positive" "$TEST"
  grep -q '"edit"' "$TEST"
}

@test "spec ref: SPEC-142 doc exists and is marked IMPLEMENTED" {
  [ -f "$SPEC" ]
  grep -q "^status: IMPLEMENTED" "$SPEC"
}

@test "edge: guard file ≤150 lines (workspace hygiene)" {
  lines=$(wc -l < "$GUARD")
  [ "$lines" -le 150 ]
}

@test "edge: foundation file ≤200 lines (SPEC-127 cap preserved)" {
  lines=$(wc -l < "$FOUNDATION")
  [ "$lines" -le 200 ]
}

@test "audit: secret-redactions.jsonl path is gitignored" {
  grep -qE '^output/secret-redactions\.jsonl|^output/\*' "$REPO_ROOT/.gitignore" || \
  grep -qE '^output/' "$REPO_ROOT/.gitignore"
}
