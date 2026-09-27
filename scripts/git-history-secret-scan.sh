#!/usr/bin/env bash
# SE-239 — Git history secret scanning
# Escanea el historial git completo (o un rango) con gitleaks.
# Uso: bash scripts/git-history-secret-scan.sh [--since <ref>] [--repo <path>]
# Exit codes: 0=clean, 1=CRITICAL/HIGH findings, 2=MEDIUM/LOW only
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DATE_TAG="$(date +%Y%m%d)"
OUTPUT_DIR="$REPO_ROOT/output/security"
GITLEAKS_CONFIG="$REPO_ROOT/.gitleaks.toml"

SINCE=""
TARGET_REPO="$REPO_ROOT"

# ── Parámetros ────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --since) SINCE="$2"; shift 2 ;;
    --repo)  TARGET_REPO="$2"; shift 2 ;;
    --help|-h)
      echo "Uso: bash git-history-secret-scan.sh [--since <git-ref|date>] [--repo <path>]"
      echo "  --since  Limitar al rango desde la ref dada (ej: HEAD~50, 2026-01-01, v1.0)"
      echo "  --repo   Repo a escanear (default: repositorio actual)"
      echo ""
      echo "Exit codes: 0=limpio, 1=CRITICAL/HIGH, 2=solo MEDIUM/LOW"
      exit 0 ;;
    *) echo "Parámetro desconocido: $1" >&2; exit 1 ;;
  esac
done

# ── 1. Verificar que output/security/ está en .gitignore ─────────────────────
GITIGNORE="$TARGET_REPO/.gitignore"
if [[ -f "$GITIGNORE" ]]; then
  if ! grep -qE '^output/' "$GITIGNORE" && ! grep -qE '^output/security' "$GITIGNORE"; then
    echo "ERROR: output/security/ no está en .gitignore del repo." >&2
    echo "  Añade 'output/' al .gitignore antes de escribir reports de seguridad." >&2
    echo "  Para forzar (sin garantías de confidencialidad): use --force (no implementado)." >&2
    exit 3
  fi
fi

# ── 2. Verificar gitleaks ─────────────────────────────────────────────────────
if ! command -v gitleaks &>/dev/null; then
  echo "ERROR: gitleaks no está instalado." >&2
  echo "" >&2
  echo "Instalación:" >&2
  echo "  # macOS:" >&2
  echo "  brew install gitleaks" >&2
  echo "" >&2
  echo "  # Linux (binario precompilado):" >&2
  echo "  VERSION=8.18.4" >&2
  echo '  curl -sSL "https://github.com/gitleaks/gitleaks/releases/download/v${VERSION}/gitleaks_${VERSION}_linux_x64.tar.gz" | tar xz -C /usr/local/bin gitleaks' >&2
  echo "" >&2
  echo "  # Docker (alternativa offline):" >&2
  echo '  docker run --rm -v "$(pwd):/path" zricethezav/gitleaks:latest detect --source /path' >&2
  exit 1
fi

# ── 3. Preparar directorio de output ─────────────────────────────────────────
mkdir -p "$OUTPUT_DIR"
REPORT_JSONL="$OUTPUT_DIR/history-scan-${DATE_TAG}.jsonl"
REPORT_SUMMARY="$OUTPUT_DIR/history-scan-${DATE_TAG}-summary.md"

# ── 4. Construir argumentos de rango ─────────────────────────────────────────
LOG_ARGS=()
if [[ -n "$SINCE" ]]; then
  # Intentar interpretar como ref git o como fecha
  if git -C "$TARGET_REPO" rev-parse "$SINCE" &>/dev/null; then
    LOG_ARGS=(--log-opts="${SINCE}..HEAD")
  else
    LOG_ARGS=(--log-opts="--since=${SINCE}")
  fi
fi

# ── 5. Ejecutar gitleaks ──────────────────────────────────────────────────────
TOML_ARGS=()
if [[ -f "$GITLEAKS_CONFIG" ]]; then
  TOML_ARGS=(--config "$GITLEAKS_CONFIG")
fi

TMPFILE="$(mktemp /tmp/gitleaks-history-XXXXXX.json)"
trap 'rm -f "$TMPFILE"' EXIT

echo "[history-scan] Escaneando historial de: $TARGET_REPO"
[[ -n "$SINCE" ]] && echo "[history-scan] Rango: desde $SINCE"
echo "[history-scan] Report: $REPORT_JSONL"
echo ""

