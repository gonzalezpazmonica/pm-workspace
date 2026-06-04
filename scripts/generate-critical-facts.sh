#!/usr/bin/env bash
# scripts/generate-critical-facts.sh
# SPEC-185: Auto-regenerates the CRITICAL_FACTS section of docs/critical-facts.md
# from authoritative sources (active profile, preferences, CLAUDE.md gates).
# Idempotent: same inputs → same output. Determinism is required for AC4.

set -uo pipefail

FILE="docs/critical-facts.md"
PROFILE_FILE=".claude/profiles/active-user.md"
PREFS_FILE="${HOME}/.savia/preferences.yaml"

# Defaults (fallbacks if sources missing)
LANG="español"
USER_SLUG="unknown"
ACTIVATED="unknown"
FRONTEND="opencode"
PROVIDER="anthropic"
MODEL="claude-opus"
SPRINT="PM-Workspace activo · cadencia 2 sem · daily 09:15"

# Active user slug
if [[ -f "$PROFILE_FILE" ]]; then
  USER_SLUG=$(grep -E '^active_slug:' "$PROFILE_FILE" 2>/dev/null | head -1 | sed 's/.*"\([^"]*\)".*/\1/')
  ACTIVATED=$(grep -E '^activated_at:' "$PROFILE_FILE" 2>/dev/null | head -1 | sed 's/.*"\([^"]*\)".*/\1/')
fi

# Preferences
if [[ -f "$PREFS_FILE" ]]; then
  V=$(grep -E '^frontend:' "$PREFS_FILE" | awk '{print $2}'); [[ -n "$V" ]] && FRONTEND="$V"
  V=$(grep -E '^provider:' "$PREFS_FILE" | awk '{print $2}'); [[ -n "$V" ]] && PROVIDER="$V"
  V=$(grep -E '^model_heavy:' "$PREFS_FILE" | awk '{print $2}'); [[ -n "$V" ]] && MODEL="$V"
fi

# Build new section content
read -r -d '' NEW_CONTENT <<EOF || true
- **Idioma activo**: $LANG (perfil \`$USER_SLUG\`)
- **Usuario activo**: $USER_SLUG · profile slug \`$USER_SLUG\` · activated $ACTIVATED
- **Frontend**: $FRONTEND · provider $PROVIDER · model $MODEL
- **Sprint**: $SPRINT
- **Gates inmutables**: Rule 1 PAT via \$(cat \$PAT_FILE) · Rule 3 confirmar antes de escribir Azure DevOps · Rule 8 NUNCA merge/approve autónomo · autonomous-safety: rama \`agent/*\` + PR Draft + AUTONOMOUS_REVIEWER obligatorio
- **Tono**: Radical Honesty (Rule 24) · sin filler · femenino siempre (Savia)
EOF

# Replace section between markers
TMP=$(mktemp)
awk -v new="$NEW_CONTENT" '
  /<!-- CRITICAL_FACTS_START -->/ { print; print new; in_section=1; next }
  /<!-- CRITICAL_FACTS_END -->/ { in_section=0 }
  !in_section { print }
' "$FILE" > "$TMP"

mv "$TMP" "$FILE"
echo "Regenerated $FILE from active profile + preferences"
