#!/usr/bin/env bats
# Ref: .claude/skills/sovereignty-auditor/SKILL.md (D2: independencia LLM)
# Ref: docs/EMERGENCY.md — emergency-setup.sh y emergency-status.sh
# Ref: docs/savia-dual.md — Ollama >= 0.20.0 sirve /v1/messages nativo
#
# D2 del Sovereignty Score depende de que el modo emergencia funcione de
# verdad. Estos tests ejercitan emergency-setup.sh y emergency-status.sh con
# stubs de curl/ollama/uname en PATH y un HOME temporal: nunca tocan el
# Ollama real, la red ni la configuracion de la operadora.

SCRIPT="scripts/emergency-setup.sh"
STATUS="scripts/emergency-status.sh"

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  TMP="$(mktemp -d)"
  export HOME="$TMP/home"
  mkdir -p "$HOME" "$TMP/bin"
  export STUB_DIR="$TMP"
  : > "$TMP/models"
  : > "$TMP/pulls"
  export STUB_NET=1 STUB_SERVER=1 STUB_OLLAMA_VERSION="0.20.3"
  # 16 GB comerciales: MemTotal real ~15.6 GiB
  printf 'MemTotal:       16314560 kB\nMemAvailable:    8000000 kB\n' > "$TMP/meminfo"
  export EMERGENCY_MEMINFO="$TMP/meminfo"

  cat > "$TMP/bin/curl" <<'EOF'
#!/usr/bin/env bash
for a in "$@"; do
  case "$a" in
    *localhost:11434*) [[ "$STUB_SERVER" == 1 ]] && exit 0 || exit 7 ;;
  esac
done
[[ "$STUB_NET" == 1 ]] && exit 0 || exit 6
EOF
  cat > "$TMP/bin/ollama" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  --version) echo "ollama version is $STUB_OLLAMA_VERSION" ;;
  list) echo "NAME ID SIZE MODIFIED"; while read -r m; do [[ -n "$m" ]] && echo "$m abc 4.7 GB 1 day ago"; done < "$STUB_DIR/models" ;;
  pull) echo "$2" >> "$STUB_DIR/pulls"; echo "$2" >> "$STUB_DIR/models" ;;
  serve) exit 0 ;;
esac
EOF
  cat > "$TMP/bin/uname" <<'EOF'
#!/usr/bin/env bash
case "$1" in -s) echo Linux ;; -m) echo x86_64 ;; *) echo Linux ;; esac
EOF
  chmod +x "$TMP/bin/"*
  export PATH="$TMP/bin:$PATH"
  unset PM_EMERGENCY_MODE ANTHROPIC_BASE_URL ANTHROPIC_AUTH_TOKEN
}

teardown() {
  rm -rf "$TMP"
}

envfile() { echo "$HOME/.pm-workspace-emergency.env"; }

# ── Estructura ──────────────────────────────────────────────────────────────

@test "ambos scripts declaran set -euo pipefail" {
  head -5 "$REPO_ROOT/$SCRIPT" | grep -q "set -euo pipefail"
  head -5 "$REPO_ROOT/$STATUS" | grep -q "set -euo pipefail"
}

# ── emergency-setup.sh ──────────────────────────────────────────────────────

@test "setup: base URL sin /v1 final (Claude Code pide /v1/messages)" {
  run bash "$REPO_ROOT/$SCRIPT"
  [ "$status" -eq 0 ]
  grep -q '^export ANTHROPIC_BASE_URL="http://localhost:11434"$' "$(envfile)"
  ! grep -q 'ANTHROPIC_BASE_URL=.*/v1' "$(envfile)"
}

@test "setup: credencial placeholder para no enviar la real a localhost" {
  run bash "$REPO_ROOT/$SCRIPT"
  [ "$status" -eq 0 ]
  grep -q '^export ANTHROPIC_AUTH_TOKEN="ollama"$' "$(envfile)"
  grep -q '^export ANTHROPIC_API_KEY=""$' "$(envfile)"
}

