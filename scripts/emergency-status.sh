#!/usr/bin/env bash
# emergency-status.sh — Estado del sistema de emergencia PM-Workspace
# Uso: ./scripts/emergency-status.sh
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; NC='\033[0m'; BOLD='\033[1m'

echo -e "\n${BOLD}${CYAN}PM-Workspace · Emergency Status${NC}\n"

ISSUES=0

# ── Ollama instalado ─────────────────────────────────────────────────────────
if command -v ollama &>/dev/null; then
  VER=$(ollama --version 2>/dev/null || echo "?")
  echo -e "  ${GREEN}✓${NC} Ollama instalado (v$VER)"
else
  echo -e "  ${RED}✗${NC} Ollama NO instalado"
  echo -e "    → Ejecuta: ${CYAN}./scripts/emergency-setup.sh${NC}"
  ISSUES=$((ISSUES + 1))
fi

# ── Servidor activo ──────────────────────────────────────────────────────────
if curl -s --max-time 3 http://localhost:11434/api/tags &>/dev/null; then
  echo -e "  ${GREEN}✓${NC} Servidor Ollama activo (:11434)"
else
  echo -e "  ${RED}✗${NC} Servidor Ollama NO responde"
  echo -e "    → Ejecuta: ${CYAN}ollama serve${NC}"
  ISSUES=$((ISSUES + 1))
fi

# ── Modelos disponibles ─────────────────────────────────────────────────────
if command -v ollama &>/dev/null; then
  MODELS=$(ollama list 2>/dev/null | tail -n +2 || echo "")
  if [[ -n "$MODELS" ]]; then
    MODEL_COUNT=$(echo "$MODELS" | wc -l | tr -d ' ')
    echo -e "  ${GREEN}✓${NC} Modelos disponibles: ${BOLD}$MODEL_COUNT${NC}"
    echo "$MODELS" | while IFS= read -r line; do
      NAME=$(echo "$line" | awk '{print $1}')
      SIZE=$(echo "$line" | awk '{print $3, $4}')
      echo -e "    · $NAME ($SIZE)"
    done
  else
    echo -e "  ${YELLOW}⚠${NC} No hay modelos descargados"
    echo -e "    → Ejecuta: ${CYAN}ollama pull qwen2.5:7b${NC}"
    ISSUES=$((ISSUES + 1))
  fi
fi

# ── Variables de entorno ────────────────────────────────────────────────────
echo ""
if [[ "${PM_EMERGENCY_MODE:-}" == "active" ]]; then
  echo -e "  ${GREEN}✓${NC} Modo emergencia: ${BOLD}ACTIVO${NC}"
  echo -e "    ANTHROPIC_BASE_URL=${CYAN}${ANTHROPIC_BASE_URL:-no configurado}${NC}"
  echo -e "    PM_EMERGENCY_MODEL=${CYAN}${PM_EMERGENCY_MODEL:-no configurado}${NC}"
else
  echo -e "  ${YELLOW}○${NC} Modo emergencia: INACTIVO"
  echo -e "    → Para activar: ${CYAN}source ~/.pm-workspace-emergency.env${NC}"
fi

# ── Hardware ────────────────────────────────────────────────────────────────
echo ""
RAM_KB=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}' || sysctl -n hw.memsize 2>/dev/null | awk '{print int($1/1024)}' || echo 0)
RAM_GB=$((RAM_KB / 1024 / 1024))
RAM_USED_KB=$(grep MemAvailable /proc/meminfo 2>/dev/null | awk '{print $2}' || echo 0)
RAM_FREE_GB=$((RAM_USED_KB / 1024 / 1024))
echo -e "  RAM total: ${BOLD}${RAM_GB}GB${NC} · Libre: ${BOLD}${RAM_FREE_GB}GB${NC}"

if command -v nvidia-smi &>/dev/null; then
  GPU=$(nvidia-smi --query-gpu=name,memory.used,memory.total --format=csv,noheader 2>/dev/null | head -1)
  echo -e "  GPU: ${BOLD}$GPU${NC}"
fi

# ── Resumen ─────────────────────────────────────────────────────────────────
echo ""
if [[ $ISSUES -eq 0 ]]; then
  echo -e "${GREEN}${BOLD}Sistema listo para modo emergencia.${NC}"
else
  echo -e "${YELLOW}${BOLD}$ISSUES problema(s) detectado(s). Revisa las sugerencias arriba.${NC}"
fi
echo ""
