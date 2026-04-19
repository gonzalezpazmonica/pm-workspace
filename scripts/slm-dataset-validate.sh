#!/usr/bin/env bash
# slm-dataset-validate.sh — Validate a JSONL dataset before SLM training.
#
# Checks (all read-only):
#   - Valid JSON per line (no malformed records)
#   - Alpaca schema: {instruction, output} required; input optional
#   - Length distribution (min/median/max tokens-ish proxy via wc)
#   - PII scan (emails, phones, DNI) — hard fail si cualquiera presente
#   - Deduplication estimate (exact instruction match)
#   - Sample size ≥ minimum threshold (default 100)
#
# Usage:
#   slm-dataset-validate.sh --input data.jsonl
#   slm-dataset-validate.sh --input data.jsonl --min-samples 500 --json
#   slm-dataset-validate.sh --input data.jsonl --allow-pii   # downgrade PII to warning
#
# Exit codes:
#   0 — dataset válido
#   1 — validation failures (listados en stdout)
#   2 — usage error
#
# Ref: SPEC-SE-027 §Pipeline de preparación de datos, SPEC-023 §Fuentes de datos
# Safety: read-only, set -uo pipefail.

set -uo pipefail

INPUT=""
MIN_SAMPLES=100
ALLOW_PII=0
JSON=0

usage() {
  cat <<EOF
Usage:
  $0 --input FILE [--min-samples N] [--allow-pii] [--json]

  --input FILE        JSONL dataset en formato Alpaca ({instruction, output} or with input)
  --min-samples N     Mínimo muestras válidas requeridas (default 100)
  --allow-pii         Downgrade PII leaks to warning (DANGEROUS — only for tests)
  --json              Output JSON

Exit codes:
  0 — valid  ·  1 — validation failures  ·  2 — usage error

Ref: SPEC-SE-027 §Data prep, docs/rules/domain/slm-training-pipeline.md §Fase 1
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --input) INPUT="$2"; shift 2 ;;
    --min-samples) MIN_SAMPLES="$2"; shift 2 ;;
    --allow-pii) ALLOW_PII=1; shift ;;
    --json) JSON=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown arg '$1'" >&2; exit 2 ;;
  esac
done

[[ -z "$INPUT" ]] && { echo "ERROR: --input required" >&2; exit 2; }
[[ ! -f "$INPUT" ]] && { echo "ERROR: input file not found: $INPUT" >&2; exit 2; }
if ! [[ "$MIN_SAMPLES" =~ ^[0-9]+$ ]] || [[ "$MIN_SAMPLES" -le 0 ]]; then
  echo "ERROR: --min-samples must be positive integer" >&2
  exit 2
fi
command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 required" >&2; exit 2; }

# Delegate validation to python (JSON parsing + regex scans + statistics).
python3 - "$INPUT" "$MIN_SAMPLES" "$ALLOW_PII" "$JSON" <<'PY'
import json, sys, re, statistics

input_path = sys.argv[1]
min_samples = int(sys.argv[2])
allow_pii = int(sys.argv[3])
json_out = int(sys.argv[4])

EMAIL_RE = re.compile(r'[\w.+-]+@[\w-]+\.[\w.-]+')
PHONE_RE = re.compile(r'(?:\+?\d{1,3}[\s-]?)?\(?\d{3,4}\)?[\s-]?\d{3}[\s-]?\d{3,4}')
DNI_RE = re.compile(r'\b\d{8}[A-Z]\b')

errors = []
warnings = []
valid_records = []
malformed = 0
missing_fields = 0
pii_hits = {"emails": 0, "phones": 0, "dnis": 0}

with open(input_path) as f:
    for ln, line in enumerate(f, 1):
        line = line.strip()
        if not line:
            continue
        try:
            rec = json.loads(line)
        except json.JSONDecodeError:
            malformed += 1
            continue
        # Alpaca schema check.
        if not isinstance(rec, dict):
            malformed += 1
            continue
        if 'instruction' not in rec or 'output' not in rec:
            missing_fields += 1
            continue
        valid_records.append(rec)
        # PII scan.
        combined = f"{rec.get('instruction','')} {rec.get('input','')} {rec.get('output','')}"
        pii_hits["emails"] += len(EMAIL_RE.findall(combined))
        pii_hits["phones"] += len(PHONE_RE.findall(combined))
        pii_hits["dnis"] += len(DNI_RE.findall(combined))

# Structural errors.
if malformed > 0:
    errors.append(f"{malformed} malformed JSON lines")
if missing_fields > 0:
    errors.append(f"{missing_fields} records missing 'instruction' or 'output' fields")
if len(valid_records) < min_samples:
    errors.append(f"only {len(valid_records)} valid records, below --min-samples threshold {min_samples}")

# PII errors (or warnings if --allow-pii).
pii_total = sum(pii_hits.values())
if pii_total > 0:
    msg = f"PII detected: {pii_hits['emails']} emails, {pii_hits['phones']} phones, {pii_hits['dnis']} DNIs — scrub before training"
    if allow_pii:
        warnings.append(msg + " (allowed via --allow-pii)")
    else:
        errors.append(msg)

# Length stats.
if valid_records:
    instr_lens = [len(r['instruction'].split()) for r in valid_records]
    out_lens = [len(r['output'].split()) for r in valid_records]
    stats = {
        "instruction_words_min": min(instr_lens),
        "instruction_words_median": int(statistics.median(instr_lens)),
        "instruction_words_max": max(instr_lens),
        "output_words_min": min(out_lens),
        "output_words_median": int(statistics.median(out_lens)),
        "output_words_max": max(out_lens),
    }
else:
    stats = {}

# Dedup check (exact instruction match).
instructions = [r['instruction'] for r in valid_records]
unique = len(set(instructions))
duplicates = len(instructions) - unique
if duplicates > 0:
    pct = duplicates / len(instructions) * 100 if instructions else 0
    if pct > 20:
        errors.append(f"{duplicates} duplicate instructions ({pct:.1f}%) — dataset too redundant")
    elif pct > 5:
        warnings.append(f"{duplicates} duplicate instructions ({pct:.1f}%) — consider dedup")

valid = 1 if not errors else 0
report = {
    "valid": bool(valid),
    "input": input_path,
    "total_records": len(valid_records) + malformed + missing_fields,
    "valid_records": len(valid_records),
    "malformed": malformed,
    "missing_fields": missing_fields,
    "duplicates": duplicates,
    "unique": unique,
    "pii": pii_hits,
    "stats": stats,
    "errors": errors,
    "warnings": warnings,
}

if json_out:
    print(json.dumps(report, ensure_ascii=False))
else:
    if valid:
        print(f"VALID: {len(valid_records)} records in {input_path}")
        if warnings:
            print("  Warnings:")
            for w in warnings: print(f"    - {w}")
        if stats:
            print(f"  Length: instr {stats['instruction_words_min']}/{stats['instruction_words_median']}/{stats['instruction_words_max']} (min/median/max words)")
            print(f"          out   {stats['output_words_min']}/{stats['output_words_median']}/{stats['output_words_max']}")
        print(f"  Unique: {unique}/{len(valid_records)} distinct instructions")
    else:
        print(f"INVALID: dataset {input_path}")
        for e in errors: print(f"  ERR: {e}")
        for w in warnings: print(f"  WARN: {w}")

sys.exit(0 if valid else 1)
PY
rc=$?
exit $rc
