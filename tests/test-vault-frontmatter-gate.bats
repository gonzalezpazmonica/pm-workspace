#!/usr/bin/env bats
# BATS tests for .claude/hooks/vault-frontmatter-gate.sh
# Ref: SPEC-PROJECT-UPDATE F1 — frontmatter gate.

HOOK=".claude/hooks/vault-frontmatter-gate.sh"

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  # The hook resolves WORKSPACE via SAVIA_WORKSPACE_DIR/CLAUDE_PROJECT_DIR.
  # Point them at the real repo so the validator script is found.
  export SAVIA_WORKSPACE_DIR="$(pwd)"
  export CLAUDE_PROJECT_DIR="$(pwd)"
  unset SAVIA_VAULT_GATE_ENABLED
}

# ── Sanity ───────────────────────────────────────────────────────────────────

@test "hook exists and is executable" {
  [[ -x "$HOOK" ]]
}

@test "uses set -uo pipefail" {
  run grep -c 'set -uo pipefail' "$HOOK"
  [[ "$output" -ge 1 ]]
}

@test "passes bash -n syntax" {
  run bash -n "$HOOK"
  [ "$status" -eq 0 ]
}

# ── Early exits / out-of-scope ───────────────────────────────────────────────

@test "empty stdin exits 0" {
  run bash "$HOOK" <<< ""
  [ "$status" -eq 0 ]
}

@test "SAVIA_VAULT_GATE_ENABLED=false disables gate (even with bad payload)" {
  export SAVIA_VAULT_GATE_ENABLED=false
  payload='{"tool_input":{"file_path":"projects/aurora_main/aurora-monica/vault/10-PBIs/bad.md","content":"no fm"}}'
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 0 ]
}

@test "non-md path under vault is out-of-scope" {
  payload='{"tool_input":{"file_path":"projects/aurora_main/aurora-monica/vault/10-PBIs/foo.txt","content":"hi"}}'
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 0 ]
}

@test ".md outside any vault is out-of-scope" {
  payload='{"tool_input":{"file_path":"docs/foo.md","content":"# foo"}}'
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 0 ]
}

@test "input without file_path is out-of-scope" {
  payload='{"tool_input":{"content":"# foo"}}'
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 0 ]
}

@test "empty content is out-of-scope (e.g. delete)" {
  payload='{"tool_input":{"file_path":"projects/aurora_main/aurora-monica/vault/10-PBIs/x.md","content":""}}'
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 0 ]
}

# ── Valid frontmatter under vault ────────────────────────────────────────────

@test "valid PBI frontmatter passes" {
  body='---
entity_type: pbi
project: aurora
title: Test PBI
confidentiality: N4
pbi_id: "PBI-0001"
state: new
created: 2026-05-07
updated: 2026-05-07
---

body'
  payload=$(jq -n \
    --arg p "projects/aurora_main/aurora-monica/vault/10-PBIs/PBI-0001.md" \
    --arg c "$body" \
    '{tool_input:{file_path:$p,content:$c}}')
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 0 ]
}

@test "Edit tool with new_string carries the same gate" {
  body='---
entity_type: inbox
project: aurora
title: Capture
confidentiality: N4
created: 2026-05-07
updated: 2026-05-07
---

body'
  payload=$(jq -n \
    --arg p "projects/aurora_main/aurora-monica/vault/00-Inbox/x.md" \
    --arg c "$body" \
    '{tool_input:{file_path:$p,new_string:$c}}')
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 0 ]
}

# ── Invalid frontmatter blocks (exit 2) ──────────────────────────────────────

@test "missing pbi_id blocks with exit 2" {
  body='---
entity_type: pbi
project: aurora
title: Bad
confidentiality: N4
state: new
created: 2026-05-07
updated: 2026-05-07
---

body'
  payload=$(jq -n \
    --arg p "projects/aurora_main/aurora-monica/vault/10-PBIs/bad.md" \
    --arg c "$body" \
    '{tool_input:{file_path:$p,content:$c}}')
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"BLOCKED [vault-frontmatter-gate]"* ]] || [[ "$output" == *"BLOCKED"* ]]
}

@test "no frontmatter at all blocks with exit 2" {
  payload=$(jq -n \
    --arg p "projects/aurora_main/aurora-monica/vault/10-PBIs/raw.md" \
    --arg c "# Just a heading, no frontmatter" \
    '{tool_input:{file_path:$p,content:$c}}')
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 2 ]
}

@test "invalid confidentiality value blocks" {
  body='---
entity_type: inbox
project: aurora
title: bad
confidentiality: SECRET
created: 2026-05-07
updated: 2026-05-07
---

body'
  payload=$(jq -n \
    --arg p "projects/aurora_main/aurora-monica/vault/00-Inbox/x.md" \
    --arg c "$body" \
    '{tool_input:{file_path:$p,content:$c}}')
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 2 ]
}

@test "slug mismatch (path says aurora, fm says other) blocks" {
  body='---
entity_type: inbox
project: other
title: bad
confidentiality: N4
created: 2026-05-07
updated: 2026-05-07
---

body'
  payload=$(jq -n \
    --arg p "projects/aurora_main/aurora-monica/vault/00-Inbox/x.md" \
    --arg c "$body" \
    '{tool_input:{file_path:$p,content:$c}}')
  run bash "$HOOK" <<< "$payload"
  [ "$status" -eq 2 ]
}
