#!/bin/bash
# shield-autostart.sh — Garantiza que Savia Shield proxy (Capa 0) este up.
# Fire-and-forget: lanza shield-launcher en background si 8443 no responde.
# Espera max 3s a que proxy responda antes de ceder. NO bloquea mas alla.
set -uo pipefail
read -r -t 0.1 _HOOK_INPUT 2>/dev/null || true

# Salida limpia si algo falla
trap 'printf "{\"hookSpecificOutput\":{\"hookEventName\":\"SessionStart\",\"additionalContext\":\"Shield autostart: ERR line %s\"}}\n" "$LINENO"; exit 0' ERR

# Respeta el toggle global de Shield
if [ "${SAVIA_SHIELD_ENABLED:-true}" = "false" ]; then
  exit 0
fi

PROXY_PORT=8443
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"

# Check rapido: proxy responde?
if curl -sf --max-time 1 "http://127.0.0.1:${PROXY_PORT}/health" >/dev/null 2>&1; then
  exit 0
fi

# Proxy caido -> lanzar launcher en background (usa DETACHED_PROCESS en Windows)
LAUNCHER="$PROJECT_DIR/scripts/shield-launcher.py"
if [ ! -f "$LAUNCHER" ]; then
  printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"Shield: launcher no encontrado"}}\n'
  exit 0
fi

# Lanzar detached, redirigir todo output
python3 "$LAUNCHER" start >/dev/null 2>&1 &

# Esperar max 3s a que proxy responda (suficiente para proxy; daemon puede tardar mas)
for i in 1 2 3 4 5 6; do
  sleep 0.5
  if curl -sf --max-time 1 "http://127.0.0.1:${PROXY_PORT}/health" >/dev/null 2>&1; then
    printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"Shield proxy levantado (%ss)"}}\n' "$((i*5/10))"
    exit 0
  fi
done

# Proxy no respondio a tiempo -> aviso pero no bloquea
printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"Shield proxy no respondio en 3s (puede estar arrancando NER daemon)"}}\n'
exit 0
