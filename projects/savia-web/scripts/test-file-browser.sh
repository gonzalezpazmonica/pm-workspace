#!/usr/bin/env bash
# test-file-browser.sh — Validate file browser component structure
# Usage: bash scripts/test-file-browser.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0
FAIL=0

check() {
  local desc="$1"
  local result="$2"
  if [ "$result" = "0" ]; then
    echo "  PASS  $desc"
    ((PASS++)) || true
  else
    echo "  FAIL  $desc"
    ((FAIL++)) || true
  fi
}

echo "=== File Browser Component Tests ==="
echo ""

# 1. Files exist
check "FileBreadcrumb.vue exists" "$([ -f "$ROOT/src/components/files/FileBreadcrumb.vue" ] && echo 0 || echo 1)"
check "FileViewer.vue exists" "$([ -f "$ROOT/src/components/files/FileViewer.vue" ] && echo 0 || echo 1)"
check "FileListItem.vue exists" "$([ -f "$ROOT/src/components/files/FileListItem.vue" ] && echo 0 || echo 1)"
check "FileBrowserPage.vue exists" "$([ -f "$ROOT/src/pages/FileBrowserPage.vue" ] && echo 0 || echo 1)"

# 2. FileBreadcrumb has navigate emit
check "FileBreadcrumb has 'navigate' emit" \
  "$(grep -q "navigate" "$ROOT/src/components/files/FileBreadcrumb.vue" && echo 0 || echo 1)"

# 3. FileViewer has content prop
check "FileViewer has 'content' prop" \
  "$(grep -q "content" "$ROOT/src/components/files/FileViewer.vue" && echo 0 || echo 1)"

# 4. FileListItem uses Lucide imports
check "FileListItem imports from lucide-vue-next" \
  "$(grep -q "lucide-vue-next" "$ROOT/src/components/files/FileListItem.vue" && echo 0 || echo 1)"

# 5. FileBrowserPage imports new components
check "FileBrowserPage imports FileBreadcrumb" \
  "$(grep -q "FileBreadcrumb" "$ROOT/src/pages/FileBrowserPage.vue" && echo 0 || echo 1)"
check "FileBrowserPage imports FileListItem" \
  "$(grep -q "FileListItem" "$ROOT/src/pages/FileBrowserPage.vue" && echo 0 || echo 1)"
check "FileBrowserPage imports FileViewer" \
  "$(grep -q "FileViewer" "$ROOT/src/pages/FileBrowserPage.vue" && echo 0 || echo 1)"

# 6. Line count checks (<=150 lines each)
for f in \
  "$ROOT/src/components/files/FileBreadcrumb.vue" \
  "$ROOT/src/components/files/FileViewer.vue" \
  "$ROOT/src/components/files/FileListItem.vue" \
  "$ROOT/src/pages/FileBrowserPage.vue"; do
  lines=$(wc -l < "$f")
  name=$(basename "$f")
  check "$name ≤150 lines ($lines)" "$([ "$lines" -le 150 ] && echo 0 || echo 1)"
done

# 7. No emoji icons in file browser components
EMOJI_PATTERN='📁\|📄\|📂\|🗂'
for f in \
  "$ROOT/src/components/files/FileBreadcrumb.vue" \
  "$ROOT/src/components/files/FileViewer.vue" \
  "$ROOT/src/components/files/FileListItem.vue" \
  "$ROOT/src/pages/FileBrowserPage.vue"; do
  name=$(basename "$f")
  check "$name has no emoji icons" \
    "$(grep -ql "$EMOJI_PATTERN" "$f" && echo 1 || echo 0)"
done

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
