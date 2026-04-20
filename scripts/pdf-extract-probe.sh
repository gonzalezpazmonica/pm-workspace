#!/usr/bin/env bash
# pdf-extract-probe.sh — SPEC-102 Slice 1 feasibility probe.
#
# Check preconditions para integrar opendataloader-pdf como engine de
# extracción de PDFs. Emite report con:
#   - Java version check (required ≥11)
#   - Maven/Gradle availability
#   - Existing pdf-digest engine (PyMuPDF) version
#   - Sample PDF test (si existe)
#   - Veredicto: VIABLE / BLOCKED / NEEDS_JAVA
#
# NO descarga el JAR de opendataloader ni ejecuta conversión — solo
# emite preconditions report. El descarga/install queda al usuario.
#
# Usage:
#   pdf-extract-probe.sh
#   pdf-extract-probe.sh --sample path/to/test.pdf
#   pdf-extract-probe.sh --json
#
# Exit codes:
#   0 — VIABLE (Java ≥11 present)
#   1 — BLOCKED (missing critical prereq)
#   2 — usage error
#
# Ref: SPEC-102 Slice 1, ROADMAP §Tier 4.4
# Safety: read-only, set -uo pipefail. No download / no install.

set -uo pipefail

SAMPLE=""
JSON=0

usage() {
  cat <<EOF
Usage:
  $0 [--sample PDF] [--json]

  --sample PDF    Optional sample PDF for engine availability check
  --json          Output JSON

Emit preconditions report for SPEC-102 opendataloader-pdf adoption.
NO instala ni descarga JARs. Solo reporta estado de entorno.

Ref: SPEC-102 §Arquitectura, ROADMAP §Tier 4.4
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sample) SAMPLE="$2"; shift 2 ;;
    --json) JSON=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown arg '$1'" >&2; exit 2 ;;
  esac
done

[[ -n "$SAMPLE" && ! -f "$SAMPLE" ]] && { echo "ERROR: sample not found: $SAMPLE" >&2; exit 2; }

# Collect signals.
JAVA_VERSION=""
JAVA_MAJOR=0
JAVA_PATH=""
if command -v java >/dev/null 2>&1; then
  JAVA_PATH=$(command -v java)
  JAVA_VERSION=$(java -version 2>&1 | head -1 | sed -E 's/.*version "([^"]+)".*/\1/')
  # Extract major (handles 1.8 / 11 / 17 / 21).
  JAVA_MAJOR=$(echo "$JAVA_VERSION" | awk -F. '{ if ($1 == "1") print $2; else print $1 }')
fi

MAVEN_OK=0
command -v mvn >/dev/null 2>&1 && MAVEN_OK=1
GRADLE_OK=0
command -v gradle >/dev/null 2>&1 && GRADLE_OK=1

# PyMuPDF current engine.
PYMUPDF_VERSION=""
if command -v python3 >/dev/null 2>&1; then
  PYMUPDF_VERSION=$(python3 -c "import pymupdf; print(pymupdf.__version__)" 2>/dev/null || \
                    python3 -c "import fitz; print(fitz.__version__)" 2>/dev/null || echo "")
fi

# Sample PDF check (just size + first-byte magic).
SAMPLE_OK=0
SAMPLE_SIZE=0
if [[ -n "$SAMPLE" ]]; then
  SAMPLE_SIZE=$(stat -c%s "$SAMPLE" 2>/dev/null || echo 0)
  # Verify PDF magic bytes %PDF.
  if head -c 4 "$SAMPLE" 2>/dev/null | grep -q '%PDF'; then
    SAMPLE_OK=1
  fi
fi

# Verdict.
VERDICT="VIABLE"
EXIT_CODE=0
REASONS=()

if [[ "$JAVA_MAJOR" -lt 11 ]]; then
  VERDICT="NEEDS_JAVA"
  EXIT_CODE=1
  REASONS+=("Java ≥11 required for opendataloader-pdf, found '$JAVA_VERSION' (major=$JAVA_MAJOR)")
fi

if [[ -z "$JAVA_VERSION" ]]; then
  VERDICT="BLOCKED"
  EXIT_CODE=1
  REASONS+=("Java not installed — opendataloader-pdf requires JDK")
fi

# Write report.
if [[ "$JSON" -eq 1 ]]; then
  reasons_json=""
  for r in "${REASONS[@]}"; do
    r_esc=$(echo "$r" | sed 's/"/\\"/g')
    reasons_json+="\"$r_esc\","
  done
  reasons_json="${reasons_json%,}"
  cat <<JSON
{"verdict":"$VERDICT","java_version":"$JAVA_VERSION","java_major":$JAVA_MAJOR,"java_path":"$JAVA_PATH","maven_ok":$MAVEN_OK,"gradle_ok":$GRADLE_OK,"pymupdf_version":"$PYMUPDF_VERSION","sample_provided":$(if [[ -n "$SAMPLE" ]]; then echo true; else echo false; fi),"sample_valid":$(if [[ "$SAMPLE_OK" -eq 1 ]]; then echo true; else echo false; fi),"sample_size_bytes":$SAMPLE_SIZE,"reasons":[$reasons_json]}
JSON
else
  echo "=== SPEC-102 opendataloader-pdf Feasibility Probe ==="
  echo ""
  echo "Java:"
  if [[ -z "$JAVA_VERSION" ]]; then
    echo "  ❌ not installed"
  else
    echo "  path:    $JAVA_PATH"
    echo "  version: $JAVA_VERSION (major=$JAVA_MAJOR)"
    if [[ "$JAVA_MAJOR" -ge 11 ]]; then
      echo "  status:  ✅ meets requirement (≥11)"
    else
      echo "  status:  ❌ below requirement (≥11 needed)"
    fi
  fi
  echo ""
  echo "Build tools:"
  echo "  maven:  $(if [[ "$MAVEN_OK" -eq 1 ]]; then echo '✅'; else echo '(not found, optional)'; fi)"
  echo "  gradle: $(if [[ "$GRADLE_OK" -eq 1 ]]; then echo '✅'; else echo '(not found, optional)'; fi)"
  echo ""
  echo "Current pdf-digest engine (PyMuPDF):"
  if [[ -z "$PYMUPDF_VERSION" ]]; then
    echo "  not installed"
  else
    echo "  pymupdf: $PYMUPDF_VERSION"
  fi
  echo ""
  if [[ -n "$SAMPLE" ]]; then
    echo "Sample PDF:"
    echo "  path:  $SAMPLE"
    echo "  size:  $SAMPLE_SIZE bytes"
    echo "  valid: $(if [[ "$SAMPLE_OK" -eq 1 ]]; then echo '✅ (PDF magic OK)'; else echo '❌ (bad magic)'; fi)"
    echo ""
  fi
  echo "VERDICT: $VERDICT"
  for r in "${REASONS[@]}"; do
    echo "  • $r"
  done
  echo ""
  if [[ "$VERDICT" == "VIABLE" ]]; then
    echo "Next steps (manual, out of scope for this probe):"
    echo "  1. Download opendataloader JAR from official release"
    echo "  2. Create scripts/pdf-extract.sh wrapper (Python calling JAR)"
    echo "  3. Add --engine flag to pdf-digest agent"
  elif [[ "$VERDICT" == "NEEDS_JAVA" ]]; then
    echo "To unblock:"
    echo "  sudo apt install openjdk-17-jre   # Ubuntu/Debian"
    echo "  brew install openjdk@17            # macOS"
  else
    echo "Blocked. Install Java 11+ first."
  fi
fi

exit $EXIT_CODE
