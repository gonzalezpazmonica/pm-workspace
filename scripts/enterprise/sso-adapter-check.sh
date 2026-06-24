#!/usr/bin/env bash
# sso-adapter-check.sh — SPEC-SE-007: Verifica la configuración del SSO/SAML adapter
#
# Comprueba si el proveedor SSO/SAML está configurado y accesible.
# En entornos sin SSO (single-tenant local), devuelve sso_not_configured=true.
#
# Usage:
#   sso-adapter-check.sh [--provider PROVIDER]
#
# Providers:
#   okta         Okta SAML/OIDC
#   azure-ad     Microsoft Entra ID (Azure AD) SAML/OIDC
#   generic-saml SAML 2.0 genérico
#
# Output JSON (stdout):
#   {
#     "provider": "okta",
#     "reachable": true,
#     "cert_valid": true,
#     "acs_configured": true
#   }
#   -- o en entorno sin SSO --
#   {"sso_not_configured": true, "message": "..."}
#
# Configuración esperada (env vars o .claude/enterprise/sso.yaml):
#   SSO_PROVIDER_URL   SAML metadata URL del IdP
#   SSO_ACS_URL        Assertion Consumer Service URL
#   SSO_CERT_PATH      Path al certificado SAML (PEM)
#
# Ref: docs/propuestas/savia-enterprise/SPEC-SE-007-enterprise-onboarding.md

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

PROVIDER="generic-saml"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --provider) PROVIDER="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,28p' "${BASH_SOURCE[0]}" | sed 's/^# //; s/^#//'
      exit 0 ;;
    *) echo "ERROR: unknown arg: $1" >&2; exit 2 ;;
  esac
done

VALID_PROVIDERS="okta azure-ad generic-saml"
if [[ " $VALID_PROVIDERS " != *" $PROVIDER "* ]]; then
  echo "ERROR: invalid provider '$PROVIDER'. Must be one of: $VALID_PROVIDERS" >&2; exit 2
fi

# ── Leer configuración SSO ────────────────────────────────────────────────────

SSO_CONFIG="${ROOT_DIR}/.claude/enterprise/sso.yaml"

# Intentar leer env vars o config file
SSO_PROVIDER_URL="${SSO_PROVIDER_URL:-}"
SSO_ACS_URL="${SSO_ACS_URL:-}"
SSO_CERT_PATH="${SSO_CERT_PATH:-}"

# Si existe sso.yaml, extraer valores
if [[ -f "$SSO_CONFIG" ]]; then
  [[ -z "$SSO_PROVIDER_URL" ]] && SSO_PROVIDER_URL=$(grep "provider_url:" "$SSO_CONFIG" 2>/dev/null \
    | head -1 | sed 's/.*provider_url:[[:space:]]*//' | tr -d '"' || echo "")
  [[ -z "$SSO_ACS_URL" ]] && SSO_ACS_URL=$(grep "acs_url:" "$SSO_CONFIG" 2>/dev/null \
    | head -1 | sed 's/.*acs_url:[[:space:]]*//' | tr -d '"' || echo "")
  [[ -z "$SSO_CERT_PATH" ]] && SSO_CERT_PATH=$(grep "cert_path:" "$SSO_CONFIG" 2>/dev/null \
    | head -1 | sed 's/.*cert_path:[[:space:]]*//' | tr -d '"' || echo "")
fi

# ── Detectar si SSO está configurado ─────────────────────────────────────────

if [[ -z "$SSO_PROVIDER_URL" && -z "$SSO_ACS_URL" && ! -f "$SSO_CONFIG" ]]; then
  # Entorno sin SSO (single-tenant local)
  cat <<JSONEOF
{
  "sso_not_configured": true,
  "provider": "${PROVIDER}",
  "message": "SSO no configurado en este entorno. Para configurar: establece SSO_PROVIDER_URL, SSO_ACS_URL y SSO_CERT_PATH, o crea .claude/enterprise/sso.yaml. Ref: SPEC-SE-007."
}
JSONEOF
  exit 0
fi

# ── Verificar conectividad al IdP ─────────────────────────────────────────────

REACHABLE="false"
CERT_VALID="false"
ACS_CONFIGURED="false"

# Check 1: metadata URL accesible
if [[ -n "$SSO_PROVIDER_URL" ]]; then
  if command -v curl >/dev/null 2>&1; then
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
      --connect-timeout 5 --max-time 10 \
      "$SSO_PROVIDER_URL" 2>/dev/null) || HTTP_STATUS="0"
    if [[ "$HTTP_STATUS" == "200" || "$HTTP_STATUS" == "302" ]]; then
      REACHABLE="true"
    fi
  else
    # curl no disponible — no podemos verificar
    REACHABLE="false"
  fi
fi

# Check 2: certificado válido (si existe)
if [[ -n "$SSO_CERT_PATH" ]] && [[ -f "$SSO_CERT_PATH" ]]; then
  if command -v openssl >/dev/null 2>&1; then
    CERT_EXPIRY=$(openssl x509 -enddate -noout -in "$SSO_CERT_PATH" 2>/dev/null \
      | sed 's/notAfter=//' || echo "")
    if [[ -n "$CERT_EXPIRY" ]]; then
      # Verificar que no ha expirado
      EXPIRY_EPOCH=$(date -d "$CERT_EXPIRY" +%s 2>/dev/null || echo 0)
      NOW_EPOCH=$(date +%s)
      [[ $EXPIRY_EPOCH -gt $NOW_EPOCH ]] && CERT_VALID="true"
    fi
  fi
fi

# Check 3: ACS URL configurada
[[ -n "$SSO_ACS_URL" ]] && ACS_CONFIGURED="true"

# ── Output JSON ───────────────────────────────────────────────────────────────

cat <<JSONEOF
{
  "provider": "${PROVIDER}",
  "reachable": ${REACHABLE},
  "cert_valid": ${CERT_VALID},
  "acs_configured": ${ACS_CONFIGURED},
  "provider_url": "${SSO_PROVIDER_URL}",
  "acs_url": "${SSO_ACS_URL}"
}
JSONEOF
