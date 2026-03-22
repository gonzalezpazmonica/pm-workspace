#!/usr/bin/env bats
# Tests for memory-store.sh — Engram-inspired patterns

setup() {
    export PROJECT_ROOT=$(mktemp -d)
    export STORE_FILE="$PROJECT_ROOT/output/.memory-store.jsonl"
    SCRIPT="$BATS_TEST_DIRNAME/../../scripts/memory-store.sh"
}

teardown() {
    rm -rf "$PROJECT_ROOT"
}

@test "save: basic save with --content" {
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
    grep -q "Why: Token cache" "$STORE_FILE"
    grep -q "Where: AuthService" "$STORE_FILE"
    grep -q "Learned: Always init" "$STORE_FILE"
}

@test "save: auto-generates topic_key from type/title" {
    run bash "$SCRIPT" save --type architecture --title "Event sourcing for orders" --content "CQRS pattern"
    [ "$status" -eq 0 ]
    grep -q '"topic_key":"architecture/event-sourcing-for-orders"' "$STORE_FILE"
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

@test "suggest-topic: generates family-prefixed key" {
    run bash "$SCRIPT" suggest-topic decision "Use Redis for cache"
    [ "$status" -eq 0 ]
    [[ "$output" == "decision/use-redis-for-cache" ]]
}

@test "suggest-topic: bug family" {
    run bash "$SCRIPT" suggest-topic bug "Memory leak in worker"
    [[ "$output" == "bug/memory-leak-in-worker" ]]
}

@test "search: finds by title" {
    bash "$SCRIPT" save --type decision --title "Use PostgreSQL" --content "Relational DB for orders"
    bash "$SCRIPT" save --type bug --title "Redis timeout" --content "Connection pool exhausted"
    run bash "$SCRIPT" search "PostgreSQL"
    [ "$status" -eq 0 ]
    [[ "$output" == *"PostgreSQL"* ]]
}

@test "search: finds by topic_key" {
    bash "$SCRIPT" save --type architecture --title "Microservices" --content "Split monolith" --topic "architecture/split"
    run bash "$SCRIPT" search "architecture"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Microservices"* ]]
}

@test "context: shows recent entries with topic_key" {
    bash "$SCRIPT" save --type decision --title "Entry one" --content "First"
    bash "$SCRIPT" save --type bug --title "Entry two" --content "Second"
    run bash "$SCRIPT" context
    [ "$status" -eq 0 ]
    [[ "$output" == *"Entry one"* ]]
    [[ "$output" == *"Entry two"* ]]
    [[ "$output" == *"decision/"* ]]
}

@test "stats: shows topic family breakdown" {
    bash "$SCRIPT" save --type decision --title "D1" --content "c1"
    bash "$SCRIPT" save --type decision --title "D2" --content "c2"
    bash "$SCRIPT" save --type bug --title "B1" --content "c3"
    run bash "$SCRIPT" stats
    [ "$status" -eq 0 ]
    [[ "$output" == *"decision: 2"* ]]
    [[ "$output" == *"bug: 1"* ]]
    [[ "$output" == *"familia topic_key"* ]]
}

@test "session-summary: saves structured session data" {
    run bash "$SCRIPT" session-summary \
        --goal "Fix auth bugs" \
        --accomplished "Fixed 3 bugs, added 5 tests" \
        --discoveries "Token cache was never initialized" \
        --files "AuthService.cs, AuthTests.cs"
    [ "$status" -eq 0 ]
    grep -q '"type":"session-summary"' "$STORE_FILE"
    grep -q "Goal: Fix auth bugs" "$STORE_FILE"
    grep -q "Accomplished: Fixed 3 bugs" "$STORE_FILE"
    grep -q '"topic_key":"session/' "$STORE_FILE"
}

@test "session-summary: requires --accomplished" {
    run bash "$SCRIPT" session-summary --goal "Something"
    [ "$status" -ne 0 ]
}

@test "SPEC-019: upsert tracks supersedes when content changes" {
    bash "$SCRIPT" save --type decision --title "Auth" --content "JWT tokens" --topic "decision/auth"
    bash "$SCRIPT" save --type decision --title "Auth" --content "OAuth2 with PKCE" --topic "decision/auth"
    grep -q '"supersedes":"JWT tokens"' "$STORE_FILE"
    grep -q '"rev":2' "$STORE_FILE"
}

@test "SPEC-019: upsert no supersedes when content identical" {
    bash "$SCRIPT" save --type decision --title "DB" --content "PostgreSQL" --topic "decision/db"
    bash "$SCRIPT" save --type decision --title "DB" --content "PostgreSQL" --topic "decision/db"
    # supersedes should NOT appear (same content = refresh, not change)
    ! grep -q '"supersedes"' "$STORE_FILE"
}

@test "SPEC-020: save with --expires sets expires_at" {
    run bash "$SCRIPT" save --type discovery --title "Temp info" --content "Sprint ends Friday" --expires 30
    [ "$status" -eq 0 ]
    grep -q '"expires_at":"' "$STORE_FILE"
}

@test "SPEC-020: save without --expires has no expires_at" {
    run bash "$SCRIPT" save --type decision --title "Permanent" --content "Always true"
    [ "$status" -eq 0 ]
    ! grep -q '"expires_at"' "$STORE_FILE"
}

@test "help: shows usage with all commands" {
    run bash "$SCRIPT" help
    [ "$status" -eq 0 ]
    [[ "$output" == *"suggest-topic"* ]]
    [[ "$output" == *"session-summary"* ]]
    [[ "$output" == *"--what"* ]]
    [[ "$output" == *"--learned"* ]]
}
