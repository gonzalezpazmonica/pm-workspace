#!/usr/bin/env bash
set -euo pipefail
# containment-run.sh — Execute command in proper containment level
# SE-292 S2+S3+S7: Container execution with credential isolation + fail-closed

level="${1:-}"
shift 2>/dev/null || true
cmd="$*"

if [[ -z "$level" || -z "$cmd" ]]; then
  echo "Usage: containment-run.sh <N-anfitrion|N-contenido|N-hostil> <command...>" >&2
  exit 2
fi

fail_closed() {
  local reason="$1"
  echo "BLOCKED [containment-fail-closed]: ${reason}" >&2
  echo "  Level: ${level}" >&2
  echo "  Fix: docker build -t savia-contained:latest containment/" >&2
  exit 2
}

case "$level" in
  N-anfitrion)
    exec bash -c "$cmd"
    ;;

  N-contenido|N-hostil)
    if ! command -v docker &>/dev/null; then
      fail_closed "Docker not installed"
    fi
    if ! timeout 3 docker info >/dev/null 2>&1; then
      fail_closed "Docker daemon not responding"
    fi

    IMAGE="${SAVIA_CONTAINER_IMAGE:-savia-contained:latest}"
    if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
      fail_closed "Image not built"
    fi

    EXTRA_OPTS=""
    if [[ "$level" == "N-hostil" ]]; then
      EXTRA_OPTS="--read-only --tmpfs /tmp:noexec,nosuid,size=100M"
    fi

    docker run --rm \
      --cpus=1 --memory=512m --pids-limit=50 \
      --cap-drop=ALL --security-opt=no-new-privileges \
      --network=none \
      $EXTRA_OPTS \
      -e SAVIA_CONTAINER_MODE=1 \
      -w /tmp/savia-work \
      "$IMAGE" \
      bash -c "$cmd"
    ;;

  *)
    echo "ERROR: Unknown level '${level}'" >&2
    exit 2
    ;;
esac
