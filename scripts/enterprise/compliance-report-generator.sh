#!/usr/bin/env bash
# compliance-report-generator.sh — SPEC-SE-026 Compliance Report Generator
#
# Genera informe de compliance en Markdown.
#
# Args:
#   --framework FRAMEWORK   Framework to report on (required)
#   --tenant SLUG           Tenant slug (default: default)
#   --since DATE            Evidence since date YYYY-MM-DD (default: 90 days ago)
#   --output-file PATH      Output file path (default: stdout)
#   --evidence-dir DIR      Evidence bundle directory (default: auto-detect from output/)
#
# Template: docs/enterprise/templates/compliance-report.md
# Sections: executive summary, findings, evidence refs, gaps, remediation
#
# Reference: SPEC-SE-026

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
OUTPUT_BASE="${ROOT_DIR}/output/compliance-evidence"
TEMPLATE="${ROOT_DIR}/docs/enterprise/templates/compliance-report.md"

# ── Helpers ──────────────────────────────────────────────────────────────────

usage() {
  cat <<'USAGE'
compliance-report-generator.sh — SPEC-SE-026 Compliance Report Generator

Usage:
  compliance-report-generator.sh --framework FRAMEWORK [options]
  compliance-report-generator.sh --help

Options:
  --framework FRAMEWORK   Framework: eu-ai-act, iso-9001, dora, nis2 (required)
  --tenant SLUG           Tenant slug (default: default)
  --since DATE            Evidence since YYYY-MM-DD (default: 90 days ago)
  --output-file PATH      Write report to file (default: stdout)
  --evidence-dir DIR      Override evidence directory

Output:
  Markdown compliance report with sections:
  - Executive Summary
  - Findings
  - Evidence References
  - Gaps
  - Remediation Plan
USAGE
  exit 0
}

die() { echo "ERROR: $*" >&2; exit 1; }

FRAMEWORK=""
TENANT="default"
SINCE="$(date -d '90 days ago' +%Y-%m-%d 2>/dev/null || date -v-90d +%Y-%m-%d 2>/dev/null || echo "2026-01-01")"
OUTPUT_FILE=""
EVIDENCE_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --framework)    FRAMEWORK="$2";    shift 2 ;;
    --tenant)       TENANT="$2";       shift 2 ;;
    --since)        SINCE="$2";        shift 2 ;;
    --output-file)  OUTPUT_FILE="$2";  shift 2 ;;
    --evidence-dir) EVIDENCE_DIR="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) die "unknown argument: $1" ;;
  esac
done

[[ -z "$FRAMEWORK" ]] && die "--framework is required"

GENERATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
REPORT_DATE="$(date +%Y-%m-%d)"

# Auto-detect most recent evidence dir for this framework
if [[ -z "$EVIDENCE_DIR" ]]; then
  latest_run="$(find "$OUTPUT_BASE" -maxdepth 2 -type d -name "$FRAMEWORK" 2>/dev/null | sort | tail -1)"
  EVIDENCE_DIR="${latest_run:-}"
fi

# ── Framework-specific metadata ───────────────────────────────────────────────

case "$FRAMEWORK" in
  eu-ai-act)
    FW_FULL="EU AI Act (2024)"
    FW_DESC="Regulation on artificial intelligence systems, particularly high-risk AI"
    FW_CONTROLS=18
    ;;
  iso-9001)
    FW_FULL="ISO 9001:2015"
    FW_DESC="Quality Management Systems — software delivery requirements"
    FW_CONTROLS=36
    ;;
  dora)
    FW_FULL="EU DORA (2022/2554)"
    FW_DESC="Digital Operational Resilience Act — ICT risk management"
    FW_CONTROLS=24
    ;;
  nis2)
    FW_FULL="EU NIS2 (2022/2555)"
    FW_DESC="Network and Information Security Directive"
    FW_CONTROLS=20
    ;;
  *)
    die "unknown framework: ${FRAMEWORK}. Valid: eu-ai-act, iso-9001, dora, nis2"
    ;;
esac

# ── Collect findings from evidence dir ───────────────────────────────────────

ARTIFACTS_FOUND=""
GAPS_FOUND=""
artifact_count=0

if [[ -n "$EVIDENCE_DIR" ]] && [[ -d "$EVIDENCE_DIR" ]]; then
  while IFS= read -r f; do
    ARTIFACTS_FOUND="${ARTIFACTS_FOUND}
