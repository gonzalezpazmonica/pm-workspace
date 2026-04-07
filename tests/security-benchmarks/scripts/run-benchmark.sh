#!/usr/bin/env bash
set -uo pipefail

# run-benchmark.sh — SPEC-032: Security Benchmark Runner
# Usage: run-benchmark.sh [--target juice-shop] [--compare YYYYMMDD] [--skip-docker]

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${1:-juice-shop}"
COMPARE_DATE=""
SKIP_DOCKER=false
RESULTS_DIR="$BASE_DIR/results"
TODAY=$(date +"%Y%m%d")
RESULT_FILE="$RESULTS_DIR/${TODAY}-${TARGET}.json"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) TARGET="$2"; shift 2 ;;
    --compare) COMPARE_DATE="$2"; shift 2 ;;
    --skip-docker) SKIP_DOCKER=true; shift ;;
    *) shift ;;
  esac
done

mkdir -p "$RESULTS_DIR"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Security Benchmark — $TARGET"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Step 1: Start target
if [[ "$SKIP_DOCKER" == "false" ]]; then
  echo ""
  echo "📦 Starting $TARGET..."
  docker compose -f "$BASE_DIR/docker-compose.yml" up -d "$TARGET" 2>&1

  echo "⏳ Waiting for health check..."
  local_url="http://localhost:3000"
  for i in $(seq 1 30); do
    curl -sf "$local_url" > /dev/null 2>&1 && break
    sleep 2
  done

  if ! curl -sf "$local_url" > /dev/null 2>&1; then
    echo "❌ $TARGET failed to start after 60s"
    docker compose -f "$BASE_DIR/docker-compose.yml" logs "$TARGET" 2>&1 | tail -10
    exit 1
  fi
  echo "✅ $TARGET running at $local_url"
fi

# Step 2: Load known vulnerabilities
KNOWN_VULNS="$BASE_DIR/targets/$TARGET/known-vulns.yaml"
if [[ ! -f "$KNOWN_VULNS" ]]; then
  echo "❌ No known-vulns.yaml for target: $TARGET"
  exit 1
fi

total_known=$(grep -c "^- id:" "$KNOWN_VULNS" || echo 0)
critical_known=$(grep -c 'severity: critical' "$KNOWN_VULNS" || echo 0)
high_known=$(grep -c 'severity: high' "$KNOWN_VULNS" || echo 0)
medium_known=$(grep -c 'severity: medium' "$KNOWN_VULNS" || echo 0)
low_known=$(grep -c 'severity: low' "$KNOWN_VULNS" || echo 0)

echo ""
echo "📋 Known vulnerabilities: $total_known"
echo "   Critical: $critical_known | High: $high_known | Medium: $medium_known | Low: $low_known"

# Step 3: Placeholder for agent scan results
# In full implementation, this invokes security-attacker + pentester agents
# For now, we generate the benchmark structure
echo ""
echo "🔍 Benchmark structure ready. To run full scan:"
echo "   1. Start target: docker compose up -d $TARGET"
echo "   2. Invoke agents: /security-pipeline --target http://localhost:3000"
echo "   3. Compare findings against known-vulns.yaml"
echo "   4. Generate report: run-benchmark.sh --compare $TODAY"

# Step 4: Write result skeleton
cat > "$RESULT_FILE" << EOF
{
  "target": "$TARGET",
  "date": "$TODAY",
  "known_vulns": $total_known,
  "by_severity": {
    "critical": $critical_known,
    "high": $high_known,
    "medium": $medium_known,
    "low": $low_known
  },
  "detected": 0,
  "false_positives": 0,
  "detection_rate": 0,
  "false_positive_rate": 0,
  "agents": {
    "attacker": { "findings": 0, "time_seconds": 0 },
    "pentester": { "findings": 0, "time_seconds": 0 }
  },
  "status": "scaffold_ready"
}
EOF

echo ""
echo "📄 Result skeleton: $RESULT_FILE"

# Step 5: Compare with previous run if requested
if [[ -n "$COMPARE_DATE" ]]; then
  PREV_FILE="$RESULTS_DIR/${COMPARE_DATE}-${TARGET}.json"
  if [[ -f "$PREV_FILE" ]]; then
    echo ""
    echo "📊 Comparison with $COMPARE_DATE:"
    echo "   Previous: $(grep detection_rate "$PREV_FILE" | tr -dc '0-9.')"
    echo "   Current:  $(grep detection_rate "$RESULT_FILE" | tr -dc '0-9.')"
  else
    echo "⚠️  No previous result for $COMPARE_DATE"
  fi
fi

# Step 6: Tear down if we started it
if [[ "$SKIP_DOCKER" == "false" ]]; then
  echo ""
  echo "🧹 Stopping $TARGET..."
  docker compose -f "$BASE_DIR/docker-compose.yml" down 2>&1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Benchmark complete — $TARGET"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
