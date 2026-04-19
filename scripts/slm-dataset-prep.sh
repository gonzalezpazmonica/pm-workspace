#!/usr/bin/env bash
# slm-dataset-prep.sh — Phase 1 scaffolding for SLM training pipeline.
#
# Convierte archivos JSONL de conversaciones Savia (chat turns, memory
# engrams) al formato Unsloth SFT: (instruction, input, output) triples.
#
# Input JSONL schema expected (flexible, auto-detect):
#   {"role": "user|assistant", "content": "..."}          # chat-format
#   {"prompt": "...", "response": "..."}                   # simple Q&A
#   {"instruction": "...", "input": "...", "output": "..."} # already Alpaca/Unsloth
#
# Output: JSONL in Alpaca/Unsloth format con triples (instruction, input, output).
#
# Usage:
#   slm-dataset-prep.sh --input raw.jsonl --output processed.jsonl
#   slm-dataset-prep.sh --input raw.jsonl --output p.jsonl --pii-scrub
#   slm-dataset-prep.sh --input raw.jsonl --output p.jsonl --dry-run
#
# Exit codes:
#   0 — conversion succeeded
#   1 — validation error (malformed input)
#   2 — usage error
#
# Ref: SPEC-SE-027, SPEC-080, docs/rules/domain/slm-training-pipeline.md §Fase 1
# Safety: read-only del input, set -uo pipefail, sin red.

set -uo pipefail

INPUT=""
OUTPUT=""
PII_SCRUB=0
DRY_RUN=0

usage() {
  cat <<EOF
Usage:
  $0 --input FILE --output FILE [--pii-scrub] [--dry-run]

  --input FILE    JSONL raw (chat-format / Q&A / Alpaca)
  --output FILE   JSONL destino Alpaca/Unsloth
  --pii-scrub     Scrub emails, phones, and DNI-like patterns (GDPR)
  --dry-run       Valida sin escribir output

Ref: docs/rules/domain/slm-training-pipeline.md
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --input) INPUT="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    --pii-scrub) PII_SCRUB=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown arg '$1'" >&2; exit 2 ;;
  esac
done

[[ -z "$INPUT" ]] && { echo "ERROR: --input required" >&2; exit 2; }
[[ -z "$OUTPUT" && "$DRY_RUN" -eq 0 ]] && { echo "ERROR: --output required (unless --dry-run)" >&2; exit 2; }
[[ ! -f "$INPUT" ]] && { echo "ERROR: input not found: $INPUT" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 required" >&2; exit 2; }

# Delegate conversion to a python heredoc (jq alone cannot do the format
# detection cleanly, and python3 is already required).
python3 - "$INPUT" "${OUTPUT:-/dev/null}" "$PII_SCRUB" "$DRY_RUN" <<'PY'
import json, sys, re, os

input_path = sys.argv[1]
output_path = sys.argv[2]
pii_scrub = int(sys.argv[3])
dry_run = int(sys.argv[4])

EMAIL_RE = re.compile(r'[\w.+-]+@[\w-]+\.[\w.-]+')
PHONE_RE = re.compile(r'(?:\+?\d{1,3}[\s-]?)?\(?\d{2,4}\)?[\s-]?\d{3}[\s-]?\d{3,4}')
DNI_RE = re.compile(r'\b\d{8}[A-Z]\b')

def scrub(text):
    text = EMAIL_RE.sub('[EMAIL]', text)
    text = PHONE_RE.sub('[PHONE]', text)
    text = DNI_RE.sub('[DNI]', text)
    return text

def to_alpaca(rec):
    """Convert a record to (instruction, input, output). Return None to skip."""
    if isinstance(rec, dict):
        if 'instruction' in rec and 'output' in rec:
            return {
                'instruction': rec['instruction'],
                'input': rec.get('input', ''),
                'output': rec['output'],
            }
        if 'prompt' in rec and 'response' in rec:
            return {
                'instruction': rec['prompt'],
                'input': '',
                'output': rec['response'],
            }
    return None

def pair_chat_turns(records):
    """Collapse user/assistant turns into Alpaca triples.
    Strategy: every user turn + next assistant turn = one training pair."""
    out = []
    i = 0
    while i < len(records):
        r = records[i]
        if isinstance(r, dict) and r.get('role') == 'user':
            # find next assistant turn
            j = i + 1
            while j < len(records):
                nxt = records[j]
                if isinstance(nxt, dict) and nxt.get('role') == 'assistant':
                    out.append({
                        'instruction': r.get('content', ''),
                        'input': '',
                        'output': nxt.get('content', ''),
                    })
                    i = j + 1
                    break
                j += 1
            else:
                i += 1
        else:
            i += 1
    return out

records = []
malformed = 0
with open(input_path) as f:
    for line_num, line in enumerate(f, 1):
        line = line.strip()
        if not line:
            continue
        try:
            records.append(json.loads(line))
        except json.JSONDecodeError:
            malformed += 1

if malformed > 0:
    sys.stderr.write(f"WARN: {malformed} malformed JSON lines skipped\n")

# Detect format: if first record has 'role', use chat pairing; else alpaca/qa.
is_chat = records and isinstance(records[0], dict) and 'role' in records[0]
if is_chat:
    pairs = pair_chat_turns(records)
else:
    pairs = [p for p in (to_alpaca(r) for r in records) if p]

if pii_scrub:
    for p in pairs:
        p['instruction'] = scrub(p['instruction'])
        p['input'] = scrub(p['input'])
        p['output'] = scrub(p['output'])

# Report.
sys.stderr.write(f"slm-dataset-prep: input_records={len(records)} pairs_emitted={len(pairs)} format={'chat' if is_chat else 'qa'} pii_scrub={pii_scrub} dry_run={dry_run}\n")

if dry_run:
    sys.exit(0)

with open(output_path, 'w') as f:
    for p in pairs:
        f.write(json.dumps(p, ensure_ascii=False) + '\n')

sys.stderr.write(f"wrote {output_path}\n")
PY
rc=$?
exit $rc