@test "setup: no persiste nada en ficheros de shell (emergencia transitoria)" {
  touch "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"
  run bash "$REPO_ROOT/$SCRIPT"
  [ "$status" -eq 0 ]
  [ ! -s "$HOME/.bashrc" ] && [ ! -s "$HOME/.zshrc" ] && [ ! -s "$HOME/.profile" ]
}

@test "setup: boundary 16 GB comerciales (15.6 GiB) usa el tramo de 16 GB" {
  run bash "$REPO_ROOT/$SCRIPT"
  [ "$status" -eq 0 ]
  grep -q 'ANTHROPIC_DEFAULT_OPUS_MODEL="qwen2.5:7b"' "$(envfile)"
  grep -q 'PM_EMERGENCY_MODEL="qwen2.5:7b"' "$(envfile)"
}

@test "setup: boundary 8 GB comerciales usa qwen2.5:3b como modelo por defecto" {
  printf 'MemTotal:        8030000 kB\n' > "$EMERGENCY_MEMINFO"
  run bash "$REPO_ROOT/$SCRIPT"
  [ "$status" -eq 0 ]
  grep -q 'PM_EMERGENCY_MODEL="qwen2.5:3b"' "$(envfile)"
}

@test "setup: descarga todos los modelos a los que apuntan los alias" {
  run bash "$REPO_ROOT/$SCRIPT"
  [ "$status" -eq 0 ]
  grep -qx 'qwen2.5:7b' "$TMP/pulls"
  grep -qx 'qwen2.5:3b' "$TMP/pulls"
}

@test "setup: --model fija un unico modelo para todos los alias" {
  run bash "$REPO_ROOT/$SCRIPT" --model qwen2.5:3b
  [ "$status" -eq 0 ]
  [ "$(grep -c 'qwen2.5:3b' "$(envfile)")" -eq 5 ]
  [ "$(sort -u "$TMP/pulls")" = "qwen2.5:3b" ]
}

@test "setup: modelo ya presente no se re-descarga (match exacto, no regex)" {
  echo "qwen2.5:7b-instruct" > "$TMP/models"
  echo "qwen2.5:3b" >> "$TMP/models"
  run bash "$REPO_ROOT/$SCRIPT"
  [ "$status" -eq 0 ]
  grep -qx 'qwen2.5:7b' "$TMP/pulls"
  ! grep -qx 'qwen2.5:3b' "$TMP/pulls"
}

@test "setup: fail offline sin modelos cacheados — exit 1 y sin fichero env" {
  export STUB_NET=0
  mkdir -p "$HOME/.pm-workspace-emergency"
  touch "$HOME/.pm-workspace-emergency/.plan-executed"
  run bash "$REPO_ROOT/$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" != *"Setup completado"* ]]
  [ ! -f "$(envfile)" ]
}

@test "setup: offline con un modelo cacheado lo usa para todos los alias" {
  export STUB_NET=0
  mkdir -p "$HOME/.pm-workspace-emergency"
  touch "$HOME/.pm-workspace-emergency/.plan-executed"
  echo "qwen2.5:3b" > "$TMP/models"
  run bash "$REPO_ROOT/$SCRIPT"
  [ "$status" -eq 0 ]
  [ ! -s "$TMP/pulls" ]
  ! grep -q 'qwen2.5:7b' "$(envfile)"
}

@test "setup: reject Ollama < 0.20.0 (sin endpoint /v1/messages)" {
  export STUB_OLLAMA_VERSION="0.19.9"
  run bash "$REPO_ROOT/$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"0.20.0"* ]]
  [ ! -f "$(envfile)" ]
}

@test "setup: error si --model llega vacio (sin valor)" {
  run bash "$REPO_ROOT/$SCRIPT" --model
  [ "$status" -eq 2 ]
  [[ "$output" == *"--model"* ]]
}

