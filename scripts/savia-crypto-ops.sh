#!/bin/bash
# savia-crypto-ops.sh — Encrypt and decrypt operations
# Sourced by savia-crypto.sh — do NOT run directly.

SCRIPTS_DIR="${SCRIPTS_DIR:-$(cd "$(dirname "$0")" && pwd)}"
source "$SCRIPTS_DIR/savia-compat.sh"

# ── Encrypt: hybrid RSA+AES encryption ─────────────────────────────
do_encrypt() {
  local pubkey_file="${1:?Uso: savia-crypto.sh encrypt <pubkey.pem> < plaintext}"
  local plaintext="${2:-}"

  if [ ! -f "$pubkey_file" ]; then
    log_error "Public key not found: $pubkey_file"
    return 1
  fi

  local tmp_dir
  tmp_dir=$(mktemp -d)
  trap "rm -rf '$tmp_dir'" EXIT

  # Read plaintext from arg or stdin
  if [ -n "$plaintext" ]; then
    echo -n "$plaintext" > "$tmp_dir/plain.txt"
  else
    cat > "$tmp_dir/plain.txt"
  fi

  # Generate random AES-256 key and IV
  openssl rand -hex 32 > "$tmp_dir/aes.key"
  openssl rand -hex 16 > "$tmp_dir/aes.iv"

  # Encrypt body with AES-256-CBC
  openssl enc -aes-256-cbc -salt -pbkdf2 -iter 10000 \
    -K "$(cat "$tmp_dir/aes.key")" -iv "$(cat "$tmp_dir/aes.iv")" \
    -in "$tmp_dir/plain.txt" -out "$tmp_dir/body.enc" 2>/dev/null

  # Encrypt AES key+IV with recipient's RSA public key
  local key_bundle
  key_bundle="$(cat "$tmp_dir/aes.key"):$(cat "$tmp_dir/aes.iv")"
  echo -n "$key_bundle" | openssl pkeyutl -encrypt \
    -pubin -inkey "$pubkey_file" -out "$tmp_dir/key.enc" 2>/dev/null

  # Output: base64(encrypted_key):::base64(encrypted_body)
  local enc_key enc_body
  enc_key=$(portable_base64_encode "$tmp_dir/key.enc")
  enc_body=$(portable_base64_encode "$tmp_dir/body.enc")

  echo "${enc_key}:::${enc_body}"
}

# ── Decrypt: hybrid RSA+AES decryption ─────────────────────────────
do_decrypt() {
  local encrypted="${1:?Uso: savia-crypto.sh decrypt <encrypted_package>}"

  if [ ! -f "$KEYS_DIR/private.pem" ]; then
    log_error "No private key found at $KEYS_DIR/private.pem"
    return 1
  fi

  local tmp_dir
  tmp_dir=$(mktemp -d)
  trap "rm -rf '$tmp_dir'" EXIT

  # Split package
  local enc_key enc_body
  enc_key=$(echo "$encrypted" | cut -d':' -f1)
  enc_body=$(echo "$encrypted" | awk -F':::' '{print $2}')

  if [ -z "$enc_key" ] || [ -z "$enc_body" ]; then
    log_error "Invalid encrypted package format (expected key:::body)"
    return 1
  fi

  # Decode and decrypt AES key with own RSA private key
  echo -n "$enc_key" | portable_base64_decode > "$tmp_dir/key.enc"
  local key_bundle
  key_bundle=$(openssl pkeyutl -decrypt \
    -inkey "$KEYS_DIR/private.pem" -in "$tmp_dir/key.enc" 2>/dev/null)

  local aes_key aes_iv
  aes_key=$(echo "$key_bundle" | cut -d':' -f1)
  aes_iv=$(echo "$key_bundle" | cut -d':' -f2)

  # Decode and decrypt body with AES
  echo -n "$enc_body" | portable_base64_decode > "$tmp_dir/body.enc"
  openssl enc -d -aes-256-cbc -pbkdf2 -iter 10000 \
    -K "$aes_key" -iv "$aes_iv" \
    -in "$tmp_dir/body.enc" 2>/dev/null
}
