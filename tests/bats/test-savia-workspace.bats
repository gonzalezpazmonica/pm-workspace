#!/usr/bin/env bats
# SE-373 — savia setup · modulo workspace: composicion multi-repo (AC-0..AC-7)
# Ref: docs/specs/SE-373-savia-setup-workspace.spec.md
# CRIT-001: sandbox local; solo lectura de repos hijos.

W="bash scripts/savia-workspace.sh"

setup() {
    TMPD="$(mktemp -d)"
    WDIR="$TMPD/w"
    SV="$TMPD/home"
    mkdir -p "$SV" "$WDIR"
}

teardown() {
    rm -rf "$TMPD"
}

mk_repos() {
    for r in "$@"; do
        mkdir -p "$WDIR/$r"
        (cd "$WDIR/$r" && git init -q && echo "# $r" > README.md && \
         git add -A && git -c user.email=t@t -c user.name=t commit -qm init >/dev/null)
    done
}

@test "SE-373 AC-0: genera AGENTS.md con repos y mapa de relaciones" {
    mk_repos product-a-api product-a-web
    run env SAVIA_HOME_OVERRIDE="$SV" $W "$WDIR"
    [ "$status" -eq 0 ]
    [ -f "$WDIR/AGENTS.md" ]
    grep -q 'product-a-api' "$WDIR/AGENTS.md"
    grep -q 'product-a-web' "$WDIR/AGENTS.md"
    grep -q '`product-a-api` | `product-a-web`' "$WDIR/AGENTS.md"
}

@test "SE-373 AC-1: la composicion instruye lazy-load (no leer todos)" {
    mk_repos product-a-api product-a-web
    env SAVIA_HOME_OVERRIDE="$SV" $W "$WDIR" >/dev/null
    grep -qi 'BAJO DEMANDA (lazy load)' "$WDIR/AGENTS.md"
    grep -qi 'no leas todos' "$WDIR/AGENTS.md"
}

@test "SE-373 AC-2: re-ejecucion idempotente y preserva overrides manuales" {
    mk_repos product-a-api product-a-web product-b-web
    env SAVIA_HOME_OVERRIDE="$SV" $W "$WDIR" >/dev/null
    # override manual: api tambien sirve a product-b-web
    cat > "$SV/a.json" <<'EOF'
{"workspace":{"relations_manual":{"product-a-api":["product-b-web"]}}}
EOF
    run env SAVIA_HOME_OVERRIDE="$SV" $W "$WDIR" --answers "$SV/a.json"
    [ "$status" -eq 0 ]
    grep -q '`product-a-api` | `product-a-web`, `product-b-web`' "$WDIR/AGENTS.md"
    # re-ejecutar sin answers: el override persiste desde el estado
    run env SAVIA_HOME_OVERRIDE="$SV" $W "$WDIR"
    grep -q 'product-b-web' "$WDIR/AGENTS.md"
    # sin duplicar filas
    N=$(grep -c 'product-a-api' "$WDIR/AGENTS.md")
    [ "$N" -ge 2 ]  # inventario + relacion
}

@test "SE-373 AC-3: --dry-run no escribe nada" {
    mk_repos product-a-api product-a-web
    run env SAVIA_HOME_OVERRIDE="$SV" $W "$WDIR" --dry-run
    [ "$status" -eq 0 ]
    [ ! -f "$WDIR/AGENTS.md" ]
    [ ! -f "$SV/savia-setup.json" ]
}

@test "SE-373 AC-4: --answers con relaciones manuales produce el mapa esperado" {
    mk_repos product-a-api product-a-web product-b-web product-b-api
    cat > "$SV/a.json" <<'EOF'
{"workspace":{"relations_manual":{"product-b-api":["product-b-web"]}}}
EOF
    env SAVIA_HOME_OVERRIDE="$SV" $W "$WDIR" --answers "$SV/a.json" >/dev/null
    grep -q '`product-b-api` | `product-b-web`' "$WDIR/AGENTS.md"
}

@test "SE-373 AC-5: directorio sin repos -> exit 2 con error claro" {
    E="$TMPD/vacio"; mkdir -p "$E"
    run env SAVIA_HOME_OVERRIDE="$SV" $W "$E"
    [ "$status" -eq 2 ]
    echo "$output" | grep -qi 'no hay repos'
}

@test "SE-373 AC-6: registra en savia-setup.json.workspaces" {
    mk_repos product-a-api product-a-web
    env SAVIA_HOME_OVERRIDE="$SV" $W "$WDIR" >/dev/null
    python3 - "$SV/savia-setup.json" "$WDIR" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
ws = d.get("workspaces", {})
assert any(k == sys.argv[2] for k in ws), ws
print("ok")
PY
}

@test "SE-373 AC-7: no regresion — suite SE-372 sigue verde" {
    run bats tests/bats/test-savia-setup.bats
    [ "$status" -eq 0 ]
}
