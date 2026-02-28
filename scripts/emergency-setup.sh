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
  echo -e "${BOLD}PM-Workspace Emergency Setup${NC}"
  echo "Instala Ollama y configura un LLM local para operar sin conexión cloud."
  echo ""
  echo "Uso: $0 [--model MODEL]"
  echo "  --model MODEL   Modelo a descargar (default: $DEFAULT_MODEL)"
  echo "  --help          Muestra esta ayuda"
  echo ""
  echo "Modelos recomendados por hardware:"
  echo "  8GB RAM:   qwen2.5:3b, phi3.5:3.8b"
  echo "  16GB RAM:  qwen2.5:7b (default), mistral:7b"
  echo "  32GB+ RAM: qwen2.5:14b, deepseek-coder-v2:16b"
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

echo -e "\n${BOLD}${CYAN}╔══════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║   PM-Workspace · Emergency Setup         ║${NC}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════╝${NC}\n"

# ── 1. Detectar sistema ──────────────────────────────────────────────────────
echo -e "${BLUE}[1/5]${NC} Detectando sistema..."
OS="$(uname -s)"
ARCH="$(uname -m)"
RAM_KB=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}' || sysctl -n hw.memsize 2>/dev/null | awk '{print int($1/1024)}' || echo 0)
RAM_GB=$((RAM_KB / 1024 / 1024))

echo -e "  OS: ${GREEN}$OS${NC} · Arch: ${GREEN}$ARCH${NC} · RAM: ${GREEN}${RAM_GB}GB${NC}"

if [[ $RAM_GB -lt 8 ]]; then
  echo -e "  ${YELLOW}⚠ RAM < 8GB. Recomendado: qwen2.5:1.5b o phi3.5:3.8b${NC}"
  [[ "$MODEL" == "$DEFAULT_MODEL" ]] && MODEL="qwen2.5:3b"
fi

# Detectar GPU
GPU_INFO="ninguna detectada"
if command -v nvidia-smi &>/dev/null; then
  GPU_INFO=$(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>/dev/null | head -1 || echo "NVIDIA (sin detalle)")
elif [[ "$OS" == "Darwin" ]] && sysctl -n machdep.cpu.brand_string &>/dev/null; then
  GPU_INFO="Apple Silicon (Metal)"
fi
echo -e "  GPU: ${GREEN}$GPU_INFO${NC}"

# ── 2. Instalar Ollama ──────────────────────────────────────────────────────
echo -e "\n${BLUE}[2/5]${NC} Verificando Ollama..."
if command -v ollama &>/dev/null; then
  OLLAMA_VER=$(ollama --version 2>/dev/null || echo "desconocida")
  echo -e "  ${GREEN}✓${NC} Ollama ya instalado (versión: $OLLAMA_VER)"
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

# ── 4. Descargar modelo ─────────────────────────────────────────────────────
echo -e "\n${BLUE}[4/5]${NC} Descargando modelo ${CYAN}$MODEL${NC}..."
if ollama list 2>/dev/null | grep -q "$MODEL"; then
  echo -e "  ${GREEN}✓${NC} Modelo ya disponible"
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
echo -e ""
echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${GREEN}║   ✓ Setup completado                    ║${NC}"
echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════╝${NC}"
echo -e ""
echo -e "Para activar el modo emergencia:"
echo -e "  ${CYAN}source $ENV_FILE${NC}"
echo -e ""
echo -e "Para verificar estado:"
echo -e "  ${CYAN}./scripts/emergency-status.sh${NC}"
echo -e ""
echo -e "Para operar sin LLM:"
echo -e "  ${CYAN}./scripts/emergency-fallback.sh --help${NC}"
