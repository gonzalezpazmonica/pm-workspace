#!/usr/bin/env bash
# opencode-install.sh — SE-077 Slice 1
#
# Installs OpenCode v1.14.x in `~/.savia/opencode/` and links the savia-gates
# plugin. Idempotent: re-running upgrades the binary in place and refreshes
# the plugin symlink.
#
# Usage:
#   bash scripts/opencode-install.sh                  # install latest pinned
#   bash scripts/opencode-install.sh --version 1.14.25
#   bash scripts/opencode-install.sh --link-only      # skip download, just relink plugin
#   bash scripts/opencode-install.sh --dry-run
#   bash scripts/opencode-install.sh --uninstall      # remove ~/.savia/opencode
#
# Exit codes: 0 ok | 2 usage | 3 download/install error
#
# Reference: SE-077 (docs/propuestas/SE-077-opencode-replatform-v114.md)
# Reference: docs/rules/domain/opencode-savia-bridge.md
# Reference: docs/rules/domain/autonomous-safety.md

set -uo pipefail

ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
SAVIA_HOME="${SAVIA_HOME:-${HOME}/.savia}"
OPENCODE_DIR="${SAVIA_HOME}/opencode"
PLUGIN_SRC="${ROOT}/scripts/opencode-plugin/savia-gates"
PLUGIN_DST="${OPENCODE_DIR}/plugins/savia-gates"
DEFAULT_VERSION="1.14.25"
VERSION="${OPENCODE_VERSION:-${DEFAULT_VERSION}}"
DRY_RUN=0
LINK_ONLY=0
UNINSTALL=0

usage() {
  cat <<USG
Usage: opencode-install.sh [--version X.Y.Z] [--link-only] [--dry-run] [--uninstall]

Env:
  SAVIA_HOME          default ${HOME}/.savia
  OPENCODE_VERSION    default ${DEFAULT_VERSION}
USG
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)    VERSION="${2:?}"; shift 2 ;;
    --dry-run)    DRY_RUN=1; shift ;;
    --link-only)  LINK_ONLY=1; shift ;;
    --uninstall)  UNINSTALL=1; shift ;;
    --help|-h)    usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage >&2; exit 2 ;;
  esac
done

die() { echo "ERROR: $*" >&2; exit "${2:-3}"; }

run() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "DRY-RUN: $*"
  else
    "$@"
  fi
}

if [[ "$UNINSTALL" -eq 1 ]]; then
  if [[ -d "${OPENCODE_DIR}" ]]; then
    run rm -rf "${OPENCODE_DIR}"
    echo "uninstalled: ${OPENCODE_DIR}"
  else
    echo "nothing to uninstall: ${OPENCODE_DIR} not present"
  fi
  exit 0
fi

# Plugin source must exist in the repo
[[ -d "${PLUGIN_SRC}" ]] || die "plugin source not found: ${PLUGIN_SRC}"

# Step 1: ensure the directory tree
run mkdir -p "${OPENCODE_DIR}/bin" "${OPENCODE_DIR}/plugins"

# Step 2: download OpenCode binary unless link-only mode
if [[ "$LINK_ONLY" -ne 1 ]]; then
  if command -v curl >/dev/null 2>&1; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "DRY-RUN: would download opencode v${VERSION} via official installer"
    else
      # Official installer pattern (mirrors https://opencode.ai/install). The
      # installer pins SAVIA_HOME by setting OPENCODE_INSTALL_DIR. If the
      # network is unreachable we fail soft and let the user retry.
      if ! OPENCODE_INSTALL_DIR="${OPENCODE_DIR}/bin" \
           OPENCODE_VERSION="${VERSION}" \
           curl -fsSL https://opencode.ai/install 2>/dev/null | bash >/dev/null 2>&1; then
        echo "WARN: official installer unavailable — falling back to npm" >&2
        if command -v npm >/dev/null 2>&1; then
          run npm install --prefix "${OPENCODE_DIR}" "opencode@${VERSION}" >/dev/null 2>&1 \
            || die "npm install opencode@${VERSION} failed" 3
          run ln -sf "${OPENCODE_DIR}/node_modules/.bin/opencode" "${OPENCODE_DIR}/bin/opencode"
        else
          die "neither curl-installer nor npm could install opencode (run --link-only after manual install)" 3
        fi
      fi
    fi
  else
    die "curl not available — install opencode manually then re-run with --link-only" 3
  fi
fi

# Step 3: link the plugin into the OpenCode plugins dir
run mkdir -p "${OPENCODE_DIR}/plugins"
if [[ "$DRY_RUN" -ne 1 ]]; then
  rm -rf "${PLUGIN_DST}"
  ln -s "${PLUGIN_SRC}" "${PLUGIN_DST}"
fi

# Step 4: register opencode.json so OpenCode picks the plugin up automatically
OC_CONFIG="${OPENCODE_DIR}/opencode.json"
if [[ "$DRY_RUN" -ne 1 ]]; then
  cat > "${OC_CONFIG}" <<EOF
{
  "\$schema": "https://opencode.ai/config.json",
  "plugin": ["savia-gates"]
}
EOF
fi

# Step 5: stamp version
if [[ "$DRY_RUN" -ne 1 ]]; then
  echo "${VERSION}" > "${OPENCODE_DIR}/.installed-version"
fi

cat <<DONE
opencode installed:
  binary  : ${OPENCODE_DIR}/bin/opencode
  plugin  : ${PLUGIN_DST} -> ${PLUGIN_SRC}
  config  : ${OC_CONFIG}
  version : ${VERSION}

next:
  ${OPENCODE_DIR}/bin/opencode --version
  cd ${ROOT} && ${OPENCODE_DIR}/bin/opencode "explica el contenido de docs/ROADMAP.md"
DONE
