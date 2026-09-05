#!/usr/bin/env bash
# guardrail-audit.sh — SE-374: Auditoría de cumplimiento del principio Guardrail
# Pipeline NORMA→DISPARADOR→ENFORCEMENT. FASES A-E (spec §2.1).
# Read-only sobre guardrails (RN-12): escribe SOLO en output/guardrail-audit/.
# Uso: bash scripts/guardrail-audit.sh
set -euo pipefail
cd "$(dirname "$(dirname "${BASH_SOURCE[0]}")")"

OUT="output/guardrail-audit"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
START=$SECONDS
mkdir -p "$OUT"

# RN-12 — snapshot del árbol antes de la auditoría
SNAP_BEFORE=$(git status --porcelain 2>/dev/null | LC_ALL=C sort)

echo "== SE-374 Guardrail Audit =="
echo "-- FASE A+B: inventario y clasificación"
python3 scripts/guardrail-inventory-parse.py --out "$OUT/inventory.json" --rn-out "$TMP/rn-facts.json"

echo "-- Verificación de determinismo (2 runs, mismo commit)"
python3 scripts/guardrail-inventory-parse.py --out "$TMP/inv2.json" --rn-out "$TMP/rn2.json" --quiet
FP1="$(jq -r .content_fingerprint "$OUT/inventory.json")"
FP2="$(jq -r .content_fingerprint "$TMP/inv2.json")"
if [[ "$FP1" == "$FP2" ]] && cmp -s "$TMP/rn-facts.json" "$TMP/rn2.json"; then
  DETERMINISM="OK (fingerprint idéntico en 2 runs)"
else
  DETERMINISM="FALLO: fingerprint difiere entre runs — bug del pipeline (P0 del propio auditor)"
fi

echo "-- FASE C: matriz de cumplimiento (RN-01..RN-12)"
HOOKS=$(jq '[.guardrails[] | select(.type=="hook")] | length' "$OUT/inventory.json")
HOOKS_BLOCK=$(jq '[.guardrails[] | select(.type=="hook" and .layer=="ENFORCEMENT")] | length' "$OUT/inventory.json")
DISP=$(jq '[.guardrails[] | select(.type=="hook" and .layer=="DISPARADOR")] | length' "$OUT/inventory.json")
INFO=$(jq '[.guardrails[] | select(.type=="hook" and .layer=="INFORMATIVO")] | length' "$OUT/inventory.json")
AGENTS=$(jq '[.guardrails[] | select(.type=="agent")] | length' "$OUT/inventory.json")
RULES=$(jq '[.guardrails[] | select(.type=="rule")] | length' "$OUT/inventory.json")
SKILLS=$(jq '[.guardrails[] | select(.type=="skill")] | length' "$OUT/inventory.json")
PROHIB=$(jq '.prohibitions_total' "$TMP/rn-facts.json")

{
  echo "# Matriz de cumplimiento — Guardrail Principle Audit (SE-374)"
  echo
  echo "Commit: $(jq -r .workspace_commit "$OUT/inventory.json") · Fingerprint: \`$FP1\`"
  echo
  echo "## Inventario"
  echo
  echo "| Tipo | Total |"
  echo "|---|---|"
  echo "| hooks (block/ENFORCEMENT) | $HOOKS_BLOCK |"
  echo "| hooks (disparador/warn-log) | $DISP |"
  echo "| hooks (informativo) | $INFO |"
  echo "| agentes | $AGENTS |"
  echo "| normas + constitución | $RULES |"
  echo "| skills | $SKILLS |"
  echo "| **total guardrails** | **$((HOOKS + AGENTS + RULES + SKILLS))** |"
  echo
  echo "Prohibiciones NUNCA/jamás analizadas: $PROHIB. Capas por §2.3: ENFORCEMENT=bloqueo determinista, DISPARADOR=inyección de contexto, NORMA=texto, INFORMATIVO=telemetría."
  echo
  echo "## Cruces RN-01..RN-12"
  echo
  echo "| # | Estado | Resumen | Hallazgos |"
  echo "|---|---|---|---|"
  jq -r '.rn[] | "| " + .rn + " | " + .status + " | " + (.summary | gsub("\\|"; "\\\\|")) + " | " + ((.findings | length) | tostring) + " |"' "$TMP/rn-facts.json"
  echo
  echo "Estados: PASS=cumple · GAP=hallazgos (ver gap-report.md) · DELEGATED=verificada por el orquestador (RN-12, git status antes/después)."
  echo
  echo "## Detalle por regla"
  echo
  jq -r '.rn[] | "### " + .rn + " — " + .status + "\n\n" + .summary + "\n"' "$TMP/rn-facts.json"
  jq -r '.rn[] | select(.findings | length > 0) | .rn as $rn | .findings[] | "- **" + .severity + "** " + (.guardrail | gsub("\\|"; "\\\\|")) + " — " + (.evidence | gsub("\\|"; "\\\\|")) + "\n  Principio: " + (.principle | gsub("\\|"; "\\\\|")) + "\n  Propuesta: " + (.propuesta | gsub("\\|"; "\\\\|")) + "\n"' "$TMP/rn-facts.json"
  echo
  echo "## Metodología y límites"
  echo
  echo "RN-02 empareja prohibición→enforcement por (a) id de regla citado en el hook y (b) solapamiento de tokens con sinónimos sobre nombre/principios del hook. Un GAP puede ser falso positivo del emparejador: validar la propuesta antes de ejecutar. RN-03 acepta gate humano documentado y enlazado en savia-ethical-principles.md. Las capas NORMA/DISPARADOR son probabilísticas por diseño (LEC-1/LEC-2): este informe no vende norma por enforcement."
  echo
  echo "## Referencias"
  echo
  echo "- docs/rules/domain/savia-ethical-principles.md (§1-§15, L1-L5)"
  echo "- .claude/CONSTITUCION.md (ART-01..ART-20)"
  echo "- docs/rules/domain/autonomous-safety.md (double opt-in, SE-332, SE-146)"
  echo "- LEC-1..LEC-4: lecciones guardrails (SPEC-SE-374 §1)"
} > "$OUT/compliance-matrix.md"

