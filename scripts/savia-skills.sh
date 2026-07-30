#!/usr/bin/env bash
set -uo pipefail
export LC_ALL=C
# savia-skills.sh — Unified skill management CLI (SE-277)
#
# Single command to manage skills across multiple coding assistant frontends.
# Source of truth: .opencode/skills/<id>/SKILL.md (symlinked from .claude/skills/)
#
# Commands:
#   savia skills list             List skills per target
#   savia skills sync [--target]  Regenerate all targets
#   savia skills doctor           Health check: drift, broken symlinks, orphans
#   savia skills doctor --fix     Auto-repair detectable issues
#
# Targets:
#   opencode  .opencode/skills/       (source, nothing to generate)
#   claude    .claude/skills/         (symlink, nothing to generate)
#   codex     AGENTS.md               (block with skill index)
#   cursor    .cursor/rules/          (.mdc files)
#   windsurf  .windsurf/rules/        (.md copies)
#   copilot   .github/copilot-instructions.md (block with skill index)
#
# Reference: SE-277 spec
# Reference: skills-md-generate.sh (SE-078)
# Reference: agents-md-generate.sh (SE-078)

ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
SKILLS_DIR="${ROOT}/.opencode/skills"

# --- Helpers ---

die() { echo "ERROR: $*" >&2; exit 1; }

