#!/usr/bin/env bash
# emergency-setup.sh — Setup rápido de LLM local para modo emergencia
# Soporta: Linux (amd64/arm64), macOS (Intel/Apple Silicon), Windows (usar .ps1)
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'; BOLD='\033[1m'

DEFAULT_MODEL="qwen2.5:7b"; MODEL=""
iso_date() { date -Iseconds 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%S+00:00"; }
[[ "${1:-}" == "--help" || "${1:-}" == "-h" ]] && {
  echo -e "${BOLD}PM-Workspace Emergency Setup${NC} — Instala Ollama + LLM local"
  echo "Uso: $0 [--model MODEL]. Soporta Linux/macOS. Windows: usar .ps1"
  echo "Modelos: 8GB→qwen2.5:3b | 16GB→qwen2.5:7b (default) | 32GB+→qwen2.5:14b"; exit 0; }

while [[ $# -gt 0 ]]; do case "$1" in --model) MODEL="$2"; shift 2 ;; *) shift ;; esac; done
MODEL="${MODEL:-$DEFAULT_MODEL}"
CACHE_DIR="$HOME/.pm-workspace-emergency"; OFFLINE=false

echo -e "\n${BOLD}${CYAN}PM-Workspace · Emergency Setup${NC}\n"

# ── 1. Detectar sistema y conectividad ───────────────────────────────────────
echo -e "${BLUE}[1/5]${NC} Detectando sistema..."
OS="$(uname -s)"; ARCH="$(uname -m)"
if [[ "$OS" == "Darwin" ]]; then
  RAM_BYTES=$(sysctl -n hw.memsize 2>/dev/null || echo 0); RAM_GB=$((RAM_BYTES / 1024 / 1024 / 1024))
else
  RAM_KB=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}' || echo 0); RAM_GB=$((RAM_KB / 1024 / 1024))
fi
echo -e "  OS: ${GREEN}$OS${NC} · Arch: ${GREEN}$ARCH${NC} · RAM: ${GREEN}${RAM_GB}GB${NC}"
[[ $RAM_GB -lt 8 ]] && echo -e "  ${YELLOW}⚠ RAM < 8GB${NC}" && [[ "$MODEL" == "$DEFAULT_MODEL" ]] && MODEL="qwen2.5:3b"

# GPU
GPU_INFO="ninguna"
command -v nvidia-smi &>/dev/null && GPU_INFO=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1 || echo "NVIDIA")
[[ "$OS" == "Darwin" ]] && [[ "$ARCH" == "arm64" ]] && GPU_INFO="Apple Silicon (Metal)"
echo -e "  GPU: ${GREEN}$GPU_INFO${NC}"

# Conectividad
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
  echo -e "  ${GREEN}✓${NC} Ollama instalado ($OLLAMA_VER)"
else
  if [[ "$OFFLINE" == true ]]; then
    OLLAMA_BIN="$CACHE_DIR/ollama-bin"
    if [[ -f "$OLLAMA_BIN" ]]; then
      echo -e "  ${YELLOW}→${NC} Instalando Ollama desde caché local..."
      if [[ "$OS" == "Darwin" ]]; then
        mkdir -p "$HOME/.local/bin" && cp "$OLLAMA_BIN" "$HOME/.local/bin/ollama"
        echo -e "  ${YELLOW}ℹ${NC} Añade ${CYAN}export PATH=\"\$HOME/.local/bin:\$PATH\"${NC} a tu shell"
      else
        mkdir -p "$HOME/.local/bin"
        sudo cp "$OLLAMA_BIN" /usr/local/bin/ollama 2>/dev/null || cp "$OLLAMA_BIN" "$HOME/.local/bin/ollama"
      fi
      echo -e "  ${GREEN}✓${NC} Ollama instalado desde caché"
    else
      echo -e "  ${RED}✗${NC} No hay binario en caché. Ejecuta ${CYAN}emergency-plan.sh${NC} con conexión."; exit 1
    fi
  else
    echo -e "  ${YELLOW}→${NC} Instalando Ollama..."
    if [[ "$OS" == "Linux" ]]; then
      curl -fsSL https://ollama.ai/install.sh | sh
    elif [[ "$OS" == "Darwin" ]]; then
      # macOS: descargar tgz y extraer binario
      TMP_TGZ="$(mktemp)"; curl -fSL "https://ollama.com/download/ollama-darwin.tgz" -o "$TMP_TGZ"
      TMP_EX="$(mktemp -d)"; tar xzf "$TMP_TGZ" -C "$TMP_EX" 2>/dev/null
      mkdir -p "$HOME/.local/bin" && cp "$TMP_EX/ollama" "$HOME/.local/bin/ollama" && chmod +x "$HOME/.local/bin/ollama"
      rm -rf "$TMP_EX" "$TMP_TGZ"
      export PATH="$HOME/.local/bin:$PATH"
      echo -e "  ${YELLOW}ℹ${NC} Añade ${CYAN}export PATH=\"\$HOME/.local/bin:\$PATH\"${NC} a ~/.zshrc"
    else
      echo -e "  ${RED}✗${NC} SO no soportado. En Windows usa ${CYAN}scripts/emergency-setup.ps1${NC}"; exit 1
    fi
  fi
  echo -e "  ${GREEN}✓${NC} Ollama instalado"
fi

# ── 3. Iniciar servidor ─────────────────────────────────────────────────────
echo -e "\n${BLUE}[3/5]${NC} Verificando servidor Ollama..."
if curl -s http://localhost:11434/api/tags &>/dev/null; then
  echo -e "  ${GREEN}✓${NC} Servidor activo en :11434"
else
  echo -e "  ${YELLOW}→${NC} Iniciando servidor..."
  ollama serve &>/dev/null &
  sleep 3
  curl -s http://localhost:11434/api/tags &>/dev/null \
    && echo -e "  ${GREEN}✓${NC} Servidor iniciado" \
    || { echo -e "  ${RED}✗${NC} No se pudo iniciar. Ejecuta: ollama serve"; exit 1; }
fi

# ── 4. Verificar/descargar modelo ────────────────────────────────────────────
echo -e "\n${BLUE}[4/5]${NC} Verificando modelo ${CYAN}$MODEL${NC}..."
if ollama list 2>/dev/null | grep -q "$MODEL"; then
  echo -e "  ${GREEN}✓${NC} Modelo disponible"
elif [[ "$OFFLINE" == true ]]; then
  if ollama list 2>/dev/null | grep -q .; then
    AVAILABLE=$(ollama list 2>/dev/null | tail -n +2 | awk '{print $1}' | head -1)
    echo -e "  ${YELLOW}⚠${NC} $MODEL no disponible offline. Usando: ${CYAN}$AVAILABLE${NC}"; MODEL="$AVAILABLE"
  else echo -e "  ${RED}✗${NC} No hay modelos cacheados. Ejecuta emergency-plan.sh con conexión."; fi
else
  echo -e "  ${YELLOW}→${NC} Descargando (puede tardar minutos)..."; ollama pull "$MODEL"
  echo -e "  ${GREEN}✓${NC} Modelo descargado"
fi

# ── 5. Configurar variables ─────────────────────────────────────────────────
echo -e "\n${BLUE}[5/5]${NC} Configuración para Claude Code..."
ENV_FILE="$HOME/.pm-workspace-emergency.env"
cat > "$ENV_FILE" << ENVEOF
# PM-Workspace Emergency Mode — generado $(iso_date)
export ANTHROPIC_BASE_URL="http://localhost:11434"
export PM_EMERGENCY_MODEL="$MODEL"
export PM_EMERGENCY_MODE="active"
ENVEOF

echo -e "  ${GREEN}✓${NC} Variables en ${CYAN}$ENV_FILE${NC}"
echo -e "\n${GREEN}${BOLD}✓ Setup completado${NC}"
echo -e "Activar: ${CYAN}source $ENV_FILE${NC}"
echo -e "Estado:  ${CYAN}./scripts/emergency-status.sh${NC}"
