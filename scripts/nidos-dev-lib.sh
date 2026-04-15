#!/usr/bin/env bash
# nidos-dev-lib.sh — Dev server lifecycle for Savia nidos (SPEC-098).
# Sourced by scripts/nidos.sh. Provides: detect / start / stop / url / logs.
#
# Per-nido state in $NIDOS_DIR/<name>/.dev-server/:
#   pid        — process ID of the dev server
#   port       — port it's listening on
#   command    — the command used to launch
#   log        — stdout/stderr of the dev server
#
# Language packs (config via CLAUDE.md overrides these defaults):
#   Angular             npm run start         4200
#   React Vite          npm run dev           5173
#   React Next          npm run dev           3000
#   TypeScript/Node     npm run dev           3000
#   Python FastAPI      uvicorn main:app      8000
#   Python Django       python manage.py      8000
#   Java Spring         ./mvnw spring-boot    8080
#   Go                  go run .              8080
#   Rust Axum           cargo run             3000
#   .NET                dotnet watch run      5000
#   PHP Laravel         php artisan serve     8000
#   Ruby Rails          bin/rails server      3000

set -uo pipefail

# Timeout for ready signal detection (seconds)
DEV_READY_TIMEOUT="${NIDOS_DEV_READY_TIMEOUT:-30}"
# Log rotation threshold
DEV_LOG_MAX_BYTES="${NIDOS_DEV_LOG_MAX_BYTES:-$((10 * 1024 * 1024))}"

