#!/usr/bin/env bash
# slm-registry.sh — Model registry for trained SLMs (SPEC-SE-027 registry).
#
# Gestión local del registry documentado en SPEC-SE-027 §Model Registry.
# El registry vive en un directorio por proyecto (`<project>/registry/`)
# con un manifest.json indexando versiones, linaje y metadata.
#
# Subcommands:
#   register      Registra una nueva versión (crea entry en manifest.json)
#   list          Lista versiones registradas
#   show          Muestra detalle de una versión
#   promote       Marca una versión como "deployed" (hay un solo deployed)
#   deprecate     Marca una versión como deprecated
#
# Manifest format (JSON):
#   {
#     "project": "savia-context",
#     "versions": [
#       {
#         "id": "sft-20260419",
#         "base_model": "llama-3.2-1b",
#         "method": "sft",
#         "training_tokens": 1250000,
#         "epochs": 3,
#         "final_loss": 0.823,
#         "created_at": "2026-04-19T15:00:00Z",
#         "ollama_name": "savia-context:sft-20260419",
#         "status": "deployed"
#       }
#     ]
#   }
#
# Usage:
#   slm-registry.sh register --project PATH --id VERSION --base-model MODEL --method sft
#   slm-registry.sh list --project PATH
#   slm-registry.sh show --project PATH --id VERSION
#   slm-registry.sh promote --project PATH --id VERSION
#   slm-registry.sh deprecate --project PATH --id VERSION
#
# Exit codes:
#   0 — subcommand succeeded
#   1 — logical error (version not found, conflict, etc)
#   2 — usage error
#
# Ref: SPEC-SE-027 §Model Registry, docs/rules/domain/slm-training-pipeline.md
# Safety: read-only except for registry/manifest.json, set -uo pipefail.

set -uo pipefail

SUBCMD=""
PROJECT=""
VERSION_ID=""
BASE_MODEL=""
METHOD=""
TRAINING_TOKENS=""
EPOCHS=""
FINAL_LOSS=""
OLLAMA_NAME=""
# L18 / SE-342 S2: experiment tracking — run metadata
RUN_ID=""
RUN_METRICS=""
RUN_PARAMS=""
RUN_ARTIFACT=""
DATASET=""
CATALOG_DB=""

usage() {
  cat <<EOF
Usage:
  $0 register --project PATH --id VERSION --base-model MODEL --method METHOD [options]
  $0 run --project PATH --run-id ID [--metrics JSON] [--params JSON] [--artifact PATH] [--dataset NAME] [--catalog-db DB]
  $0 list --project PATH
  $0 show --project PATH --id VERSION
  $0 promote --project PATH --id VERSION
  $0 deprecate --project PATH --id VERSION

Subcommands:
  register    Append version entry to registry/manifest.json
  list        Print table of versions
  show        Print JSON detail of one version
  promote     Mark version as 'deployed' (only one at a time)
  deprecate   Mark version as 'deprecated'

Register options:
  --base-model MODEL      Base model name (required)
  --method METHOD         sft | dpo | grpo (required)
  --training-tokens N     Tokens consumed (optional)
  --epochs N              Epochs (optional)
  --final-loss FLOAT      Final loss (optional)
  --ollama-name NAME      Ollama tag (optional, default <project>:<id>)

Ref: SPEC-SE-027 §Model Registry
EOF
}

[[ $# -eq 0 ]] && { usage; exit 2; }

# Handle --help/-h before consuming subcommand.
case "$1" in
  -h|--help) usage; exit 0 ;;
esac

SUBCMD="$1"; shift

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project) PROJECT="$2"; shift 2 ;;
    --id) VERSION_ID="$2"; shift 2 ;;
    --base-model) BASE_MODEL="$2"; shift 2 ;;
    --method) METHOD="$2"; shift 2 ;;
    --training-tokens) TRAINING_TOKENS="$2"; shift 2 ;;
    --epochs) EPOCHS="$2"; shift 2 ;;
    --final-loss) FINAL_LOSS="$2"; shift 2 ;;
    --ollama-name) OLLAMA_NAME="$2"; shift 2 ;;
    --run-id) RUN_ID="$2"; shift 2 ;;
    --metrics) RUN_METRICS="$2"; shift 2 ;;
    --params) RUN_PARAMS="$2"; shift 2 ;;
    --artifact) RUN_ARTIFACT="$2"; shift 2 ;;
    --dataset) DATASET="$2"; shift 2 ;;
    --catalog-db) CATALOG_DB="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown arg '$1'" >&2; exit 2 ;;
  esac
