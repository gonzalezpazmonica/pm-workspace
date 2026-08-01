#!/usr/bin/env bash
set -euo pipefail
# containment-run.sh — Execute command in proper containment level

level="${1:-}"
shift 2>/dev/null || true
cmd="$*"

if [[ -z "$level" || -z "$cmd" ]]; then
  echo "Usage: containment-run.sh <N-anfitrion|N-contenido|N-hostil> <command...>"
  exit 2
fi

case "$level" in
  N-anfitrion)
    exec bash -c "$cmd"
    ;;
  N-contenido|N-hostil)
    if ! command -v docker &>/dev/null || ! timeout 3 docker info >/dev/null 2>&1; then
      echo "ERROR: Docker not available. N-contenido/N-hostil execution disabled."
      echo "Install Docker or use N-anfitrion level for this command."
      exit 2
    fi

    local extra_opts=""
    if [[ "$level" == "N-hostil" ]]; then
      extra_opts="--read-only --tmpfs /tmp:noexec,nosuid,size=100M"
    fi

    docker run --rm \
      --cpus=1 --memory=512m --pids-limit=50 \
      --cap-drop=ALL --security-opt=no-new-privileges \
      --network=none \
      $extra_opts \
      -e SAVIA_CONTAINER_MODE=1 \
      -w /tmp/savia-work \
      savia-contained:latest \
      bash -c "$cmd"
    ;;
  *)
    echo "ERROR: Unknown level '$level'. Use N-anfitrion, N-contenido, or N-hostil."
    exit 2
    ;;
esac
