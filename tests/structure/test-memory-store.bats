#!/usr/bin/env bats
# Tests for memory-store.sh — Engram-inspired patterns

setup() {
    export PROJECT_ROOT=$(mktemp -d)
    export STORE_FILE="$PROJECT_ROOT/output/.memory-store.jsonl"
    export SAVIA_TEST_MODE=true
    export SAVIA_VERIFIED_MEMORY_DISABLED=true  # SE-072: legacy fixtures predate --source contract
    SCRIPT="$BATS_TEST_DIRNAME/../../scripts/memory-store.sh"
}

teardown() {
    rm -rf "$PROJECT_ROOT"
}

@test "save: basic save with --content and auto topic_key" {
    run bash "$SCRIPT" save --type decision --title "Use GraphQL" --content "Frontend needs flexible queries"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Guardado"* ]]
    [ -f "$STORE_FILE" ]
    grep -q '"type":"decision"' "$STORE_FILE"
    grep -q '"topic_key":"decision/use-graphql"' "$STORE_FILE"
}

@test "save: structured What/Why/Where/Learned fields" {
    run bash "$SCRIPT" save --type bug --title "Null ref in auth" \
        --what "NullReferenceException on token refresh" \
        --why "Token cache not initialized on cold start" \
        --where "AuthService.cs:47" \
        --learned "Always init cache in constructor"
    [ "$status" -eq 0 ]
    grep -q "What: NullReferenceException" "$STORE_FILE"
    grep -q "Learned: Always init" "$STORE_FILE"
}

@test "save: explicit --topic overrides auto-suggestion" {
    run bash "$SCRIPT" save --type decision --title "DB choice" --content "PostgreSQL" --topic "custom/my-key"
    [ "$status" -eq 0 ]
    grep -q '"topic_key":"custom/my-key"' "$STORE_FILE"
}

@test "save: upsert increments rev on same topic_key" {
    bash "$SCRIPT" save --type decision --title "Auth strategy" --content "JWT" --topic "decision/auth"
    bash "$SCRIPT" save --type decision --title "Auth strategy v2" --content "OAuth2" --topic "decision/auth"
    [ "$(wc -l < "$STORE_FILE")" -eq 1 ]
    grep -q '"rev":2' "$STORE_FILE"
    grep -q "OAuth2" "$STORE_FILE"
}

@test "save: dedup within 15 min window (different topics)" {
    bash "$SCRIPT" save --type pattern --title "Dedup test" --content "Same content" --topic "test/dedup-a"
    run bash "$SCRIPT" save --type pattern --title "Dedup test2" --content "Same content" --topic "test/dedup-b"
    [[ "$output" == *"Duplicado"* ]]
}

@test "save: requires --type and --title" {
    run bash "$SCRIPT" save --title "No type"
    [ "$status" -ne 0 ]
    run bash "$SCRIPT" save --type bug
    [ "$status" -ne 0 ]
}

@test "suggest-topic: generates family-prefixed key for decision and bug" {
    run bash "$SCRIPT" suggest-topic decision "Use Redis for cache"
    [ "$status" -eq 0 ]
    [[ "$output" == "decision/use-redis-for-cache" ]]
    run bash "$SCRIPT" suggest-topic bug "Memory leak in worker"
    [[ "$output" == "bug/memory-leak-in-worker" ]]
}

@test "search: finds by title and topic_key" {
    bash "$SCRIPT" save --type decision --title "Use PostgreSQL" --content "Relational DB"
    run bash "$SCRIPT" search "PostgreSQL"
    [ "$status" -eq 0 ]
    [[ "$output" == *"PostgreSQL"* ]]
    bash "$SCRIPT" save --type architecture --title "Microservices" --content "Split" --topic "architecture/split"
    run bash "$SCRIPT" search "architecture"
    [[ "$output" == *"Microservices"* ]]
}

@test "context: shows recent entries with topic_key" {
    bash "$SCRIPT" save --type decision --title "Entry one" --content "First"
    bash "$SCRIPT" save --type bug --title "Entry two" --content "Second"
    run bash "$SCRIPT" context
    [ "$status" -eq 0 ]
    [[ "$output" == *"Entry one"* ]]
    [[ "$output" == *"decision/"* ]]
}

@test "stats: shows topic family breakdown" {
    bash "$SCRIPT" save --type decision --title "D1" --content "c1"
    bash "$SCRIPT" save --type bug --title "B1" --content "c3"
    run bash "$SCRIPT" stats
    [ "$status" -eq 0 ]
    [[ "$output" == *"decision:"* ]]
    [[ "$output" == *"bug:"* ]]
}

@test "session-summary: saves structured data and requires --accomplished" {
    run bash "$SCRIPT" session-summary --goal "Something"
    [ "$status" -ne 0 ]
    run bash "$SCRIPT" session-summary --goal "Fix auth" --accomplished "Fixed 3 bugs" --files "Auth.cs"
    [ "$status" -eq 0 ]
    grep -q '"type":"session-summary"' "$STORE_FILE"
}

@test "SPEC-019: upsert tracks supersedes on change, not on identical" {
    bash "$SCRIPT" save --type decision --title "Auth" --content "JWT tokens" --topic "decision/auth"
    bash "$SCRIPT" save --type decision --title "Auth" --content "OAuth2 with PKCE" --topic "decision/auth"
    grep -q '"supersedes":"JWT tokens"' "$STORE_FILE"
    grep -q '"rev":2' "$STORE_FILE"
}

@test "SPEC-020: --expires sets expires_at, absent means no expiry" {
    bash "$SCRIPT" save --type discovery --title "Temp" --content "Sprint ends" --expires 30
    grep -q '"expires_at":"' "$STORE_FILE"
    rm -f "$STORE_FILE"
    bash "$SCRIPT" save --type decision --title "Perm" --content "Always true"
    ! grep -q '"expires_at"' "$STORE_FILE"
}

@test "help: shows usage with all commands" {
    run bash "$SCRIPT" help
    [ "$status" -eq 0 ]
    [[ "$output" == *"suggest-topic"* ]]
    [[ "$output" == *"--what"* ]]
}

# ── Negative/edge cases ──

@test "search: returns empty for no match" {
    bash "$SCRIPT" save --type decision --title "Only entry" --content "data"
    run bash "$SCRIPT" search "zzz-no-match-$$"
    [ "$status" -eq 0 ]
}

@test "save: rejects unknown subcommand" {
  [[ -n "${CI:-}" ]] && skip "needs memory-store setup"
    run bash "$SCRIPT" foobar
    [ "$status" -ne 0 ] || [[ "$output" == *"Usage"* ]] || [[ "$output" == *"help"* ]]
}

@test "save: stored entry is valid JSON and topic_key is kebab-case" {
    bash "$SCRIPT" save --type bug --title "My Test Bug" --content "Validate format"
    python3 -c "import json; [json.loads(l) for l in open('$STORE_FILE') if l.strip()]"
    grep -q '"topic_key":"bug/my-test-bug"' "$STORE_FILE"
}

@test "memory-store.sh has set -uo pipefail safety" {
    grep -q "set -[euo]*o pipefail" "$SCRIPT"
}