done

[[ -z "$PROJECT" ]] && { echo "ERROR: --project required" >&2; exit 2; }
[[ ! -d "$PROJECT" ]] && { echo "ERROR: project directory not found: $PROJECT" >&2; exit 2; }

REGISTRY_DIR="$PROJECT/registry"
MANIFEST="$REGISTRY_DIR/manifest.json"
PROJECT_NAME=$(basename "$PROJECT")

ensure_manifest() {
  mkdir -p "$REGISTRY_DIR"
  if [[ ! -f "$MANIFEST" ]]; then
    cat > "$MANIFEST" <<JSON
{
  "project": "$PROJECT_NAME",
  "versions": []
}
JSON
  fi
}

case "$SUBCMD" in
  register)
    [[ -z "$VERSION_ID" ]] && { echo "ERROR: --id required for register" >&2; exit 2; }
    [[ -z "$BASE_MODEL" ]] && { echo "ERROR: --base-model required for register" >&2; exit 2; }
    [[ -z "$METHOD" ]] && { echo "ERROR: --method required for register" >&2; exit 2; }

    # Validate method.
    case "$METHOD" in
      sft|dpo|grpo) ;;
      *) echo "ERROR: invalid --method '$METHOD' (allowed: sft, dpo, grpo)" >&2; exit 2 ;;
    esac

    # Validate id format (slug).
    if ! [[ "$VERSION_ID" =~ ^[a-z0-9][a-z0-9._-]*$ ]]; then
      echo "ERROR: --id must be slug (lowercase, digits, dots, dashes)" >&2
      exit 2
    fi

    ensure_manifest

    # Check id doesn't exist.
    if python3 -c "import json; d=json.load(open('$MANIFEST')); exit(0 if any(v['id']=='$VERSION_ID' for v in d['versions']) else 1)" 2>/dev/null; then
      echo "ERROR: version '$VERSION_ID' already registered (use different id or deprecate first)" >&2
      exit 1
    fi

    : "${OLLAMA_NAME:=$PROJECT_NAME:$VERSION_ID}"
    CREATED=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    python3 - <<PY
import json
with open("$MANIFEST") as f: d = json.load(f)
entry = {
    "id": "$VERSION_ID",
    "base_model": "$BASE_MODEL",
    "method": "$METHOD",
    "created_at": "$CREATED",
    "ollama_name": "$OLLAMA_NAME",
    "status": "registered"
}
for opt_name, opt_val in [("training_tokens", "$TRAINING_TOKENS"), ("epochs", "$EPOCHS"), ("final_loss", "$FINAL_LOSS")]:
    if opt_val:
        try:
            entry[opt_name] = float(opt_val) if opt_name == "final_loss" else int(opt_val)
        except ValueError:
            pass
d["versions"].append(entry)
with open("$MANIFEST", "w") as f: json.dump(d, f, indent=2)
PY
    echo "slm-registry register: $VERSION_ID added to $MANIFEST"
    ;;

  run)
    # L18 / SE-342 S2: experiment tracking — append a run (params/metrics/artifact)
    # with optional lineage to a catalog dataset (L17). Deterministic, local.
    [[ -z "$RUN_ID" ]] && { echo "ERROR: --run-id required for run" >&2; exit 2; }
    if ! [[ "$RUN_ID" =~ ^[a-z0-9][a-z0-9._-]*$ ]]; then
      echo "ERROR: --run-id must be slug" >&2; exit 2
    fi

    ensure_manifest

    if python3 -c "import json; d=json.load(open('$MANIFEST')); exit(0 if any(r.get('kind')=='run' and r['id']=='$RUN_ID' for r in d.get('runs',[])) else 1)" 2>/dev/null; then
      echo "ERROR: run '$RUN_ID' already logged (use different id)" >&2
      exit 1
    fi

    CREATED=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    python3 - "$RUN_PARAMS" "$RUN_METRICS" "$RUN_ARTIFACT" "$DATASET" "$RUN_ID" "$BASE_MODEL" "$MANIFEST" "$CREATED" <<'PY'
import json, sys
params_raw, metrics_raw, artifact, dataset, run_id, base_model, manifest, created = sys.argv[1:]
d = json.load(open(manifest))
runs = d.setdefault("runs", [])
entry = {"kind": "run", "id": run_id, "created_at": created}
if base_model:
    entry["base_model"] = base_model
