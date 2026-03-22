#!/usr/bin/env bash
# sovereignty-pack.sh — Build fully offline Savia USB installer
# Usage: sovereignty-pack.sh [--tier 1|2|3] [--dest /media/usb] [--arch amd64]
# See SPEC-017 for full design. Delegates to sovereignty-ops.sh.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
source "$SCRIPT_DIR/sovereignty-ops.sh"

CACHE_DIR="${SAVIA_SOVEREIGNTY_CACHE:-$HOME/.savia/sovereignty-cache}"
TIER=1; DEST=""; ARCH="amd64"; DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tier) TIER="$2"; shift 2 ;;
    --dest) DEST="$2"; shift 2 ;;
    --arch) ARCH="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    --help|-h) show_help; exit 0 ;;
    *) shift ;;
  esac
done

echo -e "\n${BOLD}${CYAN}Savia Sovereignty Pack${NC} — Tier $TIER"
echo -e "Cache: ${CYAN}$CACHE_DIR${NC}\n"
mkdir -p "$CACHE_DIR"/{python,wheels,models,ollama,bin,node,workspace}

# ── Phase 1: Download ───────────────────────────────────────────────────
echo -e "${BLUE}[1/5]${NC} Downloading components..."
download_python
download_wheels
download_whisper_models
download_kokoro
download_ollama_binary
download_ollama_models
download_static_bins
[[ $TIER -ge 2 ]] && download_node
download_workspace

# ── Phase 2: Manifest ───────────────────────────────────────────────────
echo -e "\n${BLUE}[2/5]${NC} Generating manifest..."
$DRY_RUN || generate_manifest

# ── Phase 3: Size report ────────────────────────────────────────────────
echo -e "\n${BLUE}[3/5]${NC} Calculating sizes..."
TOTAL=$(du -sm "$CACHE_DIR" 2>/dev/null | cut -f1)
echo -e "  Total cache: ${CYAN}${TOTAL} MB${NC}"

# ── Phase 4: Copy to USB ────────────────────────────────────────────────
if [[ -n "$DEST" ]] && ! $DRY_RUN; then
  echo -e "\n${BLUE}[4/5]${NC} Copying to $DEST..."
  copy_to_usb
else
  echo -e "\n${BLUE}[4/5]${NC} Skipped (no --dest or --dry-run)"
fi

# ── Phase 5: Summary ────────────────────────────────────────────────────
echo -e "\n${BLUE}[5/5]${NC} Summary"
echo -e "  Tier: ${CYAN}$TIER${NC} | Arch: ${CYAN}$ARCH${NC}"
echo -e "  Cache: ${CYAN}$CACHE_DIR${NC} (${TOTAL:-?} MB)"
[[ -n "$DEST" ]] && echo -e "  USB: ${CYAN}$DEST/SAVIA-USB/${NC}"
echo -e "\n${GREEN}${BOLD}✓ Sovereignty pack complete${NC}"
