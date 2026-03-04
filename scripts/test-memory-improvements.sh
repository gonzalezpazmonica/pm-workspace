#!/bin/bash
# Test suite for Memory Store Improvements v1.9.0
PASS=0; FAIL=0; TOTAL=0
ok() { TOTAL=$((TOTAL+1)); PASS=$((PASS+1)); echo "  ✅ $1"; }
fail() { TOTAL=$((TOTAL+1)); FAIL=$((FAIL+1)); echo "  ❌ $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MS="$SCRIPT_DIR/memory-store.sh"
TD=$(mktemp -d)
trap "rm -rf $TD" EXIT
mkdir -p "$TD/output"
SF="$TD/output/.memory-store.jsonl"
run() { PROJECT_ROOT="$TD" bash "$MS" "$@"; }

echo "═══ Test Suite — Memory Store Improvements (v1.9.0) ═══"
echo ""
echo "[Group 1] Concepts Dimension"

run save --type decision --title 'Test1' --content 'With concepts' --concepts 'testing,ci' >/dev/null
grep -q '"concepts":\["testing","ci"\]' "$SF" && ok "Save with --concepts creates JSON array" || fail "Save with --concepts creates JSON array"

run save --type bug --title 'Test2' --content 'Without concepts here' >/dev/null
grep 'Test2' "$SF" | grep -q '"concepts":\[\]' && ok "Save without --concepts has empty array" || fail "Save without --concepts has empty array"

run search testing 2>&1 | grep -q 'Test1' && ok "Search finds entry by concept keyword" || fail "Search finds entry by concept keyword"

run stats 2>&1 | grep -q 'Por concepto' && ok "Stats shows concept breakdown" || fail "Stats shows concept breakdown"

echo ""
echo "[Group 2] Token Economics"
C100=$(printf 'x%.0s' {1..100})
run save --type pattern --title 'Tok100' --content "$C100" >/dev/null
T100=$(grep 'Tok100' "$SF" | grep -oP '"tokens_est":\K[0-9]+')
[[ -n "$T100" && $T100 -ge 20 && $T100 -le 30 ]] && ok "100-char → ~25 tokens (got $T100)" || fail "100-char tokens (got $T100)"

C400=$(printf 'y%.0s' {1..400})
run save --type pattern --title 'Tok400' --content "$C400" >/dev/null
T400=$(grep 'Tok400' "$SF" | grep -oP '"tokens_est":\K[0-9]+')
[[ -n "$T400" && $T400 -ge 90 && $T400 -le 110 ]] && ok "400-char → ~100 tokens (got $T400)" || fail "400-char tokens (got $T400)"

echo ""
echo "[Group 3] Hybrid Search"
run save --type decision --title 'AlphaDecision' --content 'unique alpha content' >/dev/null
run save --type bug --title 'BetaBug' --content 'unique beta content' >/dev/null

run search Alpha --type decision 2>&1 | grep -q 'AlphaDecision' && ok "--type decision finds decisions" || fail "--type decision finds decisions"
run search Beta --type decision 2>&1 | grep -q 'BetaBug' && fail "--type decision should exclude bugs" || ok "--type decision excludes bugs"
run search Test1 --since '2020-01-01' 2>&1 | grep -q 'Test1' && ok "--since 2020 finds recent entries" || fail "--since 2020 finds recent"
run search Test1 --since '2099-01-01' 2>&1 | grep -q 'No se encontraron' && ok "--since 2099 finds nothing" || fail "--since 2099"

for i in $(seq 1 12); do run save --type convention --title "Bulk$i" --content "Bulk unique content number $i" >/dev/null 2>&1; done
RC=$(run search Bulk 2>&1 | grep -c 'score:' || true)
[[ $RC -le 10 ]] && ok "Search caps at 10 results (got $RC)" || fail "Max 10 results (got $RC)"

echo ""
echo "[Group 4] Integrity"
VALID=true
while IFS= read -r line; do
  echo "$line" | python3 -c "import sys,json; json.loads(sys.stdin.read())" 2>/dev/null || { VALID=false; break; }
done < "$SF"
$VALID && ok "All JSONL lines are valid JSON" || fail "JSONL validation failed"

run save --type discovery --title 'SpecChars' --content 'Data with stuff' >/dev/null 2>&1
grep -q 'SpecChars' "$SF" && ok "Store integrity after many operations" || fail "Store integrity"

echo ""
echo "═══ Resultado: $PASS/$TOTAL passed ($FAIL failed) ═══"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
