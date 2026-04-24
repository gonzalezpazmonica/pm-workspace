#!/bin/bash
set -uo pipefail
# cwd-changed-hook.sh — Auto-load project context on directory change
# Hook: CwdChanged | Async: false (context injection needs to be synchronous)
# When user cd's into a project, injects project name + key context.
# Exit 0 + stdout → shown to Claude as context.
#
# This replaces manual /context-load for basic project detection.

# Read stdin (JSON with new CWD info)
INPUT=$(cat 2>/dev/null || true)

LIB_DIR="$(dirname "${BASH_SOURCE[0]}")/lib"
if [[ -f "$LIB_DIR/profile-gate.sh" ]]; then
  # shellcheck source=/dev/null
  source "$LIB_DIR/profile-gate.sh"
  profile_gate "standard"
fi

REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
NEW_CWD="${CLAUDE_CWD:-$(pwd)}"
PROJECTS_DIR="$REPO_ROOT/projects"
SAVIA_TMP="${TMPDIR:-${HOME}/.savia/tmp}"
mkdir -p "$SAVIA_TMP" 2>/dev/null || true
STATE_FILE="$SAVIA_TMP/savia-cwd-project-active"

# Only act if we entered a project directory
if [[ "$NEW_CWD" != "$PROJECTS_DIR"/* ]]; then
  # Left project dir — clear state
  if [[ -f "$STATE_FILE" ]]; then
    rm -f "$STATE_FILE" 2>/dev/null
  fi
  exit 0
fi

PROJECT=$(echo "$NEW_CWD" | sed "s|$PROJECTS_DIR/||" | cut -d'/' -f1)
PROJECT_DIR="$PROJECTS_DIR/$PROJECT"
PROJECT_CLAUDE="$PROJECT_DIR/CLAUDE.md"

# Skip if same project already active (avoid repeated injection)
if [[ -f "$STATE_FILE" ]] && [[ "$(cat "$STATE_FILE" 2>/dev/null)" == "$PROJECT" ]]; then
  exit 0
fi

# Record new active project
echo "$PROJECT" > "$STATE_FILE" 2>/dev/null || true

OUTPUT=""

# 1. Project CLAUDE.md exists — inject project name
if [[ -f "$PROJECT_CLAUDE" ]]; then
  OUTPUT="[Project context: $PROJECT]"
fi

# 2. Detect language pack from project files
# NOTE: avoid `ls pat1 pat2` (exits 2 if any pattern has no matches under pipefail).
# Use `compgen -G` which returns 0 iff the glob matches at least one file.
LANG_PACK=""
if compgen -G "$PROJECT_DIR/*.csproj" >/dev/null 2>&1 || compgen -G "$PROJECT_DIR/*.sln" >/dev/null 2>&1; then
  LANG_PACK="C#/.NET"
elif [[ -f "$PROJECT_DIR/package.json" ]]; then
  if [[ -f "$PROJECT_DIR/angular.json" ]]; then
    LANG_PACK="Angular"
  elif grep -q "react" "$PROJECT_DIR/package.json" 2>/dev/null; then
    LANG_PACK="React"
  else
    LANG_PACK="TypeScript/Node.js"
  fi
elif [[ -f "$PROJECT_DIR/go.mod" ]]; then
  LANG_PACK="Go"
elif [[ -f "$PROJECT_DIR/Cargo.toml" ]]; then
  LANG_PACK="Rust"
elif [[ -f "$PROJECT_DIR/requirements.txt" ]] || [[ -f "$PROJECT_DIR/pyproject.toml" ]]; then
  LANG_PACK="Python"
elif [[ -f "$PROJECT_DIR/pom.xml" ]] || [[ -f "$PROJECT_DIR/build.gradle" ]]; then
  LANG_PACK="Java"
elif [[ -f "$PROJECT_DIR/composer.json" ]]; then
  LANG_PACK="PHP"
elif [[ -f "$PROJECT_DIR/Gemfile" ]]; then
  LANG_PACK="Ruby"
elif compgen -G "$PROJECT_DIR/*.tf" >/dev/null 2>&1; then
  LANG_PACK="Terraform"
fi

if [[ -n "$LANG_PACK" ]]; then
  OUTPUT="${OUTPUT:+$OUTPUT }[Language: $LANG_PACK]"
fi

# 3. Check for context index
CTX_INDEX="$PROJECT_DIR/.context-index/PROJECT.ctx"
if [[ -f "$CTX_INDEX" ]]; then
  OUTPUT="${OUTPUT:+$OUTPUT }[Context index available]"
fi

# 4. Check for active specs
# Guard against missing specs/ dir under pipefail (find failure + || echo 0 = "0\n0")
SPEC_COUNT=0
if [[ -d "$PROJECT_DIR/specs" ]]; then
  SPEC_COUNT=$(find "$PROJECT_DIR/specs" -name "*.spec.md" 2>/dev/null | wc -l | tr -d '[:space:]')
  SPEC_COUNT="${SPEC_COUNT:-0}"
fi
if [[ "$SPEC_COUNT" -gt 0 ]]; then
  OUTPUT="${OUTPUT:+$OUTPUT }[Specs: $SPEC_COUNT]"
fi

# Inject context
if [[ -n "$OUTPUT" ]]; then
  echo "$OUTPUT"
fi

exit 0
