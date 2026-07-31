#!/usr/bin/env bash
# always-on-install-cron.sh — Install scheduled monitoring detectors (SE-279 S3)
#
# Installs crontab entries for always-on detectors.
# Supports --dry-run, --remove, --list modes.
# Alternative: systemd timer (Linux) or launchd (macOS).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DETECTORS_DIR="${SCRIPT_DIR}/always-on/detectors"
RUNNER="${SCRIPT_DIR}/always-on-runner.sh"
CRONTAB_TEMPLATE="${SCRIPT_DIR}/always-on/crontab.template"
CRONTAB_MARKER="# >>> SE-279 always-on detectors >>>"
CRONTAB_END_MARKER="# <<< SE-279 always-on detectors <<<"

MODE="install"

usage() {
  cat <<USG
Usage: always-on-install-cron.sh [--dry-run] [--remove] [--list]

Modes:
  (default)  Install crontab entries for always-on detectors
  --dry-run   Show what would be installed
  --remove    Remove SE-279 crontab entries
  --list      List currently installed SE-279 entries
USG
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) MODE="dry-run"; shift ;;
    --remove) MODE="remove"; shift ;;
    --list) MODE="list"; shift ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage >&2; exit 2 ;;
  esac
done

# --- Detector schedule definitions ---
# Format: cron_expression detector_id description
declare -a SCHEDULES=(
  "0 9-18/4 * * 1-5|sprint-blocker-watch|Check blocked PBIs > 48h (every 4h, work hours)"
  "0 */6 * * *|pr-stale-watch|Check stale PRs > 24h (every 6h)"
  "0 7 * * *|drift-daily|Daily drift check (07:00)"
  "0 9 * * 1|dependency-cve-watch|Weekly CVE scan (Monday 09:00)"
  "0 2 * * *|memory-consolidation|Daily memory consolidation check (02:00)"
)

generate_entries() {
  echo "$CRONTAB_MARKER"
  echo "# Installed by scripts/always-on-install-cron.sh (SE-279)"
  echo "# $(date)"
  echo "#"

  for entry in "${SCHEDULES[@]}"; do
    IFS='|' read -r cron_expr detector_id description <<< "$entry"
    DETECTOR_SCRIPT="${DETECTORS_DIR}/${detector_id}.sh"

    if [[ -f "$DETECTOR_SCRIPT" ]]; then
      echo "$cron_expr cd $SCRIPT_DIR/.. && bash $RUNNER $detector_id >> output/always-on/cron.log 2>&1 # $description"
    else
      echo "# $cron_expr (SKIPPED: detector $detector_id not found) # $description"
    fi
  done

  echo "$CRONTAB_END_MARKER"
}

case "$MODE" in
  list)
    echo "==> SE-279 crontab entries"
    crontab -l 2>/dev/null | grep -A 20 "$CRONTAB_MARKER" | grep -B 20 "$CRONTAB_END_MARKER" || echo "  No SE-279 entries found."
    ;;

  dry-run)
    echo "==> Would install these crontab entries:"
    echo ""
    generate_entries
    ;;

  remove)
    echo "==> Removing SE-279 crontab entries..."
    CURRENT=$(crontab -l 2>/dev/null || echo "")
    if echo "$CURRENT" | grep -q "$CRONTAB_MARKER"; then
      NEW=$(echo "$CURRENT" | sed "/$CRONTAB_MARKER/,/$CRONTAB_END_MARKER/d")
      echo "$NEW" | crontab -
      echo "  Removed."
    else
      echo "  No SE-279 entries found."
    fi
    ;;

  install)
    echo "==> Installing SE-279 crontab entries..."

    # Check runner exists
    if [[ ! -f "$RUNNER" ]]; then
      echo "ERROR: always-on-runner.sh not found at $RUNNER" >&2
      exit 1
    fi

    # Remove existing entries first (idempotent)
    CURRENT=$(crontab -l 2>/dev/null || echo "")
    if echo "$CURRENT" | grep -q "$CRONTAB_MARKER"; then
      CURRENT=$(echo "$CURRENT" | sed "/$CRONTAB_MARKER/,/$CRONTAB_END_MARKER/d")
    fi

    # Append new entries
    NEW_ENTRIES=$(generate_entries)
    printf '%s\n\n%s\n' "$CURRENT" "$NEW_ENTRIES" | crontab -

    echo "  Installed $(echo "$NEW_ENTRIES" | grep -c '^[0-9*]') detectors."
    echo "  Logs: output/always-on/cron.log"
    echo ""
    echo "  Verify with: crontab -l | grep SE-279"
    ;;
esac
