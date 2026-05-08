#!/usr/bin/env bash
# savia-shield-status.sh — Status determinístico de las 8 capas de Savia Shield
# Output: una sola línea por capa, ya resuelta (sin placeholders).
# Códigos de salida:
#   0  = todas las capas activas
#   1  = al menos una capa en ⚠️ (degradado)
#   2  = al menos una capa en ❌ (rota)

set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/savia-env.sh"
PROJECT_DIR="${SAVIA_WORKSPACE_DIR:-$(pwd)}"
SETTINGS="$PROJECT_DIR/.claude/settings.local.json"

# ── Estado global ───────────────────────────────────────────────────────────
SHIELD_ENABLED=""
if [ -f "$SETTINGS" ]; then
  SHIELD_ENABLED=$(grep -o '"SAVIA_SHIELD_ENABLED"[[:space:]]*:[[:space:]]*"[^"]*"' "$SETTINGS" 2>/dev/null | cut -d'"' -f4)
fi
if [ "$SHIELD_ENABLED" = "true" ]; then
  GLOBAL="✅ ACTIVADO"
elif [ "$SHIELD_ENABLED" = "false" ]; then
  GLOBAL="⛔ DESACTIVADO"
else
  GLOBAL="✅ ACTIVADO (default)"
fi

# ── Health checks ───────────────────────────────────────────────────────────
DAEMON_RESP=$(curl -sf --max-time 3 http://127.0.0.1:8444/health 2>/dev/null || true)
# Proxy es single-threaded (BaseHTTP): reintenta hasta 3 veces con pausa
PROXY_RESP=""
for _i in 1 2 3; do
  PROXY_RESP=$(curl -sf --max-time 5 http://127.0.0.1:8443/health 2>/dev/null || true)
  [ -n "$PROXY_RESP" ] && break
  sleep 1
done
OLLAMA_RESP=$(curl -sf --max-time 3 http://127.0.0.1:11434/api/tags 2>/dev/null || true)

DAEMON_NER=""
if [ -n "$DAEMON_RESP" ]; then
  DAEMON_NER=$(echo "$DAEMON_RESP" | grep -o '"ner"[[:space:]]*:[[:space:]]*[a-z]*' | awk -F: '{print $2}' | tr -d ' ')
  DAEMON_LINE="✅ activo (NER: ${DAEMON_NER:-unknown})"
else
  DAEMON_LINE="⚠️ no disponible (fallback regex)"
fi

if [ -n "$PROXY_RESP" ]; then
  PROXY_ENT=$(echo "$PROXY_RESP" | grep -o '"entities_loaded"[[:space:]]*:[[:space:]]*[0-9]*' | grep -o '[0-9]*$')
  PROXY_LINE="✅ activo (${PROXY_ENT:-?} entidades)"
else
  PROXY_LINE="⚠️ no disponible"
fi

if [ -n "$OLLAMA_RESP" ] && echo "$OLLAMA_RESP" | grep -q "qwen2.5:7b"; then
  OLLAMA_LINE="✅ activo (qwen2.5:7b)"
elif [ -n "$OLLAMA_RESP" ]; then
  OLLAMA_LINE="⚠️ activo pero sin qwen2.5:7b"
else
  OLLAMA_LINE="⚠️ no disponible"
fi

if [ "$DAEMON_NER" = "true" ]; then
  NER_LINE="✅ ner=true"
else
  NER_LINE="⚠️ no disponible"
fi

# ── Capas (1-8) ─────────────────────────────────────────────────────────────
[ -x "$PROJECT_DIR/.opencode/hooks/data-sovereignty-gate.sh" ] && C1="✅ hook" || C1="❌ falta"
[ "$DAEMON_NER" = "true" ] && C2="✅ Presidio+spaCy via daemon" || C2="⚠️ no disponible"
if [ -n "$OLLAMA_RESP" ] && echo "$OLLAMA_RESP" | grep -q "qwen2.5:7b"; then
  C3="✅ qwen2.5:7b activo"
else
  C3="⚠️ no disponible"
fi
[ -n "$PROXY_RESP" ] && C4="✅ savia-shield-proxy.py (8443)" || C4="⚠️ no disponible"
[ -x "$PROJECT_DIR/.opencode/hooks/data-sovereignty-audit.sh" ] && C5="✅ hook" || C5="❌ falta"
[ -x "$PROJECT_DIR/.opencode/hooks/block-force-push.sh" ] && C6="✅ hook" || C6="❌ falta"
C7="➖ removido (Capa 4 Proxy tiene masking interno)"
if grep -q 'base64.b64decode' "$PROJECT_DIR/scripts/savia-shield-daemon.py" 2>/dev/null; then
  C8="✅ integrado en daemon"
else
  C8="⚠️ no disponible"
fi

# ── Output ──────────────────────────────────────────────────────────────────
cat <<EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🛡️  Savia Shield — Estado
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Estado global ......... $GLOBAL
Daemon (8444) ......... $DAEMON_LINE
Proxy (8443) .......... $PROXY_LINE
Ollama (11434) ........ $OLLAMA_LINE
NER (en daemon) ....... $NER_LINE

Capas (1-8):
  1 Regex Gate ........ $C1
  2 NER Filter ........ $C2
  3 Ollama Classifier . $C3
  4 Proxy Interceptor . $C4
  5 Audit Logger ...... $C5
  6 Security Hooks .... $C6
  7 [removido] ........ $C7
  8 Base64 Decoder .... $C8
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

# Determinar exit code
ALL="$C1 $C2 $C3 $C4 $C5 $C6 $C7 $C8 $DAEMON_LINE $PROXY_LINE $OLLAMA_LINE $NER_LINE"
case "$ALL" in
  *❌*) exit 2 ;;
  *⚠️*) exit 1 ;;
  *)    exit 0 ;;
esac
