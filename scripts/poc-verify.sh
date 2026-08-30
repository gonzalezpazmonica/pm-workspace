#!/usr/bin/env bash
set -uo pipefail
# poc-verify.sh — SE-351: Verificador binario de PoCs (lección CyberGym)
#
# Verifica que un PoC produce una señal observable verificada PROGRAMÁTICAMENTE
# contra un target aislado, independiente del juicio del LLM. "Facts, not claims":
# el veredicto lo produce el programa (exit code / regex sobre output), no el agente.
#
# Ref: docs/specs/SE-351-poc-verify.spec.md
# Fuente de aprendizaje: https://github.com/sunblaze-ucb/cybergym (arXiv 2506.02548)
#
# Subcomandos:
#   verify  --oracle <json> --poc <file> [--name N] [--timeout N] [--out DIR]
#           → escribe recibo JSON + veredicto
#   sample  --oracle <json> --poc <file>   → imprime el target command resuelto (debug)
#   help
#
# Exit codes:
#   0   VERIFIED
#   1   NOT_VERIFIED
#   124 TIMEOUT
#   2   error de uso
#   3   error de infraestructura

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="${SAVIA_WORKSPACE_DIR:-${CLAUDE_PROJECT_DIR:-${OPENCODE_PROJECT_DIR:-$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || pwd)}}}"
POC_VERIFY_OUT_DIR="${POC_VERIFY_OUT_DIR:-$WORKSPACE_DIR/output/security}"
MAX_OUTPUT_BYTES="${POC_VERIFY_MAX_OUTPUT_BYTES:-2048}"

die() { echo "ERROR: $*" >&2; exit 2; }
infra_err() { echo "ERROR: $*" >&2; exit 3; }

_py3() { command -v python3 &>/dev/null; }
_jq() { command -v jq &>/dev/null; }

# ── Resolve target command, replacing {poc} with the poc path ───────────────
resolve_command() {
  local oracle="$1" poc_path="$2"
  _py3 || infra_err "python3 required for poc-verify"
  python3 - "$oracle" "$poc_path" <<'PY'
import json, sys
oracle_path, poc = sys.argv[1], sys.argv[2]
with open(oracle_path, encoding="utf-8") as f:
    cfg = json.load(f)
target = cfg.get("target", {})
ttype = target.get("type", "command")
cmd = target.get("command", "")
if ttype == "docker":
    image = target.get("docker_image", "")
    inner = target.get("command", "sh -c 'cat /tmp/poc | {cmd}'")
    net = target.get("network", "none")
    print(f"docker-run|{image}|{net}|{inner.replace('{poc}', '/tmp/poc')}")
elif ttype == "http":
    url = target.get("url", "").replace("{poc}", poc)
    method = target.get("method", "GET")
    print(f"http|{method}|{url}")
else:
    print(cmd.replace("{poc}", poc))
PY
}

# ── Run the target command and capture exit code + bounded output ───────────
run_target() {
  local resolved="$1" poc_path="$2" timeout_secs="${3:-10}" mode="${4:-exec}"
  local kind
  kind="${resolved%%|*}"
  local tmp_out
  tmp_out="$(mktemp)"

  case "$kind" in
    docker)
      local image net inner
      image="$(echo "$resolved" | cut -d'|' -f2)"
      net="$(echo "$resolved" | cut -d'|' -f3)"
      inner="$(echo "$resolved" | cut -d'|' -f4-)"
      if ! command -v docker &>/dev/null; then
        rm -f "$tmp_out"
        return 3
      fi
      local container="poc-verify-$(date +%s%N)-$$"
      local mount
      mount="$PWD:/work:ro"
      # always bind the poc as /tmp/poc and workdir as cwd when possible
      docker run --rm --name "$container" --network "$net" \
        -v "$(pwd):/work:ro" \
        -w /work \
        "$image" bash -c "$inner" > "$tmp_out" 2>&1
      local rc=$?
      [[ $rc -eq 125 || $rc -eq 126 || $rc -eq 127 ]] && { rm -f "$tmp_out"; return 3; }
      ;;
    http)
      local method url
      method="$(echo "$resolved" | cut -d'|' -f2)"
      url="$(echo "$resolved" | cut -d'|' -f3-)"
      if ! command -v curl &>/dev/null; then
        rm -f "$tmp_out"
        return 3
      fi
      timeout "$timeout_secs" curl -s -o "$tmp_out" -w '%{http_code}' -X "$method" "$url" > "$tmp_out" 2>&1
      local rc=$?
      ;;
    *)
      # command exec via sh -c, time-boxed
      timeout "$timeout_secs" bash -c "$resolved" > "$tmp_out" 2>&1
      local rc=$?
      ;;
  esac

  echo "$rc" > /tmp/poc-verify-rc.$$
  # bounded output
  head -c "$MAX_OUTPUT_BYTES" "$tmp_out" > /tmp/poc-verify-out.$$
  rm -f "$tmp_out"
}

# ── Evaluate oracle against exit code + output ──────────────────────────────
evaluate_oracle() {
  local oracle="$1" exit_code="$2" out_file="$3"
  _py3 || infra_err "python3 required for poc-verify"
  python3 - "$oracle" "$exit_code" "$out_file" <<'PY'
import json, re, sys
oracle_path, exit_code, out_file = sys.argv[1], int(sys.argv[2]), sys.argv[3]
with open(oracle_path, encoding="utf-8") as f:
    cfg = json.load(f)
oracle = cfg.get("oracle", {})
mode = oracle.get("mode", "exit_code_nonzero")
with open(out_file, encoding="utf-8", errors="replace") as f:
    output = f.read()

def check():
    if mode == "exit_code_nonzero":
        expected = oracle.get("expected_exit", 0)
        return exit_code != 0 and exit_code != expected
    if mode == "regex":
        return re.search(oracle.get("regex", ""), output) is not None
    if mode == "combined":
        expected = oracle.get("expected_exit", 0)
        exit_ok = exit_code != 0 and exit_code != expected
        regex_ok = re.search(oracle.get("regex", ""), output) is not None
        if oracle.get("require_all", True):
            return exit_ok and regex_ok
        return exit_ok or regex_ok
    return False

print("PASS" if check() else "FAIL")
PY
}

