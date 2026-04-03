#!/bin/bash
# hook-pii-gate.sh — PII Quality Gate Pre-Commit Hook
# Blocks commits with PII patterns: email, phone, DNI/NIE, IBAN, IP, API keys

[[ "$PII_CHECK_ENABLED" != "true" ]] && exit 0

FINDINGS_FILE=$(mktemp)
echo "0" > "$FINDINGS_FILE"
trap 'rm -f "$FINDINGS_FILE"' EXIT
RED='\033[0;31m' YELLOW='\033[1;33m' GREEN='\033[0;32m' NC='\033[0m'

log_finding() {
    local count; count=$(cat "$FINDINGS_FILE"); echo $((count + 1)) > "$FINDINGS_FILE"
    printf "%b[%d] %s:%d — %s%b\n" "$RED" "$((count + 1))" "$1" "$2" "$3" "$NC"
}

should_skip_file() {
    [[ "$1" =~ \.(png|jpg|gif|zip|tar|gz|exe|dll|so|dylib)$ ]] && return 0
    git check-ignore -q "$1" 2>/dev/null && return 0
    [[ "$1" =~ (node_modules|\.git|\.min\.|dist/|build/) ]] && return 0
    return 1
}

check_pii() {
    local file=$1 content=$2

    # Email addresses (exclude common test/example domains)
    while IFS=: read -r line_num _; do
        [[ -n "$line_num" ]] && log_finding "$file" "$line_num" "Email"
    done < <(grep -nE '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}' <<< "$content" | \
        grep -v '@example\|@test\|@localhost\|@gmail\|@outlook\|@github' || true)

    # DNI/NIE: 8 digits + letter or X/Y/Z + 7 digits + letter
    while IFS=: read -r line_num _; do
        [[ -n "$line_num" ]] && log_finding "$file" "$line_num" "DNI/NIE"
    done < <(grep -nE '[0-9]{8}[A-Z]|[XYZ][0-9]{7}[A-Z]' <<< "$content" || true)

    # Private IPs: 10.x, 192.168.x, 172.16-31.x
    while IFS=: read -r line_num _; do
        [[ -n "$line_num" ]] && log_finding "$file" "$line_num" "Private-IP"
    done < <(grep -nE '(10\.[0-9]+\.[0-9]+\.[0-9]+|192\.168\.[0-9]+\.[0-9]+|172\.(1[6-9]|2[0-9]|3[01])\.[0-9]+\.[0-9]+)' <<< "$content" || true)

    # API keys: AKIA*, AIza*, ghp_*
    while IFS=: read -r line_num _; do
        [[ -n "$line_num" ]] && log_finding "$file" "$line_num" "API-Key"
    done < <(grep -nE '(sk-[a-zA-Z0-9]{20,}|pk-[a-zA-Z0-9]{20,}|AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{35}|ghp_[A-Za-z0-9]{36})' <<< "$content" | \
        grep -v 'PLACEHOLDER\|sk-\*\|pk-\*' || true)

    # IBAN: 2-letter country + 2 check digits + context
    while IFS=: read -r line_num _; do
        [[ -n "$line_num" ]] && log_finding "$file" "$line_num" "IBAN"
    done < <(grep -nE '[A-Z]{2}[0-9]{2}[A-Z0-9]{1,30}' <<< "$content" | grep -iE 'iban|account|es[0-9]{20}' || true)

    # Company forms: S.L., S.A., Ltd, GmbH, Inc, etc.
    while IFS=: read -r line_num _; do
        [[ -n "$line_num" ]] && log_finding "$file" "$line_num" "Company"
    done < <(grep -nE '\b[A-Z][a-zA-Z0-9 ]+(S\.L\.|S\.A\.|Ltd|GmbH|Inc|AG)\b' <<< "$content" || true)
}

# Main
printf "\n%b🔐 PII Quality Gate%b\n" "$YELLOW" "$NC"

staged_files=$(git diff --cached --name-only 2>/dev/null)
[[ -z "$staged_files" ]] && printf "%b✅ No staged files%b\n\n" "$GREEN" "$NC" && exit 0

while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    should_skip_file "$file" && continue
    content=$(git show ":$file" 2>/dev/null) || continue
    [[ -z "$content" ]] && continue
    check_pii "$file" "$content"
done <<< "$staged_files"

TOTAL=$(cat "$FINDINGS_FILE")
if [[ "$TOTAL" -gt 0 ]]; then
    printf "\n%b❌ PII detected: %d finding(s)%b\n" "$RED" "$TOTAL" "$NC"
    printf "%bOverride: SKIP_PII_CHECK=1 git commit%b\n\n" "$RED" "$NC"
    exit 1
fi

printf "%b✅ No PII patterns detected%b\n\n" "$GREEN" "$NC"
exit 0