extract_field() {
  local file="$1" field="$2"
  awk -v field="^${field}:" '
    /^---$/ { c++; if (c>=2) exit; next }
    c==1 {
      if ($0 ~ field) {
        sub(field, ""); sub(/^[[:space:]]+/, "")
        if ($0 ~ /^>/) { collecting = 1; buf = ""; next }
        gsub(/^"|"$/, ""); print; exit
      }
      if (collecting) {
        if ($0 ~ /^[[:alpha:]_][^[:space:]]*:/) {
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", buf); print buf; exit
        }
        gsub(/^[[:space:]]+|[[:space:]]+$/, "")
        if ($0 != "") buf = buf " " $0
      }
    }
    END { if (collecting) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", buf); print buf } }
  ' "$file"
}

list_skill_ids() {
  find -L "${SKILLS_DIR}" -mindepth 2 -maxdepth 6 -name "SKILL.md" -type f ! -path '*/_template/*' | LC_ALL=C sort | while read -r f; do
    local name
    name=$(extract_field "$f" "name")
    [[ -z "$name" ]] && name=$(basename "$(dirname "$f")")
    echo "$name"
  done
}

# --- Doctor: health checks ---

cmd_doctor() {
  local fix_mode=false
  [[ "${1:-}" == "--fix" ]] && fix_mode=true

  local issues=0

  echo "==> Skills Doctor"
  echo ""

  # 1. Check source directory
  echo -n "  Source dir (.opencode/skills): "
  if [[ -d "$SKILLS_DIR" ]]; then
    echo "OK"
  else
    echo "MISSING"
    issues=$((issues + 1))
    $fix_mode && die "Cannot fix: source directory missing. Clone or restore skills."
  fi

  # 2. Check symlink integrity
  echo -n "  Symlink .opencode/skills -> .claude/skills: "
  if [[ -L "$SKILLS_DIR" ]]; then
    local target
    target=$(readlink "$SKILLS_DIR")
    if [[ -d "$SKILLS_DIR" ]]; then
      echo "OK (-> $target)"
    else
      echo "BROKEN (-> $target)"
      issues=$((issues + 1))
    fi
  else
    echo "NOT_A_SYMLINK"
    issues=$((issues + 1))
  fi

  # 3. Check SKILLS.md sync
  echo -n "  SKILLS.md vs source: "
  local tmp
  tmp=$(mktemp)
  if bash "${ROOT}/scripts/skills-md-generate.sh" > "$tmp" 2>/dev/null; then
    if [[ -f "${ROOT}/SKILLS.md" ]]; then
      if diff -q "$tmp" "${ROOT}/SKILLS.md" >/dev/null 2>&1; then
        echo "IN SYNC"
      else
        local diff_count
        diff_count=$(diff "$tmp" "${ROOT}/SKILLS.md" | wc -l)
        echo "DRIFT ($diff_count lines differ)"
        issues=$((issues + 1))
        if $fix_mode; then
          bash "${ROOT}/scripts/skills-md-generate.sh" --apply
          echo "         -> fixed (regenerated SKILLS.md)"
        fi
      fi
    else
      echo "MISSING (SKILLS.md not found)"
      issues=$((issues + 1))
      if $fix_mode; then
        bash "${ROOT}/scripts/skills-md-generate.sh" --apply
        echo "         -> fixed (created SKILLS.md)"
      fi
    fi
  else
    echo "ERROR (skills-md-generate.sh failed)"
    issues=$((issues + 1))
  fi
  rm -f "$tmp"

  # 4. Count skills
  local count
  count=$(list_skill_ids | wc -l)
  echo "  Skill count: $count"

  # 5. Verify all SKILL.md files are reachable by their frontmatter name
  local orphans=0 mismatches=0
  while read -r f; do
    [[ "$f" == *"/_template/"* ]] && continue
    local name dirname
    name=$(extract_field "$f" "name")
    dirname=$(basename "$(dirname "$f")")
    [[ -z "$name" ]] && name="$dirname"

    # Check if name matches dirname (flat) or is a nested sub-skill
    if [[ "$name" != "$dirname" ]]; then
      if [[ "$mismatches" -eq 0 ]]; then
        echo "  INFO: $name → $dirname (nested path, normal for family skills)"
      fi
      mismatches=$((mismatches + 1))
    fi
  done < <(find -L "${SKILLS_DIR}" -mindepth 2 -maxdepth 6 -name "SKILL.md" -type f ! -path '*/_template/*' | LC_ALL=C sort)
  [[ $mismatches -gt 0 ]] && echo "  Nested skills (name ≠ dirname): $mismatches"
  [[ $orphans -gt 0 ]] && issues=$((issues + orphans))

  echo ""
  if [[ $issues -eq 0 ]]; then
    echo "  All checks passed."
  else
    echo "  $issues issue(s) found."
    if ! $fix_mode; then
      echo "  Run 'savia skills doctor --fix' to auto-repair detectable issues."
    fi
  fi

  return $issues
}

# --- List: show skills per target ---

cmd_list() {
  echo "==> Skills by Target"
  echo ""

  local count
  count=$(list_skill_ids | wc -l)
  echo "  Total skills: $count"
  echo ""

  echo "  Target        | Type     | Status"
  echo "  --------------|----------|-------"
  echo "  opencode      | source   | $( [[ -d "$SKILLS_DIR" ]] && echo "ACTIVE ($count skills)" || echo "MISSING" )"
  echo "  claude        | symlink  | $( [[ -L "$SKILLS_DIR" ]] && echo "ACTIVE (shared)" || echo "BROKEN" )"
  echo "  codex/cursor  | markdown | $( [[ -f "${ROOT}/SKILLS.md" ]] && echo "ACTIVE (SKILLS.md)" || echo "MISSING" )"
  echo "  windsurf      | rules    | $( [[ -d "${ROOT}/.windsurf/rules/" ]] && echo "ACTIVE" || echo "NOT CONFIGURED" )"
  echo "  cursor        | mdc      | $( [[ -d "${ROOT}/.cursor/rules/" ]] && echo "ACTIVE" || echo "NOT CONFIGURED" )"
  echo "  copilot       | markdown | $( [[ -f "${ROOT}/.github/copilot-instructions.md" ]] && echo "ACTIVE" || echo "NOT CONFIGURED" )"

  # Show maturity breakdown
  echo ""
  echo "  Maturity breakdown:"
  local stable=0 beta=0 experimental=0 stub=0 unknown=0
  while read -r skill_id; do
    local skill_file="${SKILLS_DIR}/${skill_id}/SKILL.md"
    local maturity
    maturity=$(extract_field "$skill_file" "maturity")
    case "$maturity" in
      stable) stable=$((stable + 1)) ;;
      beta) beta=$((beta + 1)) ;;
      experimental) experimental=$((experimental + 1)) ;;
      *) unknown=$((unknown + 1)) ;;
    esac
  done < <(list_skill_ids)
  echo "    stable: $stable  beta: $beta  experimental: $experimental  other: $unknown"
}

# --- Sync: regenerate all targets ---

