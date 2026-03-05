#!/usr/bin/env bash
# emergency-plan.sh — Pre-descarga de Ollama y modelo LLM para modo offline
# Soporta: Linux (amd64/arm64), macOS (Intel/Apple Silicon), Windows (vía PowerShell)
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'; BOLD='\033[1m'

CACHE_DIR="$HOME/.pm-workspace-emergency"
MARKER_FILE="$CACHE_DIR/.plan-executed"
MODEL=""
iso_date() { date -Iseconds 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%S+00:00"; }

show_help() {
  echo -e "${BOLD}PM-Workspace Emergency Plan${NC} — Pre-descarga Ollama + LLM para offline"
  echo "Uso: $0 [--model MODEL] [--check] [--help]"
  echo "Modelos: 8GB→3b | 16GB→7b | 32GB+→14b. Windows: usar .ps1"; exit 0; }
check_plan() {
  [[ -f "$MARKER_FILE" ]] && { echo -e "${GREEN}✓${NC} Emergency plan ejecutado ($(cat "$MARKER_FILE"))"; exit 0; } || exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --model) MODEL="$2"; shift 2 ;; --check) check_plan ;; --help|-h) show_help ;; *) shift ;;
  esac
done

echo -e "\n${BOLD}${CYAN}PM-Workspace · Emergency Plan${NC}"
echo -e "Pre-descarga de recursos para instalación offline.\n"

# ── 0. Check de conectividad ───────────────────────────────────────────────
if ! curl -s --max-time 5 https://ollama.com >/dev/null 2>&1; then
  echo -e "${RED}✗${NC} Sin conexión a internet. Se necesita para descargar recursos."
  echo -e "  Si ya ejecutaste el plan, usa: ${CYAN}./scripts/emergency-setup.sh${NC}"; exit 1
fi

# ── 1. Detectar hardware y elegir modelo ───────────────────────────────────
echo -e "${BLUE}[1/5]${NC} Detectando hardware..."
OS="$(uname -s)"
ARCH="$(uname -m)"

