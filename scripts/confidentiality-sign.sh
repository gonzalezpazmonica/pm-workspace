#!/usr/bin/env bash
set -uo pipefail
# confidentiality-sign.sh — Cryptographic signature for confidentiality audit
#
# Sign: on feature branch before push (last step before push)
# Verify: in CI on PR (must produce same diff hash as local sign)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SIG_FILE="$ROOT_DIR/.confidentiality-signature"
SECRET_FILE="$HOME/.savia/confidentiality-key"
ACTION="${1:-status}"

get_diff_hash() {
  cd "$ROOT_DIR" || exit 2
  local diff="" base="" tip=""

  # Determine base and tip refs
  if [ -n "${GITHUB_BASE_REF:-}" ]; then
    # CI: GitHub Actions PR context
    base="origin/${GITHUB_BASE_REF}"
    # In CI merge checkout, get actual branch tip (not merge commit)
    if [ -n "${GITHUB_HEAD_REF:-}" ]; then
      tip="origin/${GITHUB_HEAD_REF}"
    else
      tip="HEAD"
    fi
    echo "  [CI mode] base=$base tip=$tip" >&2
  elif git rev-parse --verify origin/main >/dev/null 2>&1; then
    # Local: feature branch vs origin/main
    base="origin/main"
    tip="HEAD"
  fi

  # Compute diff between base and tip, excluding signature file
  if [ -n "$base" ]; then
    diff=$(git diff "$base".."$tip" -- . ':!.confidentiality-signature' 2>/dev/null)
  fi

  # Fallback: staged changes (no base ref available)
  if [ -z "$diff" ] && [ -z "$base" ]; then
    diff=$(git diff --cached -- . ':!.confidentiality-signature' 2>/dev/null)
  fi

  printf '%s' "$diff" | sha256sum | awk '{print $1}'
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
  local diff_hash branch head_commit timestamp signature
  diff_hash=$(get_diff_hash)
  timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  branch=$(git -C "$ROOT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null)
  head_commit=$(git -C "$ROOT_DIR" rev-parse --short HEAD 2>/dev/null)
  signature=$(compute_hmac "$diff_hash")
  cat > "$SIG_FILE" <<SIGEOF
# Confidentiality audit signature — DO NOT EDIT
diff_hash=$diff_hash
timestamp=$timestamp
branch=$branch
head_commit=$head_commit
signature=$signature
SIGEOF
  echo "SIGNED"
  echo "  Diff hash:  ${diff_hash:0:16}..."
  echo "  Branch:     $branch"
  echo "  Commit:     $head_commit"
  echo ""
  echo "Commit .confidentiality-signature with your PR."
}

do_verify() {
  echo "Confidentiality Signature — Verify"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  if [ ! -f "$SIG_FILE" ]; then
    echo "::error::No .confidentiality-signature file."
    exit 1
  fi
  local saved_diff saved_sig
  saved_diff=$(grep '^diff_hash=' "$SIG_FILE" | cut -d= -f2)
  saved_sig=$(grep '^signature=' "$SIG_FILE" | cut -d= -f2)
  if [ -z "$saved_diff" ] || [ -z "$saved_sig" ]; then
    echo "::error::Signature file malformed."
    exit 1
  fi
  local current_diff
  current_diff=$(get_diff_hash)
  echo "  Saved:   ${saved_diff:0:16}..."
  echo "  Current: ${current_diff:0:16}..."
  if [ "$current_diff" != "$saved_diff" ]; then
    echo "  FULL saved:   $saved_diff"
    echo "  FULL current: $current_diff"
    echo "::error::Diff hash mismatch. Re-sign."
    exit 1
  fi
  if [ -f "$SECRET_FILE" ]; then
    local expected
    expected=$(compute_hmac "$saved_diff")
    if [ "$expected" != "$saved_sig" ]; then
      echo "::error::HMAC mismatch."
      exit 1
    fi
    echo "  HMAC: VERIFIED"
  else
    echo "  HMAC: skipped (no key)"
  fi
  echo "  Diff: MATCH"
  echo "VERIFIED"
}

do_status() {
  [ ! -f "$SIG_FILE" ] && echo "No signature." && exit 0
  grep -v '^#' "$SIG_FILE" | grep -v '^$'
}

case "$ACTION" in
  sign)   do_sign ;;
  verify) do_verify ;;
  status) do_status ;;
  *)      echo "Usage: $0 {sign|verify|status}"; exit 2 ;;
esac
