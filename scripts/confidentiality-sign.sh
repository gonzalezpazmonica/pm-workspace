#!/usr/bin/env bash
set -uo pipefail
# confidentiality-sign.sh — Cryptographic signature for confidentiality audit

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SIG_FILE="$ROOT_DIR/.confidentiality-signature"
SECRET_FILE="$HOME/.savia/confidentiality-key"
ACTION="${1:-status}"

get_diff_hash() {
  cd "$ROOT_DIR" || exit 2
  # Hash the HEAD tree of all tracked files, excluding self-referencing files.
  # Uses git's content-addressed blob SHAs (ls-tree output) — fully deterministic
  # across environments (no diff format dependencies, no merge-base volatility).
  # Rationale: signature asserts approval of a specific tree state. Any commit
  # that changes tracked files → tree changes → sig invalid. Rebase/merge that
  # doesn't touch tracked files → tree unchanged → sig still valid. See SPEC-111.
  git ls-tree -r HEAD \
    | awk -F'\t' '$2 != ".confidentiality-signature" && $2 != ".github/workflows/confidentiality-gate.yml"' \
    | sha256sum | awk '{print $1}'
}

ensure_secret() {
  if [ ! -f "$SECRET_FILE" ]; then
    mkdir -p "$(dirname "$SECRET_FILE")"
    openssl rand -hex 32 > "$SECRET_FILE" 2>/dev/null \
      || head -c 32 /dev/urandom | xxd -p -c 64 > "$SECRET_FILE"
    chmod 600 "$SECRET_FILE"
  fi
}

compute_hmac() {
  local key
  key=$(cat "$SECRET_FILE" 2>/dev/null)
  printf '%s' "$1" | openssl dgst -sha256 -hmac "$key" 2>/dev/null \
    | awk '{print $NF}'
}

do_sign() {
  echo "Confidentiality Signature — Sign"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  ensure_secret
  local diff_hash branch head_commit signature
  diff_hash=$(get_diff_hash)
  branch=$(git -C "$ROOT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null)
  head_commit=$(git -C "$ROOT_DIR" rev-parse --short HEAD 2>/dev/null)
  signature=$(compute_hmac "$diff_hash")
  cat > "$SIG_FILE" <<SIGEOF
# Confidentiality audit signature — DO NOT EDIT
diff_hash=$diff_hash
timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
branch=$branch
head_commit=$head_commit
signature=$signature
SIGEOF
  echo "SIGNED  hash=${diff_hash:0:16}..."
}

do_verify() {
  echo "Confidentiality Signature — Verify"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  if [ ! -f "$SIG_FILE" ]; then
    echo "ERROR: No .confidentiality-signature file."
    exit 1
  fi
  local saved_diff saved_sig
  saved_diff=$(grep '^diff_hash=' "$SIG_FILE" | cut -d= -f2)
  saved_sig=$(grep '^signature=' "$SIG_FILE" | cut -d= -f2)
  [ -z "$saved_diff" ] || [ -z "$saved_sig" ] && echo "ERROR: Malformed." && exit 1
  local current_diff
  current_diff=$(get_diff_hash)
  echo "  Saved:   ${saved_diff:0:24}..."
  echo "  Current: ${current_diff:0:24}..."
  if [ "$current_diff" != "$saved_diff" ]; then
    echo "ERROR: Diff hash mismatch."
    exit 1
  fi
  if [ -f "$SECRET_FILE" ]; then
    [ "$(compute_hmac "$saved_diff")" != "$saved_sig" ] && echo "ERROR: HMAC mismatch." >&2 && exit 1
    echo "  HMAC: VERIFIED"
  else
    echo "  HMAC: SKIPPED (no local key at $SECRET_FILE)"
    echo "  WARNING: Verification is diff-hash only — no cryptographic proof" >&2
  fi
  echo "  Diff: MATCH"
  echo "VERIFIED"
}

do_status() {
  [ ! -f "$SIG_FILE" ] && echo "No signature." && exit 0
  grep -v '^#' "$SIG_FILE" | grep -v '^$'
}

case "$ACTION" in sign) do_sign ;; verify) do_verify ;; status) do_status ;; *) echo "Usage: $0 {sign|verify|status}"; exit 2 ;; esac