if [[ "$OS" == "Darwin" ]]; then RAM_GB=$(( $(sysctl -n hw.memsize 2>/dev/null || echo 0) / 1024 / 1024 / 1024 ))
else RAM_GB=$(( $(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}' || echo 0) / 1024 / 1024 )); fi
echo -e "  OS: ${GREEN}$OS${NC} · Arch: ${GREEN}$ARCH${NC} · RAM: ${GREEN}${RAM_GB}GB${NC}"

if [[ -z "$MODEL" ]]; then
  [[ $RAM_GB -ge 32 ]] && MODEL="qwen2.5:14b" || { [[ $RAM_GB -ge 16 ]] && MODEL="qwen2.5:7b" || MODEL="qwen2.5:3b"; }
  echo -e "  Modelo: ${CYAN}$MODEL${NC} (auto)"
fi; mkdir -p "$CACHE_DIR"

# ── 2. Descargar Ollama según OS ────────────────────────────────────────────
echo -e "\n${BLUE}[2/5]${NC} Descargando Ollama para ${GREEN}$OS${NC}..."
OLLAMA_BIN="$CACHE_DIR/ollama-bin"
_extract_ollama() { # usage: _extract_ollama <archive> <tar_flags>
  local arc="$1"; shift; TMP_EX="$CACHE_DIR/_extract"; mkdir -p "$TMP_EX"
  tar "$@" -xf "$arc" -C "$TMP_EX" 2>/dev/null
  local found; found=$(find "$TMP_EX" -name "ollama" -type f | head -1)
  [[ -n "$found" ]] && cp "$found" "$OLLAMA_BIN" && chmod +x "$OLLAMA_BIN" || OLLAMA_BIN=""
  rm -rf "$TMP_EX" "$arc"
}
if [[ -f "$OLLAMA_BIN" ]]; then echo -e "  ${GREEN}✓${NC} Binario Ollama ya en caché"
elif [[ "$OS" == "Linux" ]]; then
  DL_ARCH="$ARCH"; [[ "$ARCH" == "x86_64" ]] && DL_ARCH="amd64"; [[ "$ARCH" == "aarch64" ]] && DL_ARCH="arm64"
  curl -fsSL https://ollama.ai/install.sh -o "$CACHE_DIR/ollama-install.sh" && chmod +x "$CACHE_DIR/ollama-install.sh"
  TMP_TAR="$CACHE_DIR/ollama.tar.zst"
  echo -e "  ${YELLOW}→${NC} Descargando ollama-linux-${DL_ARCH}.tar.zst..."
  curl -fSL "https://ollama.com/download/ollama-linux-${DL_ARCH}.tar.zst" -o "$TMP_TAR" && {
    _extract_ollama "$TMP_TAR" --zstd; echo -e "  ${GREEN}✓${NC} Binario Linux extraído y cacheado"
  } || { echo -e "  ${YELLOW}⚠${NC} Descarga falló. Se usará script de instalación."; rm -f "$TMP_TAR"; OLLAMA_BIN=""; }
elif [[ "$OS" == "Darwin" ]]; then
  TMP_TGZ="$CACHE_DIR/ollama-darwin.tgz"
  echo -e "  ${YELLOW}→${NC} Descargando ollama-darwin.tgz..."
  curl -fSL "https://ollama.com/download/ollama-darwin.tgz" -o "$TMP_TGZ" && {
    _extract_ollama "$TMP_TGZ" -z; echo -e "  ${GREEN}✓${NC} Binario macOS extraído y cacheado"
  } || { echo -e "  ${YELLOW}⚠${NC} Descarga falló. Instala desde https://ollama.com/download"; rm -f "$TMP_TGZ"; OLLAMA_BIN=""; }
else echo -e "  ${YELLOW}⚠${NC} SO no soportado. En Windows usa: ${CYAN}scripts/emergency-plan.ps1${NC}"; fi

# ── 3. Pre-descargar modelo LLM ─────────────────────────────────────────────
echo -e "\n${BLUE}[3/5]${NC} Pre-descargando modelo ${CYAN}$MODEL${NC}..."
MODEL_OK=false; SMALL_OK=false; OLLAMA_OK=false
_pull_small() { # Pull qwen2.5:3b if not present, using $1 as ollama binary
  [[ "$MODEL" == "qwen2.5:3b" ]] && return
  "$1" list 2>/dev/null | grep -q "qwen2.5:3b" && SMALL_OK=true || {
    echo -e "  ${YELLOW}→${NC} Modelo auxiliar ${CYAN}qwen2.5:3b${NC} (haiku)..."
    "$1" pull "qwen2.5:3b" 2>/dev/null && SMALL_OK=true || true; }
}
if command -v ollama &>/dev/null; then
  OLLAMA_OK=true
  if curl -s --max-time 3 http://localhost:11434/api/tags &>/dev/null; then
    ollama list 2>/dev/null | grep -q "$MODEL" && { echo -e "  ${GREEN}✓${NC} Modelo ya disponible"; MODEL_OK=true; } || {
      echo -e "  ${YELLOW}→${NC} Descargando modelo..."; ollama pull "$MODEL" && MODEL_OK=true; echo -e "  ${GREEN}✓${NC} Modelo descargado"; }
    _pull_small ollama
  else
    echo -e "  ${YELLOW}→${NC} Iniciando Ollama para descargar modelo..."
    ollama serve &>/dev/null & OLLAMA_PID=$!; sleep 3
    ollama pull "$MODEL" 2>/dev/null && MODEL_OK=true || echo -e "  ${YELLOW}⚠${NC} No se pudo descargar modelo ahora"
    _pull_small ollama; kill "$OLLAMA_PID" 2>/dev/null || true
  fi
elif [[ -f "${OLLAMA_BIN:-}" ]]; then
  OLLAMA_OK=true
  echo -e "  ${YELLOW}→${NC} Usando binario cacheado para descargar modelo..."
  "$OLLAMA_BIN" serve &>/dev/null & OLLAMA_PID=$!; sleep 4
  if "$OLLAMA_BIN" list 2>/dev/null | grep -q "$MODEL"; then
    echo -e "  ${GREEN}✓${NC} Modelo $MODEL ya disponible"; MODEL_OK=true
  else
    "$OLLAMA_BIN" pull "$MODEL" 2>/dev/null && MODEL_OK=true || {
      echo -e "  ${YELLOW}⚠${NC} No se pudo descargar. Se hará en emergency-setup."; }
    $MODEL_OK && echo -e "  ${GREEN}✓${NC} Modelo pre-descargado"
  fi
  _pull_small "$OLLAMA_BIN"; kill "$OLLAMA_PID" 2>/dev/null || true
else echo -e "  ${YELLOW}⚠${NC} Instala Ollama primero para pre-descargar el modelo"; fi

# ── 4. Guardar metadata y marcador ───────────────────────────────────────────
echo -e "\n${BLUE}[4/5]${NC} Guardando metadata..."
cat > "$CACHE_DIR/plan-info.json" << JSONEOF
{"executed":"$(iso_date)","os":"$OS","arch":"$ARCH","ram_gb":$RAM_GB,"model":"$MODEL"}
JSONEOF
iso_date > "$MARKER_FILE"

# ── 5. Verificación final de caché offline ────────────────────────────────────
echo -e "\n${BLUE}[5/5]${NC} Verificando caché offline..."
if [[ -f "$OLLAMA_BIN" ]]; then echo -e "  ${GREEN}✓${NC} Binario Ollama cacheado"
elif $OLLAMA_OK; then echo -e "  ${GREEN}✓${NC} Ollama instalado en PATH"
else echo -e "  ${YELLOW}⚠${NC} Binario Ollama no disponible"; fi
$MODEL_OK && echo -e "  ${GREEN}✓${NC} Modelo $MODEL cacheado" \
  || echo -e "  ${YELLOW}⚠${NC} Modelo $MODEL no verificado"
if [[ "$MODEL" != "qwen2.5:3b" ]]; then
  $SMALL_OK && echo -e "  ${GREEN}✓${NC} Modelo auxiliar qwen2.5:3b cacheado" \
    || echo -e "  ${YELLOW}⚠${NC} Modelo auxiliar qwen2.5:3b no verificado"
fi

echo -e "\n${GREEN}${BOLD}✓ Emergency Plan completado${NC}"
echo -e "Caché: ${CYAN}$CACHE_DIR${NC} · Modelo: ${CYAN}$MODEL${NC}"
echo -e "Offline: ${CYAN}./scripts/emergency-setup.sh${NC} (usará caché local)"