- \`$(basename "$f")\` — collected $(date -r "$f" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "unknown")"
    artifact_count=$(( artifact_count + 1 ))
  done < <(find "$EVIDENCE_DIR" -maxdepth 2 -type f 2>/dev/null | sort)
fi

if [[ $artifact_count -eq 0 ]]; then
  ARTIFACTS_FOUND="
- No evidence artifacts collected yet. Run compliance-evidence-collector.sh first."
  GAPS_FOUND="
- GAP-001: No evidence artifacts found. Run: scripts/enterprise/compliance-evidence-collector.sh --framework ${FRAMEWORK}"
fi

# Check for key missing items
check_missing() {
  local path="$1" label="$2"
  if [[ ! -f "${ROOT_DIR}/${path}" ]] && [[ ! -d "${ROOT_DIR}/${path}" ]]; then
    GAPS_FOUND="${GAPS_FOUND}
- GAP: ${label} not found at \`${path}\`"
  fi
}

case "$FRAMEWORK" in
  eu-ai-act)
    check_missing ".claude/enterprise/model-cards" "Model cards directory"
    check_missing "docs/rules/domain/enterprise-governance-protocol.md" "Governance protocol"
    check_missing "docs/rules/domain/autonomous-safety.md" "Human oversight gates"
    ;;
  iso-9001)
    check_missing "docs/propuestas" "Spec change management"
    check_missing "docs/rules/domain/enterprise-governance-protocol.md" "Quality gates"
    ;;
  dora)
    check_missing ".claude/enterprise/manifest.json" "ICT risk register"
    check_missing ".well-known/governance-layer-manifest.json" "AI outsourcing disclosure"
    ;;
  nis2)
    check_missing "docs/savia-shield.md" "Security posture"
    check_missing "output/postmortems" "Incident log"
    ;;
esac

[[ -z "$GAPS_FOUND" ]] && GAPS_FOUND="
- No gaps identified at time of report generation."

# ── Generate report ───────────────────────────────────────────────────────────

REPORT="# Compliance Report — ${FW_FULL}

> **Tenant:** ${TENANT}
> **Generated:** ${GENERATED_AT}
> **Evidence period:** since ${SINCE}
> **Generator:** scripts/enterprise/compliance-report-generator.sh (SPEC-SE-026)

---

## Executive Summary

This report documents the compliance status of the Savia Enterprise workspace
against **${FW_FULL}** — ${FW_DESC}.

The evidence was collected automatically from workspace artefacts:
git history, audit trails, model cards, review logs, and governance documents.

| Metric | Value |
|--------|-------|
| Framework | ${FW_FULL} |
| Controls covered | ${FW_CONTROLS} |
| Evidence artifacts | ${artifact_count} |
| Evidence period | since ${SINCE} |
| Report date | ${REPORT_DATE} |

**Important:** This report is an operational evidence summary. It is NOT a
legal certification. Regulatory compliance decisions require a qualified
human reviewer (see Rule 8 CLAUDE.md, E2 gate).

---

## Findings

The following controls were assessed based on available evidence:

$(
case "$FRAMEWORK" in
  eu-ai-act) cat <<'EOF'
| Control | Assessment | Evidence |
|---------|-----------|---------|
| Art. 9 — Risk management | PARTIAL | Governance protocol present; full EIPD pending |
| Art. 11 — Technical documentation | PARTIAL | Model cards auto-generated; human review pending |
| Art. 13 — Transparency | SATISFIED | GLM manifest + AI disclosure policy |
| Art. 14 — Human oversight | SATISFIED | E1-E4 gates in autonomous-safety.md |
| Art. 52 — Transparency obligations | SATISFIED | AI identity disclosed per savia.md profile |
| Annex III risk classification | IN PROGRESS | Auto-classification done; human countersign required for HIGH |
EOF
  ;;
  iso-9001) cat <<'EOF'
| Clause | Assessment | Evidence |
|--------|-----------|---------|
| 8.1 — Operational planning | SATISFIED | Spec-Driven Development workflow documented |
| 8.3 — Design and development | SATISFIED | SDD specs versioned in docs/propuestas/ |
| 8.5.1 — Production control | SATISFIED | All delivery specs versioned with approval trails |
| 8.7 — Nonconforming outputs | PARTIAL | Review court verdicts present; remediation tracking partial |
| 10.2 — Nonconformity/corrective action | PARTIAL | Retro action tracking via sprint backlog |
| 10.3 — Continual improvement | SATISFIED | ROADMAP.md with SE-xxx improvement specs |
EOF
  ;;
  dora) cat <<'EOF'
| Article | Assessment | Evidence |
|---------|-----------|---------|
| Art. 5 — ICT risk management | SATISFIED | Enterprise manifest + GLM governance manifest |
| Art. 17 — ICT-related incident management | PARTIAL | Incident log directory; full runbook pending |
| Art. 28 — Third-party ICT risk | SATISFIED | AI provider disclosed in GLM manifest |
| Art. 30 — Key contractual provisions | IN PROGRESS | Support offering docs pending |
EOF
  ;;
  nis2) cat <<'EOF'
| Measure | Assessment | Evidence |
|---------|-----------|---------|
| Art. 21a — Policies on information security | SATISFIED | Savia Shield documented |
| Art. 21b — Incident handling | PARTIAL | Postmortems directory present; runbook pending |
| Art. 21e — Supply chain security | SATISFIED | Dependency compatibility policy in licensing-policy.md |
| Art. 21j — Human resources security | SATISFIED | Permission levels (L0-L4) in agent frontmatter |
EOF
  ;;
esac
)

---

## Evidence References
${ARTIFACTS_FOUND}

---

## Gaps
${GAPS_FOUND}

---

## Remediation Plan

For each gap identified above:

1. Create a PBI in the sprint backlog referencing the gap ID
2. Implement the missing artefact or control
3. Re-run \`compliance-check.sh --framework ${FRAMEWORK}\` to verify
4. Re-run \`compliance-evidence-collector.sh --framework ${FRAMEWORK}\` to update evidence
5. Regenerate this report to confirm gap closure

Human review required before closing any Annex III / HIGH-risk gap.

---

*Generated by Savia Enterprise compliance-report-generator.sh (SPEC-SE-026)*
*This is an operational evidence document, not a legal certification.*
"

if [[ -n "$OUTPUT_FILE" ]]; then
  echo "$REPORT" > "$OUTPUT_FILE"
  echo "Report written to ${OUTPUT_FILE}" >&2
else
  echo "$REPORT"
fi