for field, raw in (("params", params_raw), ("metrics", metrics_raw)):
    if not raw:
        continue
    try:
        entry[field] = json.loads(raw)
    except ValueError:
        entry[field] = {"values": raw}
if artifact:
    entry["artifact"] = artifact
if dataset:
    entry["dataset"] = dataset
runs.append(entry)
with open(manifest, "w") as f:
    json.dump(d, f, indent=2)
PY

    # Best-effort lineage to L17 catalog (only when explicitly provided).
    if [[ -n "$DATASET" && -n "$CATALOG_DB" ]]; then
      python3 scripts/savia-catalog.py --db "$CATALOG_DB" register --type model \
        --name "run:$RUN_ID" --level N2 --source "$RUN_ARTIFACT" \
        --relation trained_on --from-name "$DATASET" --from-type dataset \
        >/dev/null 2>&1 || true
    fi
    echo "slm-registry run: $RUN_ID logged (${RUN_METRICS:+metrics + }${RUN_PARAMS:+params})"
    ;;

  list)
    if [[ ! -f "$MANIFEST" ]]; then
      echo "(no registry yet — use 'register' to create first version)"
      exit 0
    fi
    python3 - <<PY
import json
with open("$MANIFEST") as f: d = json.load(f)
vs = d.get("versions", [])
if not vs:
    print("(no versions registered)")
    exit(0)
print(f"Project: {d['project']}  ({len(vs)} versions)")
print()
print(f"{'ID':<30} {'METHOD':<6} {'BASE':<20} {'STATUS':<12} {'CREATED'}")
print("-" * 90)
for v in vs:
    print(f"{v['id'][:29]:<30} {v.get('method','?'):<6} {v.get('base_model','?')[:19]:<20} {v.get('status','?'):<12} {v.get('created_at','?')}")
PY
    ;;

  show)
    [[ -z "$VERSION_ID" ]] && { echo "ERROR: --id required for show" >&2; exit 2; }
    [[ ! -f "$MANIFEST" ]] && { echo "ERROR: no registry exists yet" >&2; exit 1; }
    python3 - <<PY
import json, sys
with open("$MANIFEST") as f: d = json.load(f)
for v in d["versions"]:
    if v["id"] == "$VERSION_ID":
        print(json.dumps(v, indent=2))
        sys.exit(0)
print("ERROR: version '$VERSION_ID' not found", file=sys.stderr)
sys.exit(1)
PY
    rc=$?
    [[ "$rc" -ne 0 ]] && exit "$rc"
    ;;

  promote)
    [[ -z "$VERSION_ID" ]] && { echo "ERROR: --id required for promote" >&2; exit 2; }
    [[ ! -f "$MANIFEST" ]] && { echo "ERROR: no registry exists yet" >&2; exit 1; }
    python3 - <<PY
import json, sys
with open("$MANIFEST") as f: d = json.load(f)
target = None
for v in d["versions"]:
    if v["id"] == "$VERSION_ID":
        target = v
    elif v.get("status") == "deployed":
        v["status"] = "archived"
if not target:
    print("ERROR: version '$VERSION_ID' not found", file=sys.stderr)
    sys.exit(1)
target["status"] = "deployed"
target["promoted_at"] = "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
with open("$MANIFEST", "w") as f: json.dump(d, f, indent=2)
print(f"promoted '{target['id']}' to deployed (previous deployed versions archived)")
PY
    rc=$?
    [[ "$rc" -ne 0 ]] && exit "$rc"
    ;;

  deprecate)
    [[ -z "$VERSION_ID" ]] && { echo "ERROR: --id required for deprecate" >&2; exit 2; }
    [[ ! -f "$MANIFEST" ]] && { echo "ERROR: no registry exists yet" >&2; exit 1; }
    python3 - <<PY
import json, sys
with open("$MANIFEST") as f: d = json.load(f)
target = None
for v in d["versions"]:
    if v["id"] == "$VERSION_ID":
        target = v
        break
if not target:
    print("ERROR: version '$VERSION_ID' not found", file=sys.stderr)
    sys.exit(1)
target["status"] = "deprecated"
target["deprecated_at"] = "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
with open("$MANIFEST", "w") as f: json.dump(d, f, indent=2)
print(f"deprecated '{target['id']}'")
PY
    rc=$?
    [[ "$rc" -ne 0 ]] && exit "$rc"
    ;;

  *)
    echo "ERROR: unknown subcommand '$SUBCMD'" >&2
    usage
    exit 2
    ;;
esac

exit 0
