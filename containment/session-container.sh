#!/usr/bin/env bash
set -euo pipefail
# session-container.sh — Session-scoped container reuse for cost amortization
# Creates a persistent container per session that executes N commands before
# being destroyed. Avoids cold-start latency on every command.

SESSION_ID="${SAVIA_SESSION_ID:-$(hostname)-$$}"
CONTAINER_NAME="savia-session-${SESSION_ID}"
IMAGE="${SAVIA_CONTAINER_IMAGE:-savia-contained:latest}"
WORK_DIR="/tmp/savia-work"

cmd() {
  case "${1:-}" in
    start)
      start_session ;;
    run)
      shift; run_in_session "$@" ;;
    stop)
      stop_session ;;
    status)
      session_status ;;
    *)
      echo "Usage: session-container.sh {start|run|stop|status}"
      echo "  start  — Create and start persistent container"
      echo "  run    — Execute command in running container"
      echo "  stop   — Stop and remove container"
      echo "  status — Show container state"
      exit 2 ;;
  esac
}

start_session() {
  if docker ps -q -f "name=^${CONTAINER_NAME}$" 2>/dev/null | grep -q .; then
    echo "Session container '${CONTAINER_NAME}' already running."
    return 0
  fi

  echo "Starting session container '${CONTAINER_NAME}'..."
  docker run -d --rm \
    --name "$CONTAINER_NAME" \
    --cpus=1 --memory=512m --pids-limit=50 \
    --cap-drop=ALL --security-opt=no-new-privileges \
    --network=none \
    --read-only \
    --tmpfs "$WORK_DIR:noexec,nosuid,size=100M" \
    -e SAVIA_CONTAINER_MODE=1 \
    -w "$WORK_DIR" \
    "$IMAGE" \
    sleep infinity

  echo "Session container '${CONTAINER_NAME}' started."
}

run_in_session() {
  local cmd="$*"
  if [[ -z "$cmd" ]]; then
    echo "Usage: session-container.sh run <command...>"
    exit 2
  fi

  if ! docker ps -q -f "name=^${CONTAINER_NAME}$" 2>/dev/null | grep -q .; then
    echo "ERROR: Session container '${CONTAINER_NAME}' not running. Start it first."
    exit 1
  fi

  docker exec -i \
    -w "$WORK_DIR" \
    "$CONTAINER_NAME" \
    bash -c "$cmd"
}

stop_session() {
  if docker ps -q -f "name=^${CONTAINER_NAME}$" 2>/dev/null | grep -q .; then
    echo "Stopping session container '${CONTAINER_NAME}'..."
    docker stop -t 5 "$CONTAINER_NAME" >/dev/null 2>&1
  fi
}

session_status() {
  if ! command -v docker &>/dev/null; then
    echo "UNAVAILABLE: Docker not installed"
    exit 1
  fi
  if docker ps -q -f "name=^${CONTAINER_NAME}$" 2>/dev/null | grep -q .; then
    echo "ACTIVE: ${CONTAINER_NAME}"
    docker ps -f "name=^${CONTAINER_NAME}$" --format '  {{.Status}} | {{.Image}}'
    exit 0
  else
    echo "INACTIVE: ${CONTAINER_NAME}"
    exit 1
  fi
}

cmd "$@"
