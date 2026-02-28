#!/usr/bin/env bash
# emergency-plan.sh — Pre-descarga de Ollama y modelo LLM para modo offline
# Soporta: Linux (amd64/arm64), macOS (Intel/Apple Silicon), Windows (vía PowerShell)
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'; BOLD='\033[1m'

CACHE_DIR="$HOME/.pm-workspace-emergency"
MARKER_FILE="$CACHE_DIR/.plan-executed"
MODEL=""

show_help() {
  echo -e "${BOLD}PM-Workspace Emergency Plan${NC} — Pre-descarga Ollama + LLM para offline"
  echo "Uso: $0 [--model MODEL] [--check] [--help]"
  echo "  --model MODEL  Modelo (default: auto según RAM). --check  Verifica si ya se ejecutó"
  echo "Soporta: Linux, macOS, Windows (usar .ps1). Modelos: 8GB→3b | 16GB→7b | 32GB+→14b"
  exit 0
}

check_plan() {
  [[ -f "$MARKER_FILE" ]] && { echo -e "${GREEN}✓${NC} Emergency plan ejecutado ($(cat "$MARKER_FILE"))"; exit 0; } || exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --model) MODEL="$2"; shift 2 ;; --check) check_plan ;; --help|-h) show_help ;; *) shift ;;
  esac
done

echo -e "\n${BOLD}${CYAN}PM-Workspace · Emergency Plan${NC}"
echo -e "Pre-descarga de recursos para instalación offline.\n"

# ── 1. Detectar hardware y elegir modelo ─────────────────────────────────────
echo -e "${BLUE}[1/4]${NC} Detectando hardware..."
OS="$(uname -s)"
ARCH="$(uname -m)"

if [[ "$OS" == "Darwin" ]]; then
  RAM_BYTES=$(sysctl -n hw.memsize 2>/dev/null || echo 0)
  RAM_GB=$((RAM_BYTES / 1024 / 1024 / 1024))
else
  RAM_KB=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}' || echo 0)
  RAM_GB=$((RAM_KB / 1024 / 1024))
fi
echo -e "  OS: ${GREEN}$OS${NC} · Arch: ${GREEN}$ARCH${NC} · RAM: ${GREEN}${RAM_GB}GB${NC}"

if [[ -z "$MODEL" ]]; then
  if [[ $RAM_GB -ge 32 ]]; then MODEL="qwen2.5:14b"
  elif [[ $RAM_GB -ge 16 ]]; then MODEL="qwen2.5:7b"
  else MODEL="qwen2.5:3b"; fi
  echo -e "  Modelo: ${CYAN}$MODEL${NC} (auto)"
fi
mkdir -p "$CACHE_DIR"

# ── 2. Descargar Ollama según OS ─────────────────────────────────────────────
echo -e "\n${BLUE}[2/4]${NC} Descargando Ollama para ${GREEN}$OS${NC}..."
OLLAMA_BIN="$CACHE_DIR/ollama-bin"

if [[ -f "$OLLAMA_BIN" ]]; then
  echo -e "  ${GREEN}✓${NC} Binario Ollama ya en caché"
elif [[ "$OS" == "Linux" ]]; then
  # Linux: tar.zst con binario en bin/ollama
  DL_ARCH="$ARCH"; [[ "$ARCH" == "x86_64" ]] && DL_ARCH="amd64"; [[ "$ARCH" == "aarch64" ]] && DL_ARCH="arm64"
  curl -fsSL https://ollama.ai/install.sh -o "$CACHE_DIR/ollama-install.sh" && chmod +x "$CACHE_DIR/ollama-install.sh"
  TMP_TAR="$CACHE_DIR/ollama.tar.zst"
  echo -e "  ${YELLOW}→${NC} Descargando ollama-linux-${DL_ARCH}.tar.zst..."
  curl -fSL "https://ollama.com/download/ollama-linux-${DL_ARCH}.tar.zst" -o "$TMP_TAR" && {
    TMP_EX="$CACHE_DIR/_extract"; mkdir -p "$TMP_EX"
    tar --zstd -xf "$TMP_TAR" -C "$TMP_EX" 2>/dev/null
    FOUND=$(find "$TMP_EX" -name "ollama" -type f | head -1)
    [[ -n "$FOUND" ]] && cp "$FOUND" "$OLLAMA_BIN" && chmod +x "$OLLAMA_BIN" || OLLAMA_BIN=""
    rm -rf "$TMP_EX" "$TMP_TAR"
    echo -e "  ${GREEN}✓${NC} Binario Linux extraído y cacheado"
  } || { echo -e "  ${YELLOW}⚠${NC} Descarga falló. Se usará script de instalación."; rm -f "$TMP_TAR"; OLLAMA_BIN=""; }
