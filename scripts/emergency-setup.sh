#!/usr/bin/env bash
# emergency-setup.sh — Setup rápido de LLM local para modo emergencia
# Uso: ./scripts/emergency-setup.sh [--model MODEL] [--help]
set -euo pipefail

# ── Colores ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'; BOLD='\033[1m'

DEFAULT_MODEL="qwen2.5:7b"
MODEL="${1:-}"
[[ "$MODEL" == "--help" || "$MODEL" == "-h" ]] && {
  echo -e "${BOLD}PM-Workspace Emergency Setup${NC} — Instala Ollama + LLM local"
  echo "Uso: $0 [--model MODEL]. Detecta caché de emergency-plan si no hay internet."
  echo "Modelos: 8GB→qwen2.5:3b | 16GB→qwen2.5:7b (default) | 32GB+→qwen2.5:14b"
  exit 0
}

# Parsear argumentos
while [[ $# -gt 0 ]]; do
  case "$1" in
    --model) MODEL="$2"; shift 2 ;;
    *) shift ;;
  esac
done
MODEL="${MODEL:-$DEFAULT_MODEL}"

CACHE_DIR="$HOME/.pm-workspace-emergency"
OFFLINE=false

echo -e "\n${BOLD}${CYAN}PM-Workspace · Emergency Setup${NC}\n"

# ── 1. Detectar sistema y conectividad ───────────────────────────────────────
echo -e "${BLUE}[1/5]${NC} Detectando sistema..."
OS="$(uname -s)"
ARCH="$(uname -m)"
RAM_KB=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}' || sysctl -n hw.memsize 2>/dev/null | awk '{print int($1/1024)}' || echo 0)
RAM_GB=$((RAM_KB / 1024 / 1024))

echo -e "  OS: ${GREEN}$OS${NC} · Arch: ${GREEN}$ARCH${NC} · RAM: ${GREEN}${RAM_GB}GB${NC}"

[[ $RAM_GB -lt 8 ]] && echo -e "  ${YELLOW}⚠ RAM < 8GB${NC}" && [[ "$MODEL" == "$DEFAULT_MODEL" ]] && MODEL="qwen2.5:3b"

# Detectar GPU
GPU_INFO="ninguna"
command -v nvidia-smi &>/dev/null && GPU_INFO=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1 || echo "NVIDIA")
[[ "$OS" == "Darwin" ]] && sysctl -n machdep.cpu.brand_string &>/dev/null && GPU_INFO="Apple Silicon"
echo -e "  GPU: ${GREEN}$GPU_INFO${NC}"

# Detectar conectividad
if curl -s --max-time 5 https://ollama.ai >/dev/null 2>&1; then
  echo -e "  Internet: ${GREEN}conectado${NC}"
else
  OFFLINE=true; echo -e "  Internet: ${YELLOW}SIN CONEXIÓN${NC}"
  [[ -d "$CACHE_DIR" && -f "$CACHE_DIR/.plan-executed" ]] \
    && echo -e "  ${GREEN}✓${NC} Caché local detectada" \
    || { echo -e "  ${RED}✗${NC} Sin caché. Ejecuta ${CYAN}./scripts/emergency-plan.sh${NC} con conexión."; exit 1; }
fi

# ── 2. Instalar Ollama ──────────────────────────────────────────────────────
echo -e "\n${BLUE}[2/5]${NC} Verificando Ollama..."
if command -v ollama &>/dev/null; then
  OLLAMA_VER=$(ollama --version 2>/dev/null || echo "desconocida")
  echo -e "  ${GREEN}✓${NC} Ollama ya instalado (versión: $OLLAMA_VER)"