# ── Detect project type from files present in the nido ─────────────────────
# Prints: "<command>|<port>|<ready_signal_regex>"
dev_detect_project() {
  local nido_path="$1"
  [[ ! -d "$nido_path" ]] && return 1

  # Read override from CLAUDE.md if present (simple YAML-ish parser)
  if [[ -f "$nido_path/CLAUDE.md" ]]; then
    local cmd port signal
    cmd=$(awk '/^DEV_SERVER_COMMAND[[:space:]]*=/{gsub(/^.*=[[:space:]]*/,""); gsub(/"/,""); print; exit}' "$nido_path/CLAUDE.md")
    port=$(awk '/^DEV_SERVER_PORT[[:space:]]*=/{gsub(/^.*=[[:space:]]*/,""); gsub(/"/,""); print; exit}' "$nido_path/CLAUDE.md")
    signal=$(awk '/^DEV_SERVER_READY[[:space:]]*=/{gsub(/^.*=[[:space:]]*/,""); gsub(/"/,""); print; exit}' "$nido_path/CLAUDE.md")
    if [[ -n "$cmd" && -n "$port" ]]; then
      echo "${cmd}|${port}|${signal:-listening|running|ready}"
      return 0
    fi
  fi

  # Detect by file signatures
  if [[ -f "$nido_path/angular.json" ]]; then
    echo "npm run start|4200|Local:|compiled successfully"
  elif [[ -f "$nido_path/next.config.js" || -f "$nido_path/next.config.mjs" || -f "$nido_path/next.config.ts" ]]; then
    echo "npm run dev|3000|Ready|started server"
  elif [[ -f "$nido_path/vite.config.js" || -f "$nido_path/vite.config.ts" ]]; then
    echo "npm run dev|5173|Local:|ready in"
  elif [[ -f "$nido_path/package.json" ]]; then
    echo "npm run dev|3000|listening|started|ready"
  elif [[ -f "$nido_path/pyproject.toml" ]] && grep -qi fastapi "$nido_path/pyproject.toml" 2>/dev/null; then
    echo "uvicorn main:app --reload|8000|Application startup complete|Uvicorn running"
  elif [[ -f "$nido_path/manage.py" ]]; then
    echo "python manage.py runserver|8000|Starting development server|Quit the server"
  elif [[ -f "$nido_path/pyproject.toml" || -f "$nido_path/requirements.txt" ]]; then
    echo "uvicorn main:app --reload|8000|Uvicorn running"
  elif [[ -f "$nido_path/pom.xml" ]] || [[ -f "$nido_path/build.gradle" ]]; then
    echo "./mvnw spring-boot:run|8080|Started|Tomcat started"
  elif [[ -f "$nido_path/go.mod" ]]; then
    echo "go run .|8080|listening|Server started"
  elif [[ -f "$nido_path/Cargo.toml" ]]; then
    echo "cargo run|3000|listening|started"
  elif ls "$nido_path"/*.csproj >/dev/null 2>&1 || [[ -f "$nido_path/Program.cs" ]]; then
    echo "dotnet watch run|5000|Now listening|Application started"
  elif [[ -f "$nido_path/artisan" ]]; then
    echo "php artisan serve|8000|Server running|Laravel"
  elif [[ -f "$nido_path/Gemfile" ]] && grep -qi rails "$nido_path/Gemfile" 2>/dev/null; then
    echo "bin/rails server|3000|Listening|Booting"
  else
    return 1
  fi
}

# ── Resolve port avoiding conflicts ─────────────────────────────────────────
dev_resolve_port() {
  local desired_port="$1"
  local port="$desired_port"
  local max_attempts=20

  for _ in $(seq 1 "$max_attempts"); do
    if ! (echo >"/dev/tcp/127.0.0.1/$port") 2>/dev/null; then
      # Port is free
      echo "$port"
      return 0
    fi
    port=$((port + 1))
  done
  return 1
}

# ── Start dev server in background ──────────────────────────────────────────
dev_start() {
  local nido_path="$1"
  [[ ! -d "$nido_path" ]] && { echo "ERROR: nido path not found: $nido_path" >&2; return 1; }

  local state_dir="$nido_path/.dev-server"
  mkdir -p "$state_dir"

  # Already running?
  if [[ -f "$state_dir/pid" ]]; then
    local existing_pid
    existing_pid=$(cat "$state_dir/pid" 2>/dev/null)
    if [[ -n "$existing_pid" ]] && kill -0 "$existing_pid" 2>/dev/null; then
      echo "Dev server already running (PID $existing_pid). Use: dev stop"
      return 0
    fi
    rm -f "$state_dir/pid"  # stale
  fi

  # Detect project
  local detected
  detected=$(dev_detect_project "$nido_path")
  if [[ -z "$detected" ]]; then
    echo "ERROR: could not detect project type in $nido_path" >&2
    echo "       Add DEV_SERVER_COMMAND/PORT/READY to CLAUDE.md or use a supported language pack." >&2
    return 1
  fi

  local cmd port signal
  IFS='|' read -r cmd port signal <<< "$detected"

  # Resolve port (avoid conflicts)
  local actual_port
  actual_port=$(dev_resolve_port "$port") || {
    echo "ERROR: no free port found near $port" >&2
    return 1
  }

  local log="$state_dir/log"
  # Rotate if large
  if [[ -f "$log" ]] && [[ "$(wc -c < "$log" 2>/dev/null || echo 0)" -gt "$DEV_LOG_MAX_BYTES" ]]; then
    mv "$log" "${log}.old"
  fi

  echo "Starting: $cmd (port=$actual_port)"
  # Export port for commands that respect env vars (uvicorn, npm etc.)
  (
    cd "$nido_path" || exit 1
    export PORT="$actual_port"
    nohup bash -c "$cmd" > "$log" 2>&1 &
    echo $! > "$state_dir/pid"
    echo "$actual_port" > "$state_dir/port"
    echo "$cmd" > "$state_dir/command"
  )

  # Wait for ready signal (or timeout)
  local elapsed=0
  local pid
  pid=$(cat "$state_dir/pid" 2>/dev/null)
  while [[ $elapsed -lt $DEV_READY_TIMEOUT ]]; do
    if [[ -n "$signal" ]] && grep -qiE "$signal" "$log" 2>/dev/null; then
      echo "Ready: http://localhost:$actual_port (PID $pid)"
      return 0
    fi
    if ! kill -0 "$pid" 2>/dev/null; then
      echo "ERROR: dev server died during startup. See log: $log" >&2
      rm -f "$state_dir/pid"
      return 1
    fi
    sleep 1
    elapsed=$((elapsed + 1))
  done

  echo "WARN: ready signal not detected in ${DEV_READY_TIMEOUT}s. Server may still be starting."
  echo "URL: http://localhost:$actual_port  (PID $pid)"
  echo "Log: $log"
  return 0
}

# ── Stop dev server cleanly ────────────────────────────────────────────────
dev_stop() {
  local nido_path="$1"
  local state_dir="$nido_path/.dev-server"
  [[ ! -f "$state_dir/pid" ]] && { echo "No dev server registered for this nido."; return 0; }

  local pid
  pid=$(cat "$state_dir/pid" 2>/dev/null)
  if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null || true
    sleep 1
    # Force-kill if still alive
    kill -0 "$pid" 2>/dev/null && kill -9 "$pid" 2>/dev/null
    echo "Stopped PID $pid"
  else
    echo "PID $pid not running (already dead)."
  fi
  rm -f "$state_dir/pid" "$state_dir/port" "$state_dir/command"
}

# ── Print URL if server running ────────────────────────────────────────────
dev_url() {
  local nido_path="$1"
  local state_dir="$nido_path/.dev-server"
  [[ ! -f "$state_dir/pid" ]] && { echo "No dev server running." >&2; return 1; }

  local pid port
  pid=$(cat "$state_dir/pid" 2>/dev/null)
  port=$(cat "$state_dir/port" 2>/dev/null)

  if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null && [[ -n "$port" ]]; then
    echo "http://localhost:$port"
  else
    echo "Stale state. Dev server not running." >&2
    rm -f "$state_dir/pid" "$state_dir/port" "$state_dir/command"
    return 1
  fi
}

# ── Tail log ────────────────────────────────────────────────────────────────
dev_logs() {
  local nido_path="$1"
  local log="$nido_path/.dev-server/log"
  [[ ! -f "$log" ]] && { echo "No dev server log found." >&2; return 1; }
  tail -f "$log"
}

# ── Dispatcher: called from nidos.sh as `nidos.sh dev <name> <subcmd>` ─────
dev_dispatch() {
  local name="${1:-}" subcmd="${2:-}"
  [[ -z "$name" || -z "$subcmd" ]] && {
    echo "Usage: nidos.sh dev <name> {start|stop|url|logs}" >&2
    return 2
  }
  local nido_path="$NIDOS_DIR/$name"
  [[ ! -d "$nido_path" ]] && { echo "ERROR: nido '$name' not found" >&2; return 1; }

  case "$subcmd" in
    start) dev_start "$nido_path" ;;
    stop)  dev_stop "$nido_path" ;;
    url)   dev_url "$nido_path" ;;
    logs)  dev_logs "$nido_path" ;;
    *)     echo "Unknown subcommand: $subcmd" >&2; return 2 ;;
  esac
}
