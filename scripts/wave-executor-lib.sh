#!/usr/bin/env bash
# wave-executor-lib.sh — Helper functions for wave-executor.sh

detect_timeout_cmd() {
  if command -v timeout >/dev/null 2>&1; then
    if timeout --version 2>&1 | grep -q 'coreutils'; then echo "timeout"
    elif command -v gtimeout >/dev/null 2>&1; then echo "gtimeout"
    else echo "timeout"; fi
  elif command -v gtimeout >/dev/null 2>&1; then echo "gtimeout"
  else echo ""; fi
}

validate_graph() {
  local gf="$1"
  local count; count=$(jq '.tasks | length' "$gf" 2>/dev/null) || { echo "bad JSON" >&2; return 1; }
  [[ $count -gt 100 ]] && { echo "too many tasks: $count (max 100)" >&2; return 1; }
  local dupes; dupes=$(jq -r '.tasks[].id' "$gf" | tr -d '\r' | sort | uniq -d | head -1)
  [[ -n "$dupes" ]] && { echo "duplicate task id: $dupes" >&2; return 1; }
  local all_ids; all_ids=$(jq -r '.tasks[].id' "$gf" | tr -d '\r')
  local dep_check; dep_check=$(jq -r '.tasks[] | .depends_on[]' "$gf" 2>/dev/null | tr -d '\r' | while read -r dep; do
    echo "$all_ids" | grep -qx "$dep" || echo "$dep"
  done | head -1)
  [[ -n "$dep_check" ]] && { echo "unknown dependency: $dep_check" >&2; return 1; }
  local cycle; cycle=$(jq -r '
    .tasks as $t |
    ($t | map({(.id): [.depends_on[]]}) | add // {}) as $d |
    ($t | map(.id)) as $a |
    {q: [$a[] | select(($d[.] // []) | length == 0)], r: [], d: $d} |
    until(.q | length == 0;
      .q[0] as $n | .r += [$n] | .q |= .[1:] |
      reduce ($a[] | select(($d[.] // []) | index($n) != null)) as $m (
        .; .d[$m] |= (. - [$n]) |
        if (.d[$m] | length) == 0 then .q += [$m] else . end))
    | if (.r | length) != ($a | length) then "cycle detected" else "ok" end
  ' "$gf")
  cycle=$(echo "$cycle" | tr -d '\r')
  [[ "$cycle" == "cycle detected" ]] && { echo "cycle detected" >&2; return 1; }
  local bad; bad=$(jq -r '.tasks[].expected_files[]?' "$gf" | tr -d '\r' | grep '\.\.' | head -1)
  [[ -n "$bad" ]] && { echo "path traversal: $bad" >&2; return 1; }
  return 0
}

compute_waves() {
  local gf="$1" mp="$2"
  jq -r --argjson mp "$mp" '
    .tasks as $t |
    ($t | map({(.id): [.depends_on[]]}) | add // {}) as $d |
    (reduce range(100) as $_ (
      {l: {}, ok: false};
      reduce $t[].id as $id (.;
        if ($d[$id] // []) | length == 0 then .l[$id] = (.l[$id] // 0)
        elif ([$d[$id][] as $x | .l[$x] // null] | all(. != null)) then
          .l[$id] = ([$d[$id][] as $x | .l[$x]] | max + 1)
        else . end)
    )).l as $levels |
    ($levels | to_entries | group_by(.value) | sort_by(.[0].value)) |
    [.[] | [.[].key] | [range(0; length; $mp) as $i | .[$i:$i+$mp]]] | flatten(1)
  ' "$gf"
}

verify_expected_files() {
  local gf="$1" tid="$2"
  local files; files=$(jq -r --arg id "$tid" '.tasks[] | select(.id==$id) | .expected_files[]?' "$gf")
  [[ -z "$files" ]] && return 0
  while IFS= read -r f; do [[ ! -e "$f" ]] && return 1; done <<< "$files"
  return 0
}
