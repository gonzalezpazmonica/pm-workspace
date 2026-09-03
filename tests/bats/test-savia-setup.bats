#!/usr/bin/env bats
# SE-372 — Savia Setup: inicializador interactivo (AC-0..AC-8)
# Ref: docs/specs/SE-372-savia-setup.spec.md
# CRIT-001: sandbox local; remoto solo infra propia salvo --allow-any-remote.

SETUP="bash scripts/savia-setup.sh"

setup() {
    TMPD="$(mktemp -d)"
    SB="$TMPD/root"
    SV="$TMPD/home"
    mkdir -p "$SB/.claude/profiles" "$SB/.claude/rules" "$SB/vaults" "$SV"
    python3 - "$SB/opencode.json" <<'PY'
import json, sys
d = {"mcp": {
    "codegraph": {"type": "local", "enabled": True},
    "codebase-memory-mcp": {"type": "local", "enabled": True},
    "savia-vaults": {"type": "local", "enabled": False}}}
json.dump(d, open(sys.argv[1], "w"), indent=2)
PY
}

teardown() {
    rm -rf "$TMPD"
}

answers_min() {
    cat > "$SV/a.json" <<'EOF'
{"profile":{"name":"Mónica","role":"Operadora"},
 "frontend":{"primary":"opencode"},
 "models":{"provider":"ollama"},
 "mcp":{"enabled":["savia-vaults"],"disabled":["codegraph","codebase-memory-mcp"]},
 "vaults":{"domes":[{"name":"SaviaLearning","mode":"local","confidentiality":"N2","backup":"local"}],"root_served":true},
 "federation":{"enabled":true,"remotes":[]},
 "backends":{},"autonomy":{}}
EOF
}

@test "SE-372 AC-0: --help documenta modulos y --check muestra estado" {
    run $SETUP --help
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "vaults"
    run env SAVIA_HOME_OVERRIDE="$SV" $SETUP --root "$SB" --check
    [ "$status" -eq 0 ]
    echo "$output" | grep -qi "estado por area"
}

@test "SE-372 AC-1: headless aplica mcp+prefs+dome+estado" {
    answers_min
    run env SAVIA_HOME_OVERRIDE="$SV" $SETUP --root "$SB" --answers "$SV/a.json"
    [ "$status" -eq 0 ]
    python3 -c "import json;d=json.load(open('$SB/opencode.json'));assert d['mcp']['savia-vaults']['enabled'] is True;assert d['mcp']['codegraph']['enabled'] is False"
    [ -f "$SV/preferences.yaml" ] && grep -q '^provider: ollama' "$SV/preferences.yaml"
    [ -f "$SB/vaults/SaviaLearning/INDEX.md" ]
    [ -f "$SV/savia-setup.json" ]
    [ -f "$SB/.claude/profiles/active-user.md" ]
}

@test "SE-372 AC-2: re-ejecucion idempotente (sin duplicar dome ni romper)" {
    answers_min
    env SAVIA_HOME_OVERRIDE="$SV" $SETUP --root "$SB" --answers "$SV/a.json" >/dev/null
    local antes
    antes=$(find "$SB/vaults" -name INDEX.md | wc -l)
    run env SAVIA_HOME_OVERRIDE="$SV" $SETUP --root "$SB" --answers "$SV/a.json"
    [ "$status" -eq 0 ]
    local despues
    despues=$(find "$SB/vaults" -name INDEX.md | wc -l)
    [ "$antes" -eq "$despues" ]
    python3 -c "import json; json.load(open('$SB/opencode.json'))"
}

@test "SE-372 AC-3: modulo mcp --off codegraph deshabilita sin tocar resto" {
    answers_min
    env SAVIA_HOME_OVERRIDE="$SV" $SETUP --root "$SB" --answers "$SV/a.json" >/dev/null
    python3 - "$SB/opencode.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
d["mcp"]["enabled"] = []  # noop
PY
    cat > "$SV/m.json" <<'EOF'
{"mcp":{"enabled":[],"disabled":["codegraph"]}}
EOF
    run env SAVIA_HOME_OVERRIDE="$SV" $SETUP --root "$SB" mcp --answers "$SV/m.json"
    [ "$status" -eq 0 ]
    python3 -c "import json;d=json.load(open('$SB/opencode.json'));assert d['mcp']['codegraph']['enabled'] is False;assert d['mcp']['savia-vaults']['enabled'] is True"
}

@test "SE-372 AC-4: vault remoto propio configura git remote (sin push)" {
    cat > "$SV/r.json" <<'EOF'
{"mcp":{"enabled":[],"disabled":[]},
 "vaults":{"domes":[{"name":"SaviaDomains","mode":"remote","remote_url":"git@example.com:org/vault.git","confidentiality":"N1"}]}}
EOF
    run env SAVIA_HOME_OVERRIDE="$SV" $SETUP --root "$SB" vaults --answers "$SV/r.json"
    [ "$status" -eq 0 ]
    git -C "$SB/vaults/SaviaDomains" remote get-url origin 2>/dev/null | grep -q 'git@example.com:org/vault.git'
}

@test "SE-372 AC-4b: vault remoto NO propio se rechaza (CRIT-001) salvo --allow-any-remote" {
    cat > "$SV/r.json" <<'EOF'
{"mcp":{"enabled":[],"disabled":[]},
 "vaults":{"domes":[{"name":"SaviaLabs","mode":"remote","remote_url":"https://thirdparty.io/data/vault.git","confidentiality":"N2"}]}}
EOF
    run env SAVIA_HOME_OVERRIDE="$SV" $SETUP --root "$SB" vaults --answers "$SV/r.json"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q 'RECHAZADO'
    git -C "$SB/vaults/SaviaLabs" remote get-url origin 2>/dev/null && return 1 || true
    # override explicito permite
    run env SAVIA_HOME_OVERRIDE="$SV" $SETUP --root "$SB" vaults --answers "$SV/r.json" --allow-any-remote
    echo "$output" | grep -vq 'RECHAZADO'
    git -C "$SB/vaults/SaviaLabs" remote get-url origin 2>/dev/null | grep -q 'thirdparty.io'
}

@test "SE-372 AC-6: --check tras aplicar reporta areas configuradas" {
    answers_min
    env SAVIA_HOME_OVERRIDE="$SV" $SETUP --root "$SB" --answers "$SV/a.json" >/dev/null
    run env SAVIA_HOME_OVERRIDE="$SV" $SETUP --root "$SB" --check
    echo "$output" | grep -q 'ollama'
    echo "$output" | grep -q 'savia-vaults'
}

@test "SE-372 AC-7: opencode.json sigue siendo JSON valido tras merge" {
    answers_min
    env SAVIA_HOME_OVERRIDE="$SV" $SETUP --root "$SB" --answers "$SV/a.json" >/dev/null
    python3 -c "import json; json.load(open('$SB/opencode.json')); print('json ok')"
}

@test "SE-372: answers invalido -> exit 2" {
    echo '{no-json' > "$SV/bad.json"
    run env SAVIA_HOME_OVERRIDE="$SV" $SETUP --root "$SB" --answers "$SV/bad.json"
    [ "$status" -eq 2 ]
}

@test "SE-372: federation enabled escribe .federation.json" {
    answers_min
    env SAVIA_HOME_OVERRIDE="$SV" $SETUP --root "$SB" --answers "$SV/a.json" >/dev/null
    [ -f "$SB/vaults/.federation.json" ]
    grep -q '"enabled": true' "$SB/vaults/.federation.json"
}
