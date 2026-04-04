#!/usr/bin/env bash
set -uo pipefail
# sovereignty-benchmark.sh — Benchmark pm-workspace prompts with local LLM
# Ref: SPEC-066 — Soberanía Tecnológica Phase 2
# Usage: sovereignty-benchmark.sh [--model MODEL] [--quick]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$REPO_ROOT/output"
MODEL="${SAVIA_BENCHMARK_MODEL:-qwen2.5:3b}"
QUICK=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --model) MODEL="$2"; shift 2 ;;
    --quick) QUICK=true; shift ;;
    --help|-h) echo "Usage: $0 [--model MODEL] [--quick]"; exit 0 ;;
    *) shift ;;
  esac
done

if ! command -v ollama &>/dev/null; then
  echo "ERROR: Ollama not installed." >&2; exit 1
fi

if ! ollama list 2>/dev/null | grep -q "$MODEL"; then
  echo "ERROR: Model '$MODEL' not available. Pull with: ollama pull $MODEL" >&2; exit 1
fi

RESULTS_FILE="$OUTPUT_DIR/sovereignty-benchmark-$(date +%Y%m%d).md"
mkdir -p "$OUTPUT_DIR"

echo "# Sovereignty Benchmark — $MODEL"
echo "> Date: $(date -Iseconds) | Model: $MODEL | Quick: $QUICK"
echo ""

PASS=0
FAIL=0
TOTAL=0

benchmark_prompt() {
  local name="$1" prompt="$2" expect="$3" timeout="${4:-30}"
  TOTAL=$((TOTAL + 1))
  local start end elapsed response

  start=$(date +%s%N)
  response=$(timeout "$timeout" ollama run "$MODEL" "$prompt" 2>/dev/null || echo "TIMEOUT")
  end=$(date +%s%N)
  elapsed=$(( (end - start) / 1000000 ))

  local verdict="FAIL"
  if echo "$response" | grep -qiE "$expect"; then
    verdict="PASS"
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
  fi

  printf "  %-35s %s  %5dms\n" "$name" "$verdict" "$elapsed"
}

echo "## Results"
echo ""

# Basic reasoning
benchmark_prompt "basic-reasoning" \
  "What is 2+2? Answer with just the number." \
  "^4$|^4\." 10

# Markdown generation
benchmark_prompt "markdown-generation" \
  "Generate a markdown table with 3 columns: Name, Role, Status. Add 2 rows with fictional data. Output only the table." \
  "\|.*\|.*\|" 15

# Code understanding
benchmark_prompt "code-understanding" \
  "What does this bash do: set -uo pipefail? Answer in one sentence." \
  "exit|error|undefined|unset|pipe" 15

# Spanish comprehension
benchmark_prompt "spanish-comprehension" \
  "Responde en espanol: Que es un sprint en metodologia agil? Una frase." \
  "sprint|iteracion|periodo|tiempo" 15

# JSON generation
benchmark_prompt "json-generation" \
  "Generate valid JSON: {\"name\": \"test\", \"score\": 85}. Output only the JSON." \
  "name.*test\|score.*85" 10

if [[ "$QUICK" == "false" ]]; then
  # Instruction following
  benchmark_prompt "instruction-following" \
    "List exactly 3 programming languages. Number them 1-3. No explanation." \
    "1\.\|2\.\|3\." 15

  # Technical analysis
  benchmark_prompt "technical-analysis" \
    "Name 2 security risks of curl -k flag. Be brief." \
    "MITM\|certificate\|TLS\|SSL\|man.in.the.middle\|intercept" 20

  # PM context
  benchmark_prompt "pm-context" \
    "What is velocity in Scrum? One sentence." \
    "velocity\|story.point\|sprint\|team\|capacity" 15

  # Spec comprehension
  benchmark_prompt "spec-comprehension" \
    "Read this spec excerpt and identify the problem: 'Users cannot login after session timeout because the refresh token is not validated.' What is the root cause in 10 words or less?" \
    "refresh\|token\|valid\|session" 20

  # Multi-step reasoning
  benchmark_prompt "multi-step-reasoning" \
    "A team has 5 developers, each works 6 hours/day for 10 days. Focus factor is 0.8. What is the total capacity in hours? Show the calculation." \
    "240" 20
fi

echo ""
echo "## Summary"
echo ""
echo "  Model:  $MODEL"
echo "  Passed: $PASS/$TOTAL"
echo "  Failed: $FAIL/$TOTAL"
echo "  Score:  $(( PASS * 100 / TOTAL ))%"

# Save results
{
  echo "# Sovereignty Benchmark — $MODEL"
  echo "Date: $(date -Iseconds)"
  echo "Score: $PASS/$TOTAL ($(( PASS * 100 / TOTAL ))%)"
  echo "Quick: $QUICK"
} > "$RESULTS_FILE" 2>/dev/null || true

if [[ $FAIL -eq 0 ]]; then
  echo ""
  echo "  VERDICT: Model $MODEL is viable for pm-workspace operations."
elif [[ $(( PASS * 100 / TOTAL )) -ge 70 ]]; then
  echo ""
  echo "  VERDICT: Model $MODEL is partially viable ($(( PASS * 100 / TOTAL ))%). Complex tasks may degrade."
else
  echo ""
  echo "  VERDICT: Model $MODEL is NOT viable for pm-workspace. Consider larger model."
fi