@test "setup: invalid argumento desconocido se rechaza con exit 2" {
  run bash "$REPO_ROOT/$SCRIPT" --modle qwen2.5:3b
  [ "$status" -eq 2 ]
  [ ! -f "$(envfile)" ]
}

# ── emergency-status.sh ─────────────────────────────────────────────────────

ready_env() {
  printf 'qwen2.5:7b\nqwen2.5:3b\n' > "$TMP/models"
  cat > "$(envfile)" <<'EOF'
export ANTHROPIC_BASE_URL="http://localhost:11434"
export ANTHROPIC_AUTH_TOKEN="ollama"
export ANTHROPIC_API_KEY=""
export PM_EMERGENCY_MODEL="qwen2.5:7b"
export PM_EMERGENCY_MODE="active"
export ANTHROPIC_DEFAULT_OPUS_MODEL="qwen2.5:7b"
export ANTHROPIC_DEFAULT_SONNET_MODEL="qwen2.5:7b"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="qwen2.5:3b"
export CLAUDE_CODE_SUBAGENT_MODEL="qwen2.5:7b"
EOF
}

@test "status: todo preparado → listo y exit 0" {
  ready_env
  run bash "$REPO_ROOT/$STATUS"
  [ "$status" -eq 0 ]
  [[ "$output" == *"listo"* ]]
}

@test "status: fail sin servidor → exit 1 y nunca dice listo" {
  ready_env
  export STUB_SERVER=0
  run bash "$REPO_ROOT/$STATUS"
  [ "$status" -eq 1 ]
  [[ "$output" != *"listo"* ]]
}

@test "status: fail si falta un modelo al que apunta un alias" {
  ready_env
  echo "qwen2.5:7b" > "$TMP/models"
  run bash "$REPO_ROOT/$STATUS"
  [ "$status" -eq 1 ]
  [[ "$output" == *"qwen2.5:3b"* ]]
}

@test "status: fail sin fichero env (setup nunca ejecutado)" {
  printf 'qwen2.5:7b\n' > "$TMP/models"
  run bash "$REPO_ROOT/$STATUS"
  [ "$status" -eq 1 ]
  [[ "$output" == *"emergency-setup.sh"* ]]
}

@test "status: reject Ollama < 0.20.0" {
  ready_env
  export STUB_OLLAMA_VERSION="0.12.1"
  run bash "$REPO_ROOT/$STATUS"
  [ "$status" -eq 1 ]
  [[ "$output" == *"0.20.0"* ]]
}

@test "status: invalid base URL con /v1 final en modo activo (pediria /v1/v1/messages)" {
  ready_env
  export PM_EMERGENCY_MODE=active ANTHROPIC_BASE_URL="http://localhost:11434/v1" ANTHROPIC_AUTH_TOKEN=ollama
  run bash "$REPO_ROOT/$STATUS"
  [ "$status" -eq 1 ]
  [[ "$output" == *"/v1/v1/messages"* ]]
}

@test "status: modo activo sin ANTHROPIC_AUTH_TOKEN es un problema" {
  ready_env
  export PM_EMERGENCY_MODE=active ANTHROPIC_BASE_URL="http://localhost:11434"
  run bash "$REPO_ROOT/$STATUS"
  [ "$status" -eq 1 ]
  [[ "$output" == *"ANTHROPIC_AUTH_TOKEN"* ]]
}

@test "status: empty meminfo (macOS sin /proc) no rompe el script" {
  ready_env
  export EMERGENCY_MEMINFO="$TMP/no-existe"
  run bash "$REPO_ROOT/$STATUS"
  [ "$status" -eq 0 ]
  [[ "$output" == *"listo"* ]]
}

@test "status: null — sin Ollama instalado → exit 1" {
  ready_env
  mv "$TMP/bin/ollama" "$TMP/ollama.off"
  PATH="$TMP/bin:/usr/bin:/bin" run bash "$REPO_ROOT/$STATUS"
  [ "$status" -eq 1 ]
  [[ "$output" == *"NO instalado"* ]]
}