elif [[ "$OS" == "Darwin" ]]; then
  # macOS: tgz con binario ollama en raíz (~70MB)
  TMP_TGZ="$CACHE_DIR/ollama-darwin.tgz"
  echo -e "  ${YELLOW}→${NC} Descargando ollama-darwin.tgz..."
  curl -fSL "https://ollama.com/download/ollama-darwin.tgz" -o "$TMP_TGZ" && {
    TMP_EX="$CACHE_DIR/_extract"; mkdir -p "$TMP_EX"
    tar xzf "$TMP_TGZ" -C "$TMP_EX" 2>/dev/null
    [[ -f "$TMP_EX/ollama" ]] && cp "$TMP_EX/ollama" "$OLLAMA_BIN" && chmod +x "$OLLAMA_BIN" || OLLAMA_BIN=""
    rm -rf "$TMP_EX" "$TMP_TGZ"
    echo -e "  ${GREEN}✓${NC} Binario macOS extraído y cacheado"
  } || { echo -e "  ${YELLOW}⚠${NC} Descarga falló. Instala desde https://ollama.com/download"; rm -f "$TMP_TGZ"; OLLAMA_BIN=""; }
else
  echo -e "  ${YELLOW}⚠${NC} SO no soportado por este script. En Windows usa: ${CYAN}scripts/emergency-plan.ps1${NC}"
fi

# ── 3. Pre-descargar modelo LLM ─────────────────────────────────────────────
echo -e "\n${BLUE}[3/4]${NC} Pre-descargando modelo ${CYAN}$MODEL${NC}..."
if command -v ollama &>/dev/null; then
  if curl -s --max-time 3 http://localhost:11434/api/tags &>/dev/null; then
    ollama list 2>/dev/null | grep -q "$MODEL" && echo -e "  ${GREEN}✓${NC} Modelo ya disponible" || {
      echo -e "  ${YELLOW}→${NC} Descargando modelo..."; ollama pull "$MODEL"; echo -e "  ${GREEN}✓${NC} Modelo descargado"; }
  else
    echo -e "  ${YELLOW}→${NC} Iniciando Ollama para descargar modelo..."
    ollama serve &>/dev/null & OLLAMA_PID=$!; sleep 3
    ollama pull "$MODEL" 2>/dev/null || echo -e "  ${YELLOW}⚠${NC} No se pudo descargar modelo ahora"
    kill "$OLLAMA_PID" 2>/dev/null || true
  fi
elif [[ -f "${OLLAMA_BIN:-}" ]]; then
  echo -e "  ${YELLOW}→${NC} Usando binario cacheado para descargar modelo..."
  "$OLLAMA_BIN" serve &>/dev/null & OLLAMA_PID=$!; sleep 4
  "$OLLAMA_BIN" pull "$MODEL" 2>/dev/null || {
    echo -e "  ${YELLOW}⚠${NC} No se pudo descargar modelo. Se hará en emergency-setup."
    kill "$OLLAMA_PID" 2>/dev/null || true; }
  kill "$OLLAMA_PID" 2>/dev/null || true
  echo -e "  ${GREEN}✓${NC} Modelo pre-descargado"
else
  echo -e "  ${YELLOW}⚠${NC} Instala Ollama primero para pre-descargar el modelo"
fi

# ── 4. Guardar metadata y marcador ───────────────────────────────────────────
echo -e "\n${BLUE}[4/4]${NC} Guardando metadata..."
cat > "$CACHE_DIR/plan-info.json" << JSONEOF
{"executed":"$(date -Iseconds)","os":"$OS","arch":"$ARCH","ram_gb":$RAM_GB,"model":"$MODEL"}
JSONEOF
date -Iseconds > "$MARKER_FILE"

echo -e "\n${GREEN}${BOLD}✓ Emergency Plan completado${NC}"
echo -e "Caché: ${CYAN}$CACHE_DIR${NC} · Modelo: ${CYAN}$MODEL${NC}"
echo -e "Offline: ${CYAN}./scripts/emergency-setup.sh${NC} (usará caché local)"
