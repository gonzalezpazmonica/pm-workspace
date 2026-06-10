#!/usr/bin/env bash
# frontier-strategy.sh — SE-216 Slice 3: frontier selection strategies
# Ref: docs/propuestas/SE-216-evo-patterns.md
set -uo pipefail

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

_usage() {
  cat >&2 <<'EOF'
Usage: frontier-strategy.sh select [options]

Options:
  --strategy STRAT       argmax | top_k | epsilon_greedy | softmax | pareto_per_task
                         (default: pareto_per_task)
  --k N                  Number of items to return (default: 1)
  --input-file FILE      Path to JSON input file
  --input-json JSON      Inline JSON string
  --epsilon F            Epsilon for epsilon_greedy (default: 0.1)
  --temperature F        Temperature for softmax (default: 1.0)

If neither --input-file nor --input-json is given, reads from stdin.

Input format:
  [{"id": "...", "scores": {"task1": 0.8, "task2": 0.6}, "metadata": {}}]

Output format:
  [{"id": "...", "reason": "...", "rank": 1}]
EOF
  exit 1
}

_die() {
  echo "ERROR: $*" >&2
  exit 1
}

# ---------------------------------------------------------------------------
# Python implementation
# ---------------------------------------------------------------------------

_select_py() {
  python3 - "$@" <<'PYEOF'
import sys
import json
import math
import random

VALID_STRATEGIES = ["argmax", "top_k", "epsilon_greedy", "softmax", "pareto_per_task"]


def avg_score(item):
    scores = item.get("scores", {})
    if not scores:
        return 0.0
    return sum(scores.values()) / len(scores)


def strategy_argmax(items, k, **_kwargs):
    ranked = sorted(items, key=avg_score, reverse=True)
    selected = ranked[:k]
    return [
        {"id": it["id"], "reason": f"argmax: score {avg_score(it):.2f}", "rank": i + 1}
        for i, it in enumerate(selected)
    ]


def strategy_top_k(items, k, **_kwargs):
    ranked = sorted(items, key=avg_score, reverse=True)
    selected = ranked[:k]
    return [
        {"id": it["id"], "reason": f"top_k: score {avg_score(it):.2f}", "rank": i + 1}
        for i, it in enumerate(selected)
    ]


def strategy_epsilon_greedy(items, k, epsilon=0.1, **_kwargs):
    if not items:
        return []
    results = []
    remaining = list(items)
    for rank in range(1, k + 1):
        if not remaining:
            break
        if random.random() < epsilon:
            chosen = random.choice(remaining)
            reason = f"epsilon_greedy: random (epsilon={epsilon:.3f})"
        else:
            chosen = max(remaining, key=avg_score)
            reason = f"epsilon_greedy: argmax (epsilon={epsilon:.3f}), score {avg_score(chosen):.2f}"
        results.append({"id": chosen["id"], "reason": reason, "rank": rank})
        remaining = [x for x in remaining if x["id"] != chosen["id"]]
    return results


def strategy_softmax(items, k, temperature=1.0, **_kwargs):
    if not items:
        return []
    scores = [avg_score(it) for it in items]
    # Numerical stability: subtract max before exp
    max_s = max(scores)
    weights = [math.exp((s - max_s) / max(temperature, 1e-9)) for s in scores]
    total = sum(weights)
    probs = [w / total for w in weights]

    # Sample k distinct items without replacement
    available = list(range(len(items)))
    selected_indices = []
    for _ in range(min(k, len(items))):
        if not available:
            break
        av_probs = [probs[i] for i in available]
        s = sum(av_probs)
        if s <= 0:
            idx = random.choice(available)
        else:
            norm_probs = [p / s for p in av_probs]
            r = random.random()
            cumulative = 0.0
            idx = available[-1]
            for j, p in zip(available, norm_probs):
                cumulative += p
                if r <= cumulative:
                    idx = j
                    break
        selected_indices.append(idx)
        available.remove(idx)

    return [
        {
            "id": items[idx]["id"],
            "reason": f"softmax: T={temperature:.3f}, score {avg_score(items[idx]):.2f}",
            "rank": rank + 1,
        }
        for rank, idx in enumerate(selected_indices)
    ]


def strategy_pareto_per_task(items, k, **_kwargs):
    if not items:
        return []

    # Collect all task keys
    all_tasks = set()
    for it in items:
        all_tasks.update(it.get("scores", {}).keys())

    if not all_tasks:
        # No scores at all — fall back to argmax
        return strategy_argmax(items, k)

    # For each task, find the item(s) with the highest score
    specialists = {}  # item_id -> list of tasks they dominate
    for task in all_tasks:
        best_score = -float("inf")
        best_items = []
        for it in items:
            s = it.get("scores", {}).get(task, 0.0)
            if s > best_score:
                best_score = s
                best_items = [it]
            elif s == best_score:
                best_items.append(it)
        for it in best_items:
            specialists.setdefault(it["id"], []).append(task)

    # Sort specialists by number of tasks dominated (desc), then avg_score (desc)
    specialist_items = [it for it in items if it["id"] in specialists]
    specialist_items.sort(
        key=lambda it: (len(specialists[it["id"]]), avg_score(it)), reverse=True
    )

    selected = specialist_items[:k]
    results = []
    for rank, it in enumerate(selected):
        tasks_dominated = specialists[it["id"]]
        reason = f"pareto-specialist: {', '.join(sorted(tasks_dominated))}"
        results.append({"id": it["id"], "reason": reason, "rank": rank + 1})
    return results


STRATEGIES = {
    "argmax": strategy_argmax,
    "top_k": strategy_top_k,
    "epsilon_greedy": strategy_epsilon_greedy,
    "softmax": strategy_softmax,
    "pareto_per_task": strategy_pareto_per_task,
}


def main():
    args = sys.argv[1:]

    strategy = "pareto_per_task"
    k = 1
    input_file = None
    input_json = None
    epsilon = 0.1
    temperature = 1.0

    i = 0
    while i < len(args):
        a = args[i]
        if a == "--strategy":
            strategy = args[i + 1]; i += 2
        elif a == "--k":
            k = int(args[i + 1]); i += 2
        elif a == "--input-file":
            input_file = args[i + 1]; i += 2
        elif a == "--input-json":
            input_json = args[i + 1]; i += 2
        elif a == "--epsilon":
            epsilon = float(args[i + 1]); i += 2
        elif a == "--temperature":
            temperature = float(args[i + 1]); i += 2
        else:
            i += 1

    if strategy not in STRATEGIES:
        print(
            f"ERROR: unknown strategy '{strategy}'. Valid: {', '.join(STRATEGIES.keys())}",
            file=sys.stderr,
        )
        sys.exit(1)

    if input_file is not None:
        with open(input_file) as f:
            items = json.load(f)
    elif input_json is not None:
        items = json.loads(input_json)
    else:
        items = json.load(sys.stdin)

    if not isinstance(items, list):
        print("ERROR: input must be a JSON array", file=sys.stderr)
        sys.exit(1)
    if not items:
        print("[]")
        return

    fn = STRATEGIES[strategy]
    result = fn(items, k, epsilon=epsilon, temperature=temperature)
    print(json.dumps(result))


main()
PYEOF
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

[[ $# -lt 1 ]] && _usage

SUBCOMMAND="${1:-}"
shift || true

case "$SUBCOMMAND" in
  select)
    # If neither --input-file nor --input-json is given, read stdin into a
    # variable and inject it as --input-json. This is required because the
    # Python heredoc consumes stdin before the script body can read it.
    _has_input=0
    for _arg in "$@"; do
      [[ "$_arg" == "--input-file" || "$_arg" == "--input-json" ]] && _has_input=1 && break
    done
    if [[ $_has_input -eq 0 ]]; then
      _stdin_data=$(cat)
      _select_py "$@" --input-json "$_stdin_data"
    else
      _select_py "$@"
    fi
    ;;
  help|--help|-h)
    _usage
    ;;
  *)
    _die "Unknown subcommand '${SUBCOMMAND}'. Use: select"
    ;;
esac