cmd_sync() {
  local target="all"
  local args=("$@")
  local i=0
  while [[ $i -lt ${#args[@]} ]]; do
    case "${args[$i]}" in
      --target) i=$((i + 1)); target="${args[$i]:-all}"; i=$((i + 1)) ;;
      *) i=$((i + 1)) ;;
    esac
  done

  echo "==> Syncing skills (target: $target)"
  echo ""

  # Always regenerate SKILLS.md (serves codex, cursor, zed, etc.)
  if [[ "$target" == "all" || "$target" == "markdown" ]]; then
    echo -n "  SKILLS.md: "
    if bash "${ROOT}/scripts/skills-md-generate.sh" --apply 2>/dev/null; then
      echo "OK"
    else
      echo "FAILED"
      return 1
    fi

    echo -n "  skills-manifest.json: "
    if bash "${ROOT}/scripts/skills-md-generate.sh" --apply --manifest 2>/dev/null; then
      echo "OK"
    else
      echo "FAILED (manifest flag may not be implemented yet)"
    fi
  fi

  # Windsurf rules (direct copies of SKILL.md)
  if [[ "$target" == "all" || "$target" == "windsurf" ]]; then
    echo -n "  .windsurf/rules/: "
    mkdir -p "${ROOT}/.windsurf/rules/"
    local synced=0
    while read -r skill_id; do
      local src="${SKILLS_DIR}/${skill_id}/SKILL.md"
      local dst="${ROOT}/.windsurf/rules/savia-${skill_id}.md"
      cp "$src" "$dst"
      synced=$((synced + 1))
    done < <(list_skill_ids)
    echo "OK ($synced files)"
  fi

  # Cursor rules (.mdc format with frontmatter)
  if [[ "$target" == "all" || "$target" == "cursor" ]]; then
    echo -n "  .cursor/rules/: "
    mkdir -p "${ROOT}/.cursor/rules/"
    local csynced=0
    while read -r skill_id; do
      local src="${SKILLS_DIR}/${skill_id}/SKILL.md"
      local dst="${ROOT}/.cursor/rules/savia-${skill_id}.mdc"
      local desc
      desc=$(extract_field "$src" "description")
      [[ -z "$desc" ]] && desc="Skill: $skill_id"
      # Cursor .mdc format: YAML frontmatter with description + globs + alwaysApply
      {
        echo "---"
        echo "description: \"$desc\""
        echo "globs: []"
        echo "alwaysApply: false"
        echo "---"
        echo ""
        # Skip the first YAML frontmatter block from source
        awk 'BEGIN{c=0} /^---$/ {c++; if(c==2){c=3;next}} c!=1 && c!=0 {print}' "$src"
      } > "$dst"
      csynced=$((csynced + 1))
    done < <(list_skill_ids)
    echo "OK ($csynced files)"
  fi

  # GitHub Copilot instructions (block in .github/copilot-instructions.md)
  if [[ "$target" == "all" || "$target" == "copilot" ]]; then
    echo -n "  .github/copilot-instructions.md: "
    mkdir -p "${ROOT}/.github/"
    local copilot_file="${ROOT}/.github/copilot-instructions.md"
    {
      echo "# Savia Skills — Copilot Instructions"
      echo ""
      echo "> Auto-generated by savia-skills.sh sync (SE-277). Do not edit by hand."
      echo "> Source: .opencode/skills/*/SKILL.md"
      echo ""
      echo "## Available Skills"
      echo ""
      echo "To use a skill, read its SKILL.md and follow the instructions."
      echo ""
      echo "| Skill | Description |"
      echo "|---|---|"
      while read -r skill_id; do
        local src="${SKILLS_DIR}/${skill_id}/SKILL.md"
        local desc
        desc=$(extract_field "$src" "description")
        [[ -z "$desc" ]] && desc="—"
        # Sanitize: remove pipes and trim
        desc=$(echo "$desc" | tr -s '[:space:]' ' ' | sed 's/|/\\|/g' | sed -E 's/^ +| +$//g')
        [[ ${#desc} -gt 100 ]] && desc="${desc:0:97}..."
        echo "| $skill_id | $desc |"
      done < <(list_skill_ids)
    } > "$copilot_file"
    echo "OK"
  fi

  echo ""
  echo "  Sync complete."
}

# --- Main ---

usage() {
  cat <<USG
Usage: savia skills <command> [options]

Commands:
  list              List skills and targets
  sync [--target]   Regenerate targets (all, markdown, windsurf)
  doctor            Health check
  doctor --fix      Health check + auto-repair

Examples:
  savia skills list
  savia skills sync
  savia skills doctor
  savia skills doctor --fix
USG
}

COMMAND="${1:-}"
case "$COMMAND" in
  list)
    cmd_list
    ;;
  sync)
    cmd_sync "${@:2}"
    ;;
  doctor)
    cmd_doctor "${@:2}"
    ;;
  --help|-h|"")
    usage
    ;;
  *)
    echo "Unknown command: $COMMAND" >&2
    usage >&2
    exit 2
    ;;
esac
