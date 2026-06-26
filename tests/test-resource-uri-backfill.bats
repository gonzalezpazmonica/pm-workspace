#!/usr/bin/env bats
# tests/test-resource-uri-backfill.bats — SE-222 S3
# Tests that resource: URI back-fill was applied to the target files.
# Ref: docs/propuestas/SE-222-okf-adoptable-patterns.md (Slice 3)

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

  # The 20 target files from the S3 candidate list (SE-222 already had resource:)
  TARGET_FILES=(
    "docs/propuestas/SPEC-149-sandbox-os-level.md"
    "docs/propuestas/SPEC-192-anti-adulation-illusory-truth.md"
    "docs/propuestas/SPEC-193-context-provenance-injection-hardening.md"
    "docs/propuestas/SPEC-194-criterion-simulation-layer.md"
    "docs/propuestas/SPEC-199-historical-context-tribunal-rounds.md"
    "docs/propuestas/SE-222-okf-adoptable-patterns.md"
    "docs/propuestas/SE-220-speculative-tool-execution.md"
    "docs/propuestas/SE-221-inverted-security-patterns-as-context-engineering.md"
    "docs/propuestas/SPEC-189-greedy-context-budget.md"
    "docs/propuestas/SE-172-markitdown-universal-digest.md"
    "docs/propuestas/SPEC-188-root-cause-investigation-architecture.md"
    "docs/propuestas/SPEC-154-priorizacion-vue.md"
    "docs/propuestas/SE-105-glm-governance-manifest.md"
    "docs/propuestas/SE-106-tiered-tribunal-execution.md"
    "docs/propuestas/SPEC-187-iah-principles-alignment.md"
    "docs/rules/domain/radical-honesty.md"
    "docs/rules/domain/sandbox-os-policy.md"
    "docs/rules/domain/criterion-simulation-honesty.md"
    "docs/rules/domain/authority-claims-not-evidence.md"
  )
  export REPO_ROOT TARGET_FILES
}

# ── AC1: at least 15 of the 19 accessible files have resource: ───────────────
@test "at least 15 of the 19 target files have a resource: field" {
  count=0
  for rel in "${TARGET_FILES[@]}"; do
    abs="$REPO_ROOT/$rel"
    if [[ -f "$abs" ]] && grep -q "^resource:" "$abs" 2>/dev/null; then
      count=$((count + 1))
    fi
  done
  # Also count SE-222 which had resource: already
  se222="$REPO_ROOT/docs/propuestas/SE-222-okf-adoptable-patterns.md"
  if [[ -f "$se222" ]] && grep -q "^resource:" "$se222" 2>/dev/null; then
    count=$((count + 1))
  fi
  echo "Files with resource:: $count"
  [ "$count" -ge 15 ]
}

# ── AC2: resource: values are valid URIs (http/https or internal://) ─────────
@test "all resource: fields contain valid URI prefixes (http/https or internal://)" {
  invalid=0
  for rel in "${TARGET_FILES[@]}" "docs/propuestas/SE-222-okf-adoptable-patterns.md"; do
    abs="$REPO_ROOT/$rel"
    [[ -f "$abs" ]] || continue
    while IFS= read -r line; do
      val="${line#resource:}"
      val="${val# }"         # strip leading space
      val="${val//\"/}"      # strip quotes
      val="${val// /}"       # strip all spaces
      # Must start with http://, https://, or internal://
      if [[ "$val" != http://* ]] && [[ "$val" != https://* ]] && [[ "$val" != internal://* ]]; then
        echo "INVALID resource in $rel: '$val'"
        invalid=$((invalid + 1))
      fi
    done < <(grep "^resource:" "$abs" 2>/dev/null)
  done
  [ "$invalid" -eq 0 ]
}

# ── AC3: no file has duplicate resource: fields in frontmatter ────────────────
@test "no target file has duplicate resource: field in its frontmatter" {
  duplicates=0
  for rel in "${TARGET_FILES[@]}" "docs/propuestas/SE-222-okf-adoptable-patterns.md"; do
    abs="$REPO_ROOT/$rel"
    [[ -f "$abs" ]] || continue
    # Count resource: only within the first frontmatter block
    count=$(awk '
      /^---/ { if (in_fm) exit; in_fm=1; next }
      in_fm && /^resource:/ { c++ }
      END { print c+0 }
    ' "$abs")
    if [[ "$count" -gt 1 ]]; then
      echo "DUPLICATE resource: in FM of $rel ($count occurrences)"
      duplicates=$((duplicates + 1))
    fi
  done
  [ "$duplicates" -eq 0 ]
}

# ── AC4: resource: is inside the frontmatter block ────────────────────────────
@test "resource: field is inside the frontmatter block (before second ---)" {
  violations=0
  for rel in "${TARGET_FILES[@]}" "docs/propuestas/SE-222-okf-adoptable-patterns.md"; do
    abs="$REPO_ROOT/$rel"
    [[ -f "$abs" ]] || continue
    # Only check if file has frontmatter
    [[ "$(head -1 "$abs")" == "---" ]] || continue
    grep -q "^resource:" "$abs" || continue

    # Find if resource: appears before the closing ---
    in_fm=0
    found_resource_in_fm=0
    fm_closed=0
    lineno=0
    while IFS= read -r line; do
      lineno=$((lineno + 1))
      if [[ $lineno -eq 1 ]]; then
        in_fm=1
        continue
      fi
      if [[ $in_fm -eq 1 && "$line" == "---" ]]; then
        fm_closed=1
        in_fm=0
        continue
      fi
      if [[ $in_fm -eq 1 && "$line" == resource:* ]]; then
        found_resource_in_fm=1
      fi
    done < "$abs"

    if [[ $found_resource_in_fm -eq 0 && $fm_closed -eq 1 ]]; then
      # resource: exists but not in frontmatter
      echo "resource: not in FM: $rel"
      violations=$((violations + 1))
    fi
  done
  [ "$violations" -eq 0 ]
}

# ── AC5: specific high-value files have expected resource values ──────────────
@test "SPEC-192 has the expected DOI resource" {
  f="$REPO_ROOT/docs/propuestas/SPEC-192-anti-adulation-illusory-truth.md"
  [ -f "$f" ]
  grep -q "^resource:.*doi.org" "$f"
}

@test "SE-172 has markitdown github resource" {
  f="$REPO_ROOT/docs/propuestas/SE-172-markitdown-universal-digest.md"
  [ -f "$f" ]
  grep -q "^resource:.*markitdown" "$f"
}

@test "SPEC-149 has sandbox-runtime resource" {
  f="$REPO_ROOT/docs/propuestas/SPEC-149-sandbox-os-level.md"
  [ -f "$f" ]
  grep -q "^resource:.*sandbox-runtime" "$f"
}

@test "radical-honesty.md has resource field" {
  f="$REPO_ROOT/docs/rules/domain/radical-honesty.md"
  [ -f "$f" ]
  grep -q "^resource:" "$f"
}

@test "SE-222 already had resource before backfill" {
  f="$REPO_ROOT/docs/propuestas/SE-222-okf-adoptable-patterns.md"
  [ -f "$f" ]
  grep -q "^resource:" "$f"
}