gitleaks detect \
  --source "$TARGET_REPO" \
  "${LOG_ARGS[@]}" \
  --report-format json \
  --report-path "$TMPFILE" \
  "${TOML_ARGS[@]}" \
  --no-banner \
  --exit-code 1 \
  2>/dev/null
GITLEAKS_EXIT=$?

# ── 6. Procesar findings ──────────────────────────────────────────────────────
if [[ $GITLEAKS_EXIT -eq 0 ]]; then
  echo "[history-scan] OK — sin findings en el historial."
  # Report vacío
  cat > "$REPORT_SUMMARY" <<EOF
# Git History Secret Scan — ${DATE_TAG}

**Repo**: ${TARGET_REPO}
**Rango**: ${SINCE:-completo}
**Resultado**: LIMPIO — 0 findings

Generado por SE-239 · $(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF
  exit 0
fi

# Clasificación y escritura de report
python3 - "$TMPFILE" "$REPORT_JSONL" "$REPORT_SUMMARY" "$TARGET_REPO" "$SINCE" <<'PYEOF'
import json, sys, re
from datetime import datetime, timezone

tmpfile, report_jsonl, report_summary, repo, since = sys.argv[1:]

def classify(finding):
    rule = (finding.get("RuleID") or "").lower()
    desc = (finding.get("Description") or "").lower()
    text = rule + " " + desc
    if any(k in text for k in ["aws", "gcp", "azure", "github_pat", "private_key", "rsa", "api_key", "token"]):
        return "CRITICAL"
    if any(k in text for k in ["password", "passwd", "secret", "cert", "credential"]):
        return "HIGH"
    if any(k in text for k in ["uri", "url", "connection_string", "dsn"]):
        return "MEDIUM"
    return "LOW"

try:
    findings = json.load(open(tmpfile)) or []
except Exception:
    findings = []

counts = {"CRITICAL": 0, "HIGH": 0, "MEDIUM": 0, "LOW": 0}
with open(report_jsonl, "w") as out:
    for f in findings:
        sev = classify(f)
        counts[sev] += 1
        f["severity"] = sev
        f["scan_ts"] = datetime.now(timezone.utc).isoformat()
        # Nunca escribir el valor del secret en el report público
        f.pop("Secret", None)
        f.pop("Match", None)
        out.write(json.dumps(f) + "\n")

total = sum(counts.values())
with open(report_summary, "w") as md:
    md.write(f"# Git History Secret Scan — {datetime.now().strftime('%Y-%m-%d')}\n\n")
    md.write(f"**Repo**: {repo}\n")
    md.write(f"**Rango**: {since if since else 'historial completo'}\n")
    md.write(f"**Total findings**: {total}\n\n")
    md.write("## Por severidad\n\n")
    md.write("| Severidad | Findings |\n|---|---|\n")
    for sev in ["CRITICAL", "HIGH", "MEDIUM", "LOW"]:
        md.write(f"| {sev} | {counts[sev]} |\n")
    md.write("\n## Detalle (sin valores de secrets)\n\n")
    for f in (json.loads(l) for l in open(report_jsonl)):
        rule  = f.get("RuleID", "unknown")
        fpath = f.get("File", "?")
        line  = f.get("StartLine", "?")
        commit = (f.get("Commit") or "")[:8] or "staged"
        sev   = f.get("severity", "LOW")
        md.write(f"- **[{sev}]** `{rule}` — `{fpath}:{line}` commit `{commit}`\n")
    md.write(f"\n_Generado por SE-239 · {datetime.now(timezone.utc).isoformat()}_\n")

# Exit code: 1 si CRITICAL/HIGH, 2 si solo MEDIUM/LOW
if counts["CRITICAL"] > 0 or counts["HIGH"] > 0:
    sys.exit(1)
elif counts["MEDIUM"] > 0 or counts["LOW"] > 0:
    sys.exit(2)
else:
    sys.exit(0)
PYEOF
PYEXIT=$?

echo ""
echo "[history-scan] Report JSONL: $REPORT_JSONL"
echo "[history-scan] Summary:      $REPORT_SUMMARY"
echo "[history-scan] Para remediar: bash scripts/git-history-secret-remediate.sh --commit <hash> --file <path>"

exit $PYEXIT
