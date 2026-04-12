#!/usr/bin/env bash
set -uo pipefail
# slm-data-prep.sh — Prepare project data for SLM fine-tuning
# SPEC: SE-027 SLM Training Pipeline
#
# Collects N4 project documents, chunks them into ChatML format,
# validates quality, and splits into train/eval sets.
# Zero data egress — all processing is local.
#
# Usage:
#   bash scripts/slm-data-prep.sh collect  --project X
#   bash scripts/slm-data-prep.sh format   --project X [--method sft|dpo]
#   bash scripts/slm-data-prep.sh validate --project X
#   bash scripts/slm-data-prep.sh split    --project X [--ratio 0.9]
#   bash scripts/slm-data-prep.sh stats    --project X

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
SLM_DATA_DIR="${HOME}/.savia/slm-data"

die() { echo "ERROR: $*" >&2; exit 2; }

# ── Helpers ──────────────────────────────────────────────────────────────────

_project_dir() {
  local p="$1"
  local d="$PROJECT_DIR/projects/$p"
  [[ -d "$d" ]] || die "Project '$p' not found at $d"
  echo "$d"
}

_output_dir() {
  local p="$1"
  local d="$SLM_DATA_DIR/$p"
  mkdir -p "$d"
  echo "$d"
}

_sanitize_pii() {
  # Remove common PII patterns from text before training
  # Reads from a file path argument (not stdin, to avoid heredoc conflict)
  local input_file="$1"
  python3 -c "
import re, sys
text = open(sys.argv[1], errors='replace').read()
text = re.sub(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}', '[EMAIL]', text)
text = re.sub(r'[+]?\d{1,3}[-. ]?\(?\d{2,4}\)?[-. ]?\d{3,4}[-. ]?\d{3,4}', '[PHONE]', text)
text = re.sub(r'\b\d{8}[A-Z]\b', '[DNI]', text)
text = re.sub(r'\b\d{4}[-\s]?\d{4}[-\s]?\d{4}[-\s]?\d{4}\b', '[CARD]', text)
text = re.sub(r'AKIA[0-9A-Z]{16}', '[AWS_KEY]', text)
text = re.sub(r'(Server|Host|Data Source)=[^;]+;[^;]*Password=[^;]+', '[CONNSTR]', text, flags=re.I)
print(text, end='')
" "$input_file" 2>/dev/null
}

# ── Collect ──────────────────────────────────────────────────────────────────

