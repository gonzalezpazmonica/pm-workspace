#!/usr/bin/env bash
# emergency-plan.sh — Pre-descarga de Ollama y modelo LLM para modo offline
# Uso: ./scripts/emergency-plan.sh [--model MODEL] [--help]
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'; BOLD='\033[1m'

CACHE_DIR="$HOME/.pm-workspace-emergency"
MARKER_FILE="$CACHE_DIR/.plan-executed"
DEFAULT_MODEL="qwen2.5:7b"
MODEL=""

show_help() {
  echo -e "${BOLD}PM-Workspace Emergency Plan${NC} — Pre-descarga Ollama + LLM para offline"
  echo "Uso: $0 [--model MODEL] [--check] [--help]"
  echo "  --model MODEL  Modelo (default: auto según RAM). --check  Verifica si ya se ejecutó"
  echo "Modelos: 8GB→qwen2.5:3b | 16GB→qwen2.5:7b | 32GB+→qwen2.5:14b"
  exit 0
}

check_plan() {
  if [[ -f "$MARKER_FILE" ]]; then
    echo -e "${GREEN}✓${NC} Emergency plan ya ejecutado ($(cat "$MARKER_FILE"))"
    exit 0
  else
    exit 1
  fi
}

# Parsear argumentos
while [[ $# -gt 0 ]]; do
  case "$1" in
    --model) MODEL="$2"; shift 2 ;;
    --check) check_plan ;;
    --help|-h) show_help ;;
    *) shift ;;
  esac
done

echo -e "\n${BOLD}${CYAN}PM-Workspace · Emergency Plan${NC}"
echo -e "Pre-descarga de recursos para instalación offline.\n"

# ── 1. Detectar hardware y elegir modelo ─────────────────────────────────────
echo -e "${BLUE}[1/4]${NC} Detectando hardware..."
OS="$(uname -s)"
ARCH="$(uname -m)"
RAM_KB=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}' || sysctl -n hw.memsize 2>/dev/null | awk '{print int($1/1024)}' || echo 0)
RAM_GB=$((RAM_KB / 1024 / 1024))
echo -e "  OS: ${GREEN}$OS${NC} · Arch: ${GREEN}$ARCH${NC} · RAM: ${GREEN}${RAM_GB}GB${NC}"

if [[ -z "$MODEL" ]]; then
  if [[ $RAM_GB -ge 32 ]]; then MODEL="qwen2.5:14b"
  elif [[ $RAM_GB -ge 16 ]]; then MODEL="qwen2.5:7b"
  else MODEL="qwen2.5:3b"
  fi
  echo -e "  Modelo seleccionado automáticamente: ${CYAN}$MODEL${NC}"
fi

mkdir -p "$CACHE_DIR"

# ── 2. Descargar instalador de Ollama ────────────────────────────────────────
echo -e "\n${BLUE}[2/4]${NC} Descargando instalador de Ollama..."
OLLAMA_SCRIPT="$CACHE_DIR/ollama-install.sh"

if [[ "$OS" == "Linux" ]]; then
  if [[ -f "$OLLAMA_SCRIPT" ]]; then
    echo -e "  ${GREEN}✓${NC} Instalador ya en caché"
  else
    echo -e "  ${YELLOW}→${NC} Descargando script de instalación..."
    curl -fsSL https://ollama.ai/install.sh -o "$OLLAMA_SCRIPT"
    chmod +x "$OLLAMA_SCRIPT"
    echo -e "  ${GREEN}✓${NC} Instalador guardado en ${CYAN}$OLLAMA_SCRIPT${NC}"
  fi

  # Descargar binario directamente para offline completo
  OLLAMA_BIN="$CACHE_DIR/ollama-${OS,,}-${ARCH}"
  if [[ -f "$OLLAMA_BIN" ]]; then
    echo -e "  ${GREEN}✓${NC} Binario Ollama ya en caché"
  else
    echo -e "  ${YELLOW}→${NC} Descargando binario Ollama..."
    DOWNLOAD_URL="https://ollama.com/download/ollama-linux-${ARCH}"
    curl -fSL "$DOWNLOAD_URL" -o "$OLLAMA_BIN" 2>/dev/null || {
      echo -e "  ${YELLOW}⚠${NC} No se pudo descargar binario. Se usará script de instalación."
      OLLAMA_BIN=""
    }
    [[ -n "$OLLAMA_BIN" && -f "$OLLAMA_BIN" ]] && chmod +x "$OLLAMA_BIN"
    echo -e "  ${GREEN}✓${NC} Binario guardado"
  fi
