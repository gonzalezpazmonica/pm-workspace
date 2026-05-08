#!/bin/bash
set -uo pipefail
# block-credential-leak.sh — Detecta credentials en comandos y ficheros
# Usado por: security-guardian (PreToolUse hook)
# Profile tier: security

LIB_DIR="$(dirname "${BASH_SOURCE[0]}")/lib"
if [[ -f "$LIB_DIR/profile-gate.sh" ]]; then
  # shellcheck source=/dev/null
  source "$LIB_DIR/profile-gate.sh" && profile_gate "security"
fi

# Read stdin with timeout to avoid hanging if no input arrives
# Uses timeout+cat to handle input that may lack trailing newline
INPUT=""
if INPUT=$(timeout 3 cat 2>/dev/null); then
  :
fi

# Require jq for safe JSON parsing
if ! command -v jq &>/dev/null; then
  echo "ADVERTENCIA: jq no está instalado. Instala jq para activar detección de secrets." >&2
  exit 0
fi
COMMAND=""
if [[ -n "$INPUT" ]]; then
  COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null) || COMMAND=""
fi

if [ -z "$COMMAND" ]; then
  exit 0
fi

# Patrones de secrets comunes
SECRETS_PATTERN='(password|passwd|secret|api[_-]?key|token|bearer|auth[_-]?token|private[_-]?key|connection[_-]?string|client[_-]?secret)=["\x27]?[A-Za-z0-9+/=_-]{8,}'

# Detectar secrets hardcodeados en comandos
if echo "$COMMAND" | grep -iEo "$SECRETS_PATTERN" > /dev/null 2>&1; then
  echo "BLOQUEADO: Posible secret detectado en el comando. Usa variables de entorno o vault." >&2
  exit 2
fi

# Detectar AWS Access Keys (AKIA...)
if echo "$COMMAND" | grep -iE 'AKIA[0-9A-Z]{16}' > /dev/null 2>&1; then
  echo "BLOQUEADO: AWS Access Key detectada. Usa env var AWS_ACCESS_KEY_ID o vault." >&2
  exit 2
fi

# Detectar GitHub tokens (ghp_, ghs_, ghu_)
if echo "$COMMAND" | grep -iE '(ghp_|ghs_|ghu_|ghr_)[A-Za-z0-9]{36,}' > /dev/null 2>&1; then
  echo "BLOQUEADO: GitHub token detectado. Usa variables de entorno o vault." >&2
  exit 2
fi

# Detectar OpenAI keys (sk-)
if echo "$COMMAND" | grep -iE 'sk-[A-Za-z0-9]{48,}' > /dev/null 2>&1; then
  echo "BLOQUEADO: OpenAI API key detectada. Usa variables de entorno o vault." >&2
  exit 2
fi

# Detectar Azure connection strings
if echo "$COMMAND" | grep -iE '(DefaultEndpointsProtocol|AccountKey=|SharedAccessKey=)' > /dev/null 2>&1; then
  echo "BLOQUEADO: Azure connection string detectada. Usa Key Vault o variables de entorno." >&2
  exit 2
fi

# Detectar JWT tokens — formato base64url(header).base64url(payload).base64url(signature)
# JWTs reales empiezan SIEMPRE con eyJ (base64 de '{"' del JSON header/payload).
# Sin esta restricción, cualquier path Python como `importlib.util.spec_from_file_location` matchea.
# Falsos positivos típicos evitados: módulos Python con 3 dotted identifiers, paquetes Java/C#, versiones x.y.z.
if echo "$COMMAND" | grep -E 'eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{20,}' > /dev/null 2>&1; then
  echo "BLOQUEADO: JWT token sospechoso detectado. Usa variables de entorno o vault." >&2
  exit 2
fi

# Detectar PAT hardcodeado (Azure DevOps / GitHub)
if echo "$COMMAND" | grep -iE '(pat|token)\s*[:=]\s*["\x27]?[a-z0-9]{40,}' > /dev/null 2>&1; then
  echo "BLOQUEADO: PAT/token hardcodeado detectado. Usa \$(cat \$PAT_FILE) o vault." >&2
  exit 2
fi

# Detectar private keys (PEM headers)
if echo "$COMMAND" | grep -E -- '-----BEGIN.*(RSA |EC |OPENSSH |PGP )?PRIVATE KEY-----' > /dev/null 2>&1; then
  echo "BLOQUEADO: Private key detectada. Usa vault o config.local/." >&2
  exit 2
fi

# Detectar Azure SAS tokens (sv=20XX)
if echo "$COMMAND" | grep -iE 'sv=20[0-9]{2}-[0-9]{2}-[0-9]{2}&s[a-z]=' > /dev/null 2>&1; then
  echo "BLOQUEADO: Azure SAS token detectado. Usa Key Vault o variables de entorno." >&2
  exit 2
fi

# Detectar Google API keys (AIza...)
if echo "$COMMAND" | grep -iE 'AIza[0-9A-Za-z_-]{35}' > /dev/null 2>&1; then
  echo "BLOQUEADO: Google API key detectada. Usa variables de entorno o vault." >&2
  exit 2
fi

# Detectar echo de secrets a ficheros
if echo "$COMMAND" | grep -iE 'echo\s+.*secret.*>>' > /dev/null 2>&1; then
  echo "BLOQUEADO: No escribir secrets en ficheros. Usa config.local/ o vault." >&2
  exit 2
fi

# Detectar Kubernetes service account tokens
if echo "$COMMAND" | grep -iE 'eyJhbGciOiJSUzI1NiI' > /dev/null 2>&1; then
  echo "BLOQUEADO: Kubernetes service account token detectado. Usa ServiceAccount o vault." >&2
  exit 2
fi

# Detectar HashiCorp Vault tokens (hvs., s.)
if echo "$COMMAND" | grep -iE '(hvs\.[a-zA-Z0-9_-]{24,}|s\.[a-zA-Z0-9]{24,})' > /dev/null 2>&1; then
  echo "BLOQUEADO: Vault token detectado. Usa VAULT_TOKEN env var." >&2
  exit 2
fi

# Detectar Docker registry credentials
if echo "$COMMAND" | grep -iE '(docker\s+login.*-p\s|--password\s)' > /dev/null 2>&1; then
  echo "BLOQUEADO: Docker password en línea de comandos. Usa --password-stdin o credential helper." >&2
  exit 2
fi

# Detectar Anthropic API keys (sk-ant-)
if echo "$COMMAND" | grep -iE 'sk-ant-[a-zA-Z0-9_-]{20,}' > /dev/null 2>&1; then
  echo "BLOQUEADO: Anthropic API key detectada. Usa ANTHROPIC_API_KEY env var." >&2
  exit 2
fi

exit 0
