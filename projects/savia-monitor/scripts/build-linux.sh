#!/usr/bin/env bash
# build-linux.sh — Build Savia Monitor para Linux
# Genera .deb, .rpm y .AppImage en target/release/bundle/
#
# Uso: bash projects/savia-monitor/scripts/build-linux.sh [opciones]
#
# Opciones:
#   --dev        Build de desarrollo (sin --release)
#   --deb-only   Solo generar .deb
#   --appimage-only   Solo generar .AppImage
#   --check      Solo verificar entorno, no compila
#   --help       Mostrar esta ayuda
#
# Prerequisitos (Debian/Ubuntu):
#   sudo apt install libwebkit2gtk-4.1-dev libgtk-3-dev libayatana-appindicator3-dev \
#                    librsvg2-dev build-essential curl wget file libssl-dev libxdo-dev
#   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
#   cargo install tauri-cli --version "^2.0"
#
# Prerequisitos (Fedora/RHEL):
#   sudo dnf install webkit2gtk4.1-devel openssl-devel curl wget file libappindicator-gtk3-devel \
#                    librsvg2-devel gtk3-devel
#
# Exit: 0 success, 1 error, 2 missing prerequisites

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

MODE="release"
BUNDLE_FILTER=""
CHECK_ONLY=false

show_help() {
  sed -n '2,22p' "$0" | sed 's/^# \?//'
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dev) MODE="dev"; shift ;;
      --deb-only) BUNDLE_FILTER="--bundles deb"; shift ;;
      --appimage-only) BUNDLE_FILTER="--bundles appimage"; shift ;;
      --rpm-only) BUNDLE_FILTER="--bundles rpm"; shift ;;
      --check) CHECK_ONLY=true; shift ;;
      --help|-h) show_help; exit 0 ;;
      *) echo "Error: unknown option $1" >&2; exit 2 ;;
    esac
  done
}

check_os() {
  if [[ "$(uname -s)" != "Linux" ]]; then
    echo "Error: este script solo funciona en Linux (detectado: $(uname -s))" >&2
    exit 2
  fi
}

check_rust() {
  if ! command -v cargo >/dev/null 2>&1; then
    echo "Error: Rust no instalado. Instala con:" >&2
    echo "  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh" >&2
    exit 2
  fi
  echo "  Rust: $(rustc --version 2>/dev/null || echo 'unknown')"
}

check_tauri_cli() {
  if ! command -v cargo-tauri >/dev/null 2>&1 && ! cargo tauri --version >/dev/null 2>&1; then
    echo "Warning: tauri-cli no instalado. Instala con:" >&2
    echo "  cargo install tauri-cli --version '^2.0'" >&2
    return 1
  fi
  return 0
}

check_node() {
  if ! command -v npm >/dev/null 2>&1; then
    echo "Error: npm no instalado (necesario para frontend)" >&2
    exit 2
  fi
  echo "  Node: $(node --version 2>/dev/null || echo 'unknown')"
}

check_system_deps() {
  local missing=()
  # Debian/Ubuntu packages
  if command -v dpkg >/dev/null 2>&1; then
    for pkg in libwebkit2gtk-4.1-dev libgtk-3-dev librsvg2-dev; do
      if ! dpkg -l "$pkg" >/dev/null 2>&1; then
        missing+=("$pkg")
      fi
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
      echo "Warning: faltan paquetes del sistema:" >&2
      printf '  - %s\n' "${missing[@]}" >&2
      echo "Instala con: sudo apt install ${missing[*]}" >&2
      return 1
    fi
  fi
  return 0
}

run_checks() {
  echo "== Verificando entorno =="
  check_os
  check_rust
  check_node
  check_system_deps || true
  check_tauri_cli || true
  echo ""
}

build_frontend() {
  echo "== Building frontend (Vue 3) =="
  cd "$PROJECT_DIR"
  npm install --silent
  npm run build
  echo ""
}

build_tauri() {
  echo "== Building Tauri bundle ($MODE) =="
  cd "$PROJECT_DIR"

  local flags=""
  [[ "$MODE" == "release" ]] && flags="$flags"
  [[ -n "$BUNDLE_FILTER" ]] && flags="$flags $BUNDLE_FILTER"

  # Prefer CARGO_TARGET_DIR outside OneDrive (as per CLAUDE.md convention)
  export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-$HOME/.savia/cargo-target/savia-monitor}"
  mkdir -p "$CARGO_TARGET_DIR"

  if command -v cargo-tauri >/dev/null 2>&1; then
    cargo tauri build $flags
  else
    cargo tauri build $flags || {
      echo "Error: tauri-cli no disponible. Instala con: cargo install tauri-cli --version '^2.0'" >&2
      exit 1
    }
  fi
}

show_artifacts() {
  local bundle_dir="${CARGO_TARGET_DIR:-$PROJECT_DIR/src-tauri/target}/release/bundle"
  echo ""
  echo "== Artifacts =="
  if [[ -d "$bundle_dir" ]]; then
    find "$bundle_dir" -maxdepth 3 -type f \( -name "*.deb" -o -name "*.rpm" -o -name "*.AppImage" \) 2>/dev/null | while read -r f; do
      local size
      size=$(du -h "$f" 2>/dev/null | cut -f1)
      echo "  $f ($size)"
    done
  else
    echo "  (bundle dir not found: $bundle_dir)"
  fi
}

main() {
  parse_args "$@"
  run_checks

  if [[ "$CHECK_ONLY" == "true" ]]; then
    echo "Check completed. Use --help for build options."
    exit 0
  fi

  build_frontend
  build_tauri
  show_artifacts

  echo ""
  echo "Build completed for Linux ($MODE)"
}

main "$@"