elif [[ "$OS" == "Darwin" ]]; then
  echo -e "  ${YELLOW}⚠${NC} macOS: descarga Ollama desde ${CYAN}https://ollama.com/download${NC}"
  echo -e "  El plan cacheará el modelo una vez Ollama esté instalado."
fi

# ── 3. Pre-descargar modelo LLM ─────────────────────────────────────────────
echo -e "\n${BLUE}[3/4]${NC} Pre-descargando modelo ${CYAN}$MODEL${NC}..."

if command -v ollama &>/dev/null; then
  # Si Ollama ya está instalado, usar ollama pull (guarda en su propio caché)
  if curl -s --max-time 3 http://localhost:11434/api/tags &>/dev/null; then
    if ollama list 2>/dev/null | grep -q "$MODEL"; then
      echo -e "  ${GREEN}✓${NC} Modelo ya disponible en Ollama"
    else
      echo -e "  ${YELLOW}→${NC} Descargando modelo (puede tardar minutos)..."
      ollama pull "$MODEL"
      echo -e "  ${GREEN}✓${NC} Modelo descargado y cacheado por Ollama"
    fi
  else
    echo -e "  ${YELLOW}→${NC} Iniciando Ollama para descargar modelo..."
    ollama serve &>/dev/null &
    OLLAMA_PID=$!
    sleep 3
    ollama pull "$MODEL" 2>/dev/null || echo -e "  ${YELLOW}⚠${NC} No se pudo descargar modelo ahora"
    kill "$OLLAMA_PID" 2>/dev/null || true
    echo -e "  ${GREEN}✓${NC} Modelo cacheado"
  fi
else
  # Ollama no instalado aún — instalar temporalmente para cachear modelo
  if [[ "$OS" == "Linux" && -f "${OLLAMA_BIN:-}" ]]; then
    echo -e "  ${YELLOW}→${NC} Usando binario local para descargar modelo..."
    "$OLLAMA_BIN" serve &>/dev/null &
    OLLAMA_PID=$!
    sleep 4
    "$OLLAMA_BIN" pull "$MODEL" 2>/dev/null || {
      echo -e "  ${YELLOW}⚠${NC} No se pudo descargar modelo. Se hará durante emergency-setup."
      kill "$OLLAMA_PID" 2>/dev/null || true
    }
    kill "$OLLAMA_PID" 2>/dev/null || true
    echo -e "  ${GREEN}✓${NC} Modelo pre-descargado"
  else
    echo -e "  ${YELLOW}⚠${NC} Instala Ollama primero para pre-descargar el modelo"
  fi
fi

# ── 4. Guardar metadata y marcador ───────────────────────────────────────────
echo -e "\n${BLUE}[4/4]${NC} Guardando metadata..."
cat > "$CACHE_DIR/plan-info.json" << JSONEOF
{"executed":"$(date -Iseconds)","os":"$OS","arch":"$ARCH","ram_gb":$RAM_GB,"model":"$MODEL"}
JSONEOF
date -Iseconds > "$MARKER_FILE"

echo -e "\n${GREEN}${BOLD}✓ Emergency Plan completado${NC}"
echo -e "Caché: ${CYAN}$CACHE_DIR${NC} · Modelo: ${CYAN}$MODEL${NC}"
echo -e "Si pierdes conexión: ${CYAN}./scripts/emergency-setup.sh${NC} (usará caché local)"