cmd_collect() {
  local project=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --project) project="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [[ -z "$project" ]] && die "Usage: collect --project NAME"

  local pdir; pdir=$(_project_dir "$project") || exit $?
  local odir; odir=$(_output_dir "$project")
  local raw_dir="$odir/raw"
  mkdir -p "$raw_dir"

  echo "Collecting documents from project: $project"

  local count=0

  # Collect markdown documents
  while IFS= read -r -d '' f; do
    local basename; basename=$(basename "$f")
    local relpath; relpath="${f#"$pdir"/}"
    # Skip binary, images, and non-text files
    [[ "$basename" == *.png || "$basename" == *.jpg || "$basename" == *.pdf ]] && continue
    # Skip empty files
    [[ ! -s "$f" ]] && continue
    # Sanitize and copy
    _sanitize_pii "$f" > "$raw_dir/$(echo "$relpath" | tr '/' '_')"
    ((count++))
  done < <(find "$pdir" -type f \( -name '*.md' -o -name '*.txt' \) -print0 2>/dev/null)

  # Collect code files if they exist (for code-domain training)
  local code_exts=("*.cs" "*.ts" "*.py" "*.java" "*.go" "*.rs" "*.rb" "*.php")
  for ext in "${code_exts[@]}"; do
    while IFS= read -r -d '' f; do
      local relpath; relpath="${f#"$pdir"/}"
      # Skip test files and generated code for cleaner training
      [[ "$relpath" == *test* || "$relpath" == *node_modules* || "$relpath" == *bin/* ]] && continue
      [[ ! -s "$f" ]] && continue
      _sanitize_pii "$f" > "$raw_dir/$(echo "$relpath" | tr '/' '_')"
      ((count++))
    done < <(find "$pdir" -type f -name "$ext" -print0 2>/dev/null)
  done

  echo "Collected: $count documents → $raw_dir"

  # Generate collection manifest
  python3 - "$raw_dir" "$odir" "$project" << 'PYMANIFEST'
import json, os, hashlib, sys
from datetime import datetime
raw_dir, odir, project = sys.argv[1], sys.argv[2], sys.argv[3]
files = []
for f in sorted(os.listdir(raw_dir)):
    path = os.path.join(raw_dir, f)
    if os.path.isfile(path):
        with open(path, 'rb') as fh:
            h = hashlib.sha256(fh.read()).hexdigest()
        files.append({'name': f, 'size': os.path.getsize(path), 'sha256': h})
manifest = {
    'project': project,
    'collected_at': datetime.utcnow().isoformat() + 'Z',
    'document_count': len(files),
    'total_bytes': sum(f['size'] for f in files),
    'files': files
}
with open(os.path.join(odir, 'collection-manifest.json'), 'w') as out:
    json.dump(manifest, out, indent=2)
print(f'Manifest: {len(files)} files, {manifest["total_bytes"]:,} bytes')
PYMANIFEST
}

# ── Format ───────────────────────────────────────────────────────────────────

cmd_format() {
  local project="" method="sft" chunk_size=2048 stride=512
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --project) project="$2"; shift 2 ;;
      --method) method="$2"; shift 2 ;;
      --chunk-size) chunk_size="$2"; shift 2 ;;
      --stride) stride="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [[ -z "$project" ]] && die "Usage: format --project NAME [--method sft|dpo]"

  local odir; odir=$(_output_dir "$project")
  local raw_dir="$odir/raw"
  [[ -d "$raw_dir" ]] || die "No collected data. Run 'collect' first."

  echo "Formatting data for $method training (chunk=$chunk_size, stride=$stride)"

  python3 << PYEOF
import json, os, glob

raw_dir = "$raw_dir"
output_file = "$odir/dataset-${method}.jsonl"
chunk_size = $chunk_size  # characters, not tokens (approx 4:1 ratio)
stride = $stride
method = "$method"

entries = []

for fpath in sorted(glob.glob(os.path.join(raw_dir, '*'))):
    if not os.path.isfile(fpath):
        continue
    with open(fpath, 'r', errors='replace') as f:
        text = f.read().strip()
    if not text or len(text) < 50:
        continue

    fname = os.path.basename(fpath)

    if method == "sft":
        # Create instruction-response pairs from document chunks
        # Chunk with overlap for context preservation
        for i in range(0, len(text), chunk_size - stride):
            chunk = text[i:i + chunk_size].strip()
            if len(chunk) < 100:
                continue

            # Determine instruction based on document type
            if fname.endswith('.md') or fname.endswith('.txt'):
                instruction = f"Describe the content and key information from the following project document section:"
            else:
                instruction = f"Explain what this code does and its key patterns:"

            entry = {
                "messages": [
                    {"role": "system", "content": "You are a domain expert for this project. Answer based on project documentation and code."},
                    {"role": "user", "content": f"{instruction}\n\n{chunk}"},
                    {"role": "assistant", "content": f"This section covers: {chunk[:200]}..."}
                ],
                "source": fname,
                "chunk_idx": i // (chunk_size - stride)
            }
            entries.append(entry)

    elif method == "dpo":
        # For DPO we need chosen/rejected pairs
        # This creates skeleton pairs — real DPO needs human preference data
        for i in range(0, len(text), chunk_size):
            chunk = text[i:i + chunk_size].strip()
            if len(chunk) < 200:
                continue
            entry = {
                "prompt": f"Summarize this project information:\n\n{chunk[:500]}",
                "chosen": chunk[:300],
                "rejected": "I don't have enough information to answer this question.",
                "source": fname
            }
            entries.append(entry)

with open(output_file, 'w') as out:
    for e in entries:
        out.write(json.dumps(e, ensure_ascii=False) + '\n')

print(f"Generated: {len(entries)} training examples → {output_file}")
PYEOF
}

# ── Validate ─────────────────────────────────────────────────────────────────

cmd_validate() {
  local project=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --project) project="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [[ -z "$project" ]] && die "Usage: validate --project NAME"

  local odir; odir=$(_output_dir "$project")

  python3 << PYEOF
import json, os, sys

odir = "$odir"
issues = []
total = 0
methods_found = []

for method in ["sft", "dpo"]:
    fpath = os.path.join(odir, f"dataset-{method}.jsonl")
    if not os.path.exists(fpath):
        continue
    methods_found.append(method)
    count = 0
    with open(fpath) as f:
        for i, line in enumerate(f, 1):
            try:
                entry = json.loads(line)
                count += 1
                if method == "sft":
                    msgs = entry.get("messages", [])
                    if len(msgs) < 2:
                        issues.append(f"{method} line {i}: fewer than 2 messages")
                    for m in msgs:
                        if "role" not in m or "content" not in m:
                            issues.append(f"{method} line {i}: missing role/content")
                elif method == "dpo":
                    for field in ["prompt", "chosen", "rejected"]:
                        if field not in entry:
                            issues.append(f"{method} line {i}: missing {field}")
            except json.JSONDecodeError:
                issues.append(f"{method} line {i}: invalid JSON")
    total += count
    print(f"  {method}: {count} examples")

if not methods_found:
    print("ERROR: No dataset files found. Run 'format' first.")
    sys.exit(2)

print(f"  Total: {total} examples")
if issues:
    print(f"  Issues: {len(issues)}")
    for issue in issues[:10]:
        print(f"    - {issue}")
    sys.exit(1)
else:
    print("  Validation: PASS (0 issues)")
PYEOF
}

# ── Split ────────────────────────────────────────────────────────────────────

cmd_split() {
  local project="" ratio="0.9"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --project) project="$2"; shift 2 ;;
      --ratio) ratio="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [[ -z "$project" ]] && die "Usage: split --project NAME [--ratio 0.9]"

  local odir; odir=$(_output_dir "$project")

  python3 << PYEOF
import json, os, random

odir = "$odir"
ratio = $ratio
random.seed(42)  # Reproducible splits

for method in ["sft", "dpo"]:
    fpath = os.path.join(odir, f"dataset-{method}.jsonl")
    if not os.path.exists(fpath):
        continue

    with open(fpath) as f:
        lines = f.readlines()

    random.shuffle(lines)
    split_idx = int(len(lines) * ratio)
    train = lines[:split_idx]
    eval_set = lines[split_idx:]

    train_path = os.path.join(odir, f"train-{method}.jsonl")
    eval_path = os.path.join(odir, f"eval-{method}.jsonl")

    with open(train_path, 'w') as f:
        f.writelines(train)
    with open(eval_path, 'w') as f:
        f.writelines(eval_set)

    print(f"  {method}: {len(train)} train + {len(eval_set)} eval (ratio {ratio})")
PYEOF
}

# ── Stats ────────────────────────────────────────────────────────────────────

cmd_stats() {
  local project=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --project) project="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [[ -z "$project" ]] && die "Usage: stats --project NAME"

  local odir; odir=$(_output_dir "$project")

  python3 << PYEOF
import json, os

odir = "$odir"

# Collection stats
manifest_path = os.path.join(odir, "collection-manifest.json")
if os.path.exists(manifest_path):
    with open(manifest_path) as f:
        manifest = json.load(f)
    print(f"Collection:")
    print(f"  Documents: {manifest['document_count']}")
    print(f"  Total size: {manifest['total_bytes']:,} bytes")
    print(f"  Collected: {manifest['collected_at']}")
else:
    print("Collection: not done yet")

# Dataset stats
for method in ["sft", "dpo"]:
    fpath = os.path.join(odir, f"dataset-{method}.jsonl")
    if os.path.exists(fpath):
        with open(fpath) as f:
            lines = f.readlines()
        total_chars = sum(len(l) for l in lines)
        est_tokens = total_chars // 4  # rough char-to-token ratio
        print(f"\nDataset ({method}):")
        print(f"  Examples: {len(lines)}")
        print(f"  Est. tokens: {est_tokens:,}")

# Split stats
for split in ["train", "eval"]:
    for method in ["sft", "dpo"]:
        fpath = os.path.join(odir, f"{split}-{method}.jsonl")
        if os.path.exists(fpath):
            with open(fpath) as f:
                count = sum(1 for _ in f)
            print(f"  {split}-{method}: {count} examples")

# Registry
reg_path = os.path.join(os.path.expanduser("~"), ".savia", "slm-registry", "$project", "manifest.json")
if os.path.exists(reg_path):
    with open(reg_path) as f:
        reg = json.load(f)
    print(f"\nModel Registry:")
    for v in reg.get("versions", []):
        print(f"  {v['id']}: {v['method']} | loss={v.get('final_loss','?')} | {v.get('status','?')}")
else:
    print("\nModel Registry: no models trained yet")
PYEOF
}

# ── Main ─────────────────────────────────────────────────────────────────────

case "${1:-}" in
  collect)  shift; cmd_collect "$@" ;;
  format)   shift; cmd_format "$@" ;;
  validate) shift; cmd_validate "$@" ;;
  split)    shift; cmd_split "$@" ;;
  stats)    shift; cmd_stats "$@" ;;
  --help|-h) echo "Usage: slm-data-prep.sh {collect|format|validate|split|stats} --project NAME" ;;
  *) echo "Usage: slm-data-prep.sh {collect|format|validate|split|stats} --project NAME" ;;
esac
