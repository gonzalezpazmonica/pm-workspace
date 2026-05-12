#!/usr/bin/env bats
# tests/context-guard-wrapper.bats — Slice 2 Bash wrapper tests.
# Tests scripts/context-guard-recall.sh and CLI module invocation.
# Spec §4 Slice 2 AC. Rule #26.

setup() {
    WORKSPACE_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    TMPDIR_RUN="$(mktemp -d)"
    export PYTHONPATH="${WORKSPACE_DIR}"
}

teardown() {
    rm -rf "${TMPDIR_RUN}"
}

@test "context-guard-recall.sh exists and is executable" {
    [ -x "${WORKSPACE_DIR}/scripts/context-guard-recall.sh" ]
}

@test "cli list returns empty JSON for unknown run" {
    result=$(python3 -m scripts.lib.context_guard.cli \
        --base-dir "${TMPDIR_RUN}" list "no-such-run")
    echo "${result}" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['summaries']==[], d"
}

@test "cli summarize --force creates summary file" {
    turns_file="${TMPDIR_RUN}/turns.json"
    python3 -c "
import json
turns = [{'role': 'user', 'content': 'hello world'*10}, {'role': 'assistant', 'content': 'ok'*10}]
json.dump(turns, open('${turns_file}', 'w'))
"
    python3 -m scripts.lib.context_guard.cli \
        --base-dir "${TMPDIR_RUN}" summarize bats-run-01 \
        --turns-file "${turns_file}" \
        --force

    [ -d "${TMPDIR_RUN}/bats-run-01" ]
    yaml_count=$(ls "${TMPDIR_RUN}/bats-run-01"/summary-*.yaml 2>/dev/null | wc -l)
    [ "${yaml_count}" -eq 1 ]
}

@test "cli list shows summary after summarize" {
    turns_file="${TMPDIR_RUN}/turns2.json"
    python3 -c "
import json
turns = [{'role': 'user', 'content': 'content'*20}]
json.dump(turns, open('${turns_file}', 'w'))
"
    python3 -m scripts.lib.context_guard.cli \
        --base-dir "${TMPDIR_RUN}" summarize bats-list-run \
        --turns-file "${turns_file}" --force

    result=$(python3 -m scripts.lib.context_guard.cli \
        --base-dir "${TMPDIR_RUN}" list bats-list-run)
    echo "${result}" | python3 -c "
import sys, json
d = json.load(sys.stdin)
assert len(d['summaries']) == 1, d
assert d['summaries'][0] == 'summary-001', d
"
}

@test "cli recall returns valid YAML for existing summary" {
    turns_file="${TMPDIR_RUN}/turns3.json"
    python3 -c "
import json
turns = [{'role': 'user', 'content': 'w '*50}]
json.dump(turns, open('${turns_file}', 'w'))
"
    python3 -m scripts.lib.context_guard.cli \
        --base-dir "${TMPDIR_RUN}" summarize bats-recall-run \
        --turns-file "${turns_file}" --force

    output=$(python3 -m scripts.lib.context_guard.cli \
        --base-dir "${TMPDIR_RUN}" recall bats-recall-run)
    echo "${output}" | python3 -c "
import sys, yaml
d = yaml.safe_load(sys.stdin)
assert 'summary_v1' in d, list(d.keys())
assert '_meta' in d, list(d.keys())
"
}

@test "cli recall exits 1 for missing run_id" {
    run python3 -m scripts.lib.context_guard.cli \
        --base-dir "${TMPDIR_RUN}" recall "nonexistent-run"
    [ "${status}" -eq 1 ]
}

@test "mcp_server module importable without error" {
    python3 -c "from scripts.lib.context_guard.mcp_server import build_server; s = build_server(); print(type(s).__name__)"
}

@test "context-guard-recall.sh exits 1 for missing run" {
    run bash "${WORKSPACE_DIR}/scripts/context-guard-recall.sh" "no-such-run-bats"
    [ "${status}" -eq 1 ]
}