cmd_verify() {
  local oracle="" poc="" name="poc" timeout_secs="${POC_VERIFY_TIMEOUT:-10}" out_dir="$POC_VERIFY_OUT_DIR"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --oracle) oracle="$2"; shift 2 ;;
      --poc) poc="$2"; shift 2 ;;
      --name) name="$2"; shift 2 ;;
      --timeout) timeout_secs="$2"; shift 2 ;;
      --out) out_dir="$2"; shift 2 ;;
      --help|-h) usage; exit 0 ;;
      *) die "Unknown arg: $1" ;;
    esac
  done
  [[ -z "$oracle" ]] && die "verify requires --oracle"
  [[ -z "$poc" ]] && die "verify requires --poc"
  [[ -f "$oracle" ]] || die "oracle not found: $oracle"
  [[ -f "$poc" ]] || die "poc not found: $poc"

  local resolved
  resolved="$(resolve_command "$oracle" "$(realpath "$poc")")" || die "cannot resolve command"

  local rc_out="/tmp/poc-verify-rc.$$" out_file="/tmp/poc-verify-out.$$"
  rm -f "$rc_out" "$out_file"
  run_target "$resolved" "$(realpath "$poc")" "$timeout_secs"
  local run_rc=$?
  [[ $run_rc -eq 3 ]] && { rm -f "$rc_out" "$out_file"; infra_err "infrastructure failure (docker/curl not available)"; }

  # timeout command exits 124 (or 137 when SIGKILLed) — read from rc file, not
  # from run_target's own return code (which is 0 after writing the file).
  local exit_code rc_val
  rc_val="$(cat "$rc_out" 2>/dev/null || echo 0)"
  exit_code="$rc_val"
  if [[ "$exit_code" -eq 124 || "$exit_code" -eq 137 ]]; then
    echo "VERDICT: TIMEOUT"
    rm -f "$rc_out" "$out_file"
    exit 124
  fi

  local verdict
  verdict="$(evaluate_oracle "$oracle" "$exit_code" "$out_file" 2>/dev/null)"

  local poc_hash
  poc_hash="$(sha256sum "$(realpath "$poc")" | awk '{print $1}')"
  local ts
  ts="$(date +%Y%m%d-%H%M%S)"
  local stamp
  stamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  mkdir -p "$out_dir"
  local receipt="$out_dir/poc-verify-${ts}-$$.json"
  python3 - "$receipt" "$name" "$poc_hash" "$verdict" "$exit_code" "$out_file" "$stamp" >/dev/null <<'PY'
import json, sys
receipt, name, poc_hash, verdict, exit_code, out_file, stamp = sys.argv[1:8]
with open(out_file, encoding="utf-8", errors="replace") as f:
    output = f.read()
rec = {
    "schema_version": "1",
    "receipt_id": receipt.rsplit("/", 1)[-1].replace(".json", ""),
    "name": name,
    "verdict": "VERIFIED" if verdict == "PASS" else "NOT_VERIFIED",
    "exit_code": int(exit_code),
    "poc_sha256": poc_hash,
    "output_preview": output[:2048],
    "output_bytes": len(output.encode("utf-8", errors="replace")),
    "verified_at": stamp,
}
with open(receipt, "w", encoding="utf-8") as f:
    json.dump(rec, f, indent=2, ensure_ascii=False)
PY

  if [[ "$verdict" == "PASS" ]]; then
    echo "VERDICT: VERIFIED"
    echo "receipt: $receipt"
    exit 0
  else
    echo "VERDICT: NOT_VERIFIED"
    echo "receipt: $receipt"
    exit 1
  fi
}

cmd_sample() {
  local oracle="" poc=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --oracle) oracle="$2"; shift 2 ;;
      --poc) poc="$2"; shift 2 ;;
      --help|-h) usage; exit 0 ;;
      *) die "Unknown arg: $1" ;;
    esac
  done
  [[ -z "$oracle" ]] && die "sample requires --oracle"
  [[ -z "$poc" ]] && die "sample requires --poc"
  [[ -f "$oracle" ]] || die "oracle not found: $oracle"
  [[ -f "$poc" ]] || die "poc not found: $poc"
  resolve_command "$oracle" "$(realpath "$poc")"
}

usage() {
  cat <<EOF
poc-verify.sh — SE-351 verificador binario de PoCs

Usage:
  poc-verify.sh verify --oracle <json> --poc <file> [--name N] [--timeout N] [--out DIR]
  poc-verify.sh sample --oracle <json> --poc <file>

Exit codes: 0=VERIFIED 1=NOT_VERIFIED 124=TIMEOUT 2=usage 3=infra

Environment:
  POC_VERIFY_TIMEOUT          target timeout (default 10)
  POC_VERIFY_MAX_OUTPUT_BYTES output preview cap (default 2048)
  POC_VERIFY_OUT_DIR          receipts dir (default <workspace>/output/security)
EOF
}

case "${1:-}" in
  verify) shift; cmd_verify "$@" ;;
  sample) shift; cmd_sample "$@" ;;
  --help|-h|help) usage; exit 0 ;;
  *) echo "Usage: poc-verify.sh {verify|sample}" >&2; exit 2 ;;
esac