echo "-- FASE D: informe de gaps"
P0=$(jq '.severities.P0 // 0' "$TMP/rn-facts.json")
P1=$(jq '.severities.P1 // 0' "$TMP/rn-facts.json")
P2=$(jq '.severities.P2 // 0' "$TMP/rn-facts.json")
{
  echo "# Gap Report — Guardrail Principle Audit (SE-374)"
  echo
  echo "Severidades: **P0=$P0 · P1=$P1 · P2=$P2**. Toda remediación es PROPUESTA — sin ejecución (autonomous-safety, ART-03, RN-12)."
  echo
  echo "| GAP-ID | Severidad | Guardrail | Principio violado | Evidencia (fichero:línea) | Propuesta |"
  echo "|---|---|---|---|---|---|"
  jq -r '.rn[] | .rn as $rn | .findings[] | [($rn + "-" + .severity), .severity, .guardrail, .principle, .evidence, .propuesta] | @tsv' "$TMP/rn-facts.json" \
    | awk -F'\t' '{ n[$1]++; id=$1 sprintf("-%03d", n[$1]); for (i=1;i<=NF;i++) { gsub(/\|/, "\\|", $i) }; printf "| GAP-%s | %s | %s | %s | %s | %s |\n", id, $2, $3, $4, $5, $6 }'
  echo
  echo "Los GAP-ID heredan severidad por regla (RN-02/03/04/10 P0 máximo según §4; RN-06 escala a P0 si la norma es L1-L5 o T3)."
} > "$OUT/gap-report.md"

echo "-- SE-377: capa TEST + RECEIPT"
NEG=$(bash scripts/guardrail-negative-tests.sh --json 2>/dev/null || echo "[]")
NTOTAL=$(jq -r "length" <<<"$NEG" 2>/dev/null || echo 0)
NBLOCK=$(jq -r "[.[] | select(.result==\"BLOCKED\")] | length" <<<"$NEG" 2>/dev/null || echo 0)
RECEIPT_HOOKS=$(grep -lE "\\.jsonl|receipt|audit_log" .claude/hooks/*.sh 2>/dev/null | wc -l)
ENF_TOTAL=$HOOKS_BLOCK
{
  echo
  echo "## Cobertura TEST + RECEIPT (SE-377)"
  echo
  echo "| Métrica | Valor |"
  echo "|---|---|"
  echo "| Negative tests ejecutados | $NTOTAL |"
  echo "| Enforcement hooks que bloquean | $NBLOCK/$NTOTAL |"
  echo "| Enforcement hooks con emisión auditable (jsonl/receipt/audit) | $RECEIPT_HOOKS/$ENF_TOTAL |"
  echo
  echo "Criterio SE-377: 100% de hooks ENFORCEMENT L4 con negative test + receipt. Un negative test NOT_BLOCKED = P0."
  echo
} >> "$OUT/compliance-matrix.md"

echo "-- FASE E: resumen ejecutivo"
{
  echo "# Guardrail Principle Audit — Resumen (SE-374)"
  echo
  echo "Inventario: **$HOOKS hooks** ($HOOKS_BLOCK enforcement · $DISP disparador · $INFO informativo) · $AGENTS agentes · $RULES normas · $SKILLS skills · $PROHIB prohibiciones NUNCA/jamás."
  echo
  echo "Determinismo: $DETERMINISM. Runtime: $((SECONDS - START))s."
  echo
  echo "Hallazgos: **P0=$P0 · P1=$P1 · P2=$P2** — detalle en gap-report.md, matriz en compliance-matrix.md."
  echo
  echo "Top-5 gaps (P0 primero):"
  echo
  jq -r '[.rn[] | .rn as $rn | .findings[] | {rn: $rn, severity: .severity, guardrail: .guardrail, evidence: .evidence}] | sort_by(.severity) | .[0:5][] | "- \(.severity) \(.rn): \(.guardrail | gsub("\\|";"")) (\(.evidence | gsub("\\|";"")))"' "$TMP/rn-facts.json"
  echo
  echo "Lectura clave (LEC-2): las capas NORMA y DISPARADOR son probabilísticas; solo ENFORCEMENT (hook block) garantiza. Este informe no valida el contenido ético de los principios, solo que la arquitectura los implemente."
} > "$OUT/README.md"

echo "-- RN-12: invariante read-only"
SNAP_AFTER=$(git status --porcelain 2>/dev/null | LC_ALL=C sort)
VIOLATIONS="$(diff <(printf '%s\n' "$SNAP_BEFORE") <(printf '%s\n' "$SNAP_AFTER") 2>/dev/null | grep -E '^[<>]' | grep -vE '^[<>] [^ ]+ +(output/guardrail-audit/|scripts/guardrail-)' || true)"
if [[ -n "$VIOLATIONS" ]]; then
  echo "ABORT (RN-12): la auditoría modificó ficheros fuente:"
  printf '%s\n' "$VIOLATIONS"
  exit 2
fi

ELAPSED=$((SECONDS - START))
echo "OK: 4 ficheros en $OUT/ · ${ELAPSED}s · determinismo $DETERMINISM"
[[ $ELAPSED -le 60 ]] || echo "AVISO: runtime ${ELAPSED}s supera el límite de 60s (§5)"
[[ -n "$VIOLATIONS" ]] || exit 0