else
  if [[ "$OFFLINE" == true ]]; then
    # Instalación desde caché local
    OLLAMA_BIN="$CACHE_DIR/ollama-${OS,,}-${ARCH}"
    if [[ -f "$OLLAMA_BIN" ]]; then
      echo -e "  ${YELLOW}→${NC} Instalando Ollama desde caché local..."
      sudo cp "$OLLAMA_BIN" /usr/local/bin/ollama 2>/dev/null || cp "$OLLAMA_BIN" "$HOME/.local/bin/ollama" 2>/dev/null && mkdir -p "$HOME/.local/bin"
      echo -e "  ${GREEN}✓${NC} Ollama instalado desde caché"
    else
      echo -e "  ${RED}✗${NC} No hay binario Ollama en caché."
      echo -e "    Ejecuta ${CYAN}./scripts/emergency-plan.sh${NC} cuando tengas conexión."
      exit 1
    fi
  else
    echo -e "  ${YELLOW}→${NC} Instalando Ollama..."
    if [[ "$OS" == "Linux" ]]; then
      curl -fsSL https://ollama.ai/install.sh | sh
    elif [[ "$OS" == "Darwin" ]]; then
      echo -e "  ${YELLOW}⚠${NC} En macOS, descarga desde ${CYAN}https://ollama.com/download${NC}"
      echo -e "  Ejecuta de nuevo este script tras instalar."
      exit 1
    else
      echo -e "  ${RED}✗${NC} SO no soportado para instalación automática."
      echo -e "  Descarga manualmente: ${CYAN}https://ollama.com/download${NC}"
      exit 1
    fi
  fi
  echo -e "  ${GREEN}✓${NC} Ollama instalado"
fi

# ── 3. Iniciar servidor ─────────────────────────────────────────────────────
echo -e "\n${BLUE}[3/5]${NC} Verificando servidor Ollama..."
if curl -s http://localhost:11434/api/tags &>/dev/null; then
  echo -e "  ${GREEN}✓${NC} Servidor Ollama activo en :11434"
else
  echo -e "  ${YELLOW}→${NC} Iniciando servidor Ollama..."
  ollama serve &>/dev/null &
  sleep 3
  if curl -s http://localhost:11434/api/tags &>/dev/null; then
    echo -e "  ${GREEN}✓${NC} Servidor iniciado"
  else
    echo -e "  ${RED}✗${NC} No se pudo iniciar. Ejecuta manualmente: ollama serve"
    exit 1
  fi
fi

# ── 4. Verificar/descargar modelo ────────────────────────────────────────────
echo -e "\n${BLUE}[4/5]${NC} Verificando modelo ${CYAN}$MODEL${NC}..."
if ollama list 2>/dev/null | grep -q "$MODEL"; then
  echo -e "  ${GREEN}✓${NC} Modelo ya disponible"
elif [[ "$OFFLINE" == true ]]; then
  # En modo offline, el modelo debería estar ya cacheado por emergency-plan
  if ollama list 2>/dev/null | grep -q .; then
    AVAILABLE=$(ollama list 2>/dev/null | tail -n +2 | awk '{print $1}' | head -1)
    echo -e "  ${YELLOW}⚠${NC} Modelo $MODEL no disponible offline."
    echo -e "  ${YELLOW}→${NC} Usando modelo disponible: ${CYAN}$AVAILABLE${NC}"
    MODEL="$AVAILABLE"
  else
    echo -e "  ${RED}✗${NC} No hay modelos cacheados. El LLM local no funcionará."
    echo -e "    Ejecuta ${CYAN}./scripts/emergency-plan.sh${NC} cuando tengas conexión."
  fi
else
  echo -e "  ${YELLOW}→${NC} Descargando (puede tardar varios minutos)..."
  ollama pull "$MODEL"
  echo -e "  ${GREEN}✓${NC} Modelo descargado"
fi

# ── 5. Configurar variables ─────────────────────────────────────────────────
echo -e "\n${BLUE}[5/5]${NC} Configuración para Claude Code..."
ENV_FILE="$HOME/.pm-workspace-emergency.env"
cat > "$ENV_FILE" << ENVEOF
# PM-Workspace Emergency Mode — generado $(date -Iseconds)
export ANTHROPIC_BASE_URL="http://localhost:11434"
export PM_EMERGENCY_MODEL="$MODEL"
export PM_EMERGENCY_MODE="active"
ENVEOF

echo -e "  ${GREEN}✓${NC} Variables guardadas en ${CYAN}$ENV_FILE${NC}"
echo -e "\n${GREEN}${BOLD}✓ Setup completado${NC}"
echo -e "Activar: ${CYAN}source $ENV_FILE${NC}"
echo -e "Estado:  ${CYAN}./scripts/emergency-status.sh${NC}"
echo -e "Offline: ${CYAN}./scripts/emergency-fallback.sh --help${NC}"
