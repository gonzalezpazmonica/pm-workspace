#!/usr/bin/env bash
# criticality-scoring.sh — Pure scoring functions. Sourced by criticality-engine.sh.
# Scores are integer hundredths (0..500 = 0.00..5.00): no floating point, so the
# result never depends on LC_NUMERIC (es_ES decimal comma included).
# Frontmatter values are validated with a regex BEFORE any arithmetic: bash
# arithmetic on raw strings evaluates array subscripts such as x[$(cmd)].
set -uo pipefail

W_IMPACT=30 W_URGENCY=25 W_DEPS=20 W_CONF=15 W_EFFORT=10

crit_warn() { echo "WARN: $*" >&2; }

# to_int <value> [round|ceil] — number with '.' or ',' decimal → integer.
# Returns 1 (no output) when the value is not a non-negative number.
to_int() {
  local v="$1" mode="${2:-round}"
  [[ "$v" =~ ^([0-9]{1,6})([.,]([0-9]{1,6}))?$ ]] || return 1
  local n=$((10#${BASH_REMATCH[1]})) frac="${BASH_REMATCH[3]:-}"
  if [[ -n "$frac" ]]; then
    if [[ "$mode" == ceil ]]; then
      [[ "$frac" =~ [1-9] ]] && n=$((n + 1))
    else
      (( ${frac:0:1} >= 5 )) && n=$((n + 1))
    fi
  fi
  echo "$n"
}

# dim_value <raw> <default> <label> <source> — 1..5 dimension (rounded, clamped).
dim_value() {
  local raw="$1" def="$2" label="$3" src="$4" n
  [[ -z "$raw" ]] && { echo "$def"; return 0; }
  if ! n=$(to_int "$raw"); then
    crit_warn "invalid $label '$raw' in $src; using $def"; echo "$def"; return 0
  fi
  (( n < 1 )) && n=1
  (( n > 5 )) && n=5
  echo "$n"
}

# sp_value <raw> <source> — story points rounded up; empty/0 = not estimated → 3.
sp_value() {
  local raw="$1" src="$2" n
  [[ -z "$raw" ]] && { echo 3; return 0; }
  if ! n=$(to_int "$raw" ceil); then
    crit_warn "invalid story points '$raw' in $src; using 3"; echo 3; return 0
  fi
  (( n == 0 )) && n=3
  echo "$n"
}

confidence_decay() {
  local days="${1:-0}"
  if   (( days <= 14 )); then echo 100
  elif (( days <= 30 )); then echo 90
  elif (( days <= 60 )); then echo 75
  elif (( days <= 90 )); then echo 50
  else echo 30; fi
}

urgency_boost() {
  local days_left="${1:-999}" base="${2:-3}" v
  if   (( days_left <= 0 ));  then v=5
  elif (( days_left <= 2 ));  then v=$((base + 3))
  elif (( days_left <= 7 ));  then v=$((base + 2))
  elif (( days_left <= 14 )); then v=$((base + 1))
  else v=$base; fi
  (( v > 5 )) && v=5
  echo "$v"
}

# esfuerzo_inv = 6 - min(5, ceil(SP/4)), kept inside 1..5
effort_inverse() {
  local sp="${1:-3}" c
  c=$(( (sp + 3) / 4 )); (( c > 5 )) && c=5; (( c < 1 )) && c=1
  echo $(( 6 - c ))
}

# Confidence in tenths: base 5 × decay% (90% → 45 = 4.5/5).
conf_tenths() { echo $(( 50 * ${1:-100} / 100 )); }

# compute_score impact urgency deps conf_pct sp → hundredths (0..500)
compute_score() {
  local impact="${1:-3}" urgency="${2:-3}" deps="${3:-1}" conf_pct="${4:-100}" sp="${5:-3}"
  local ei; ei=$(effort_inverse "$sp")
  local c10; c10=$(conf_tenths "$conf_pct")
  echo $(( impact*W_IMPACT + urgency*W_URGENCY + deps*W_DEPS + c10*W_CONF/10 + ei*W_EFFORT ))
}

classify() {
  local s="$1"
  if   (( s >= 400 )); then echo "P0 Critical"
  elif (( s >= 300 )); then echo "P1 High"
  elif (( s >= 200 )); then echo "P2 Medium"
  else echo "P3 Low"; fi
}

# Always '.' as decimal separator, whatever the locale.
score_display() { printf '%d.%02d\n' $(( $1 / 100 )) $(( $1 % 100 )); }

bar5() {
  local v="$1" b="" i
  for i in 1 2 3 4 5; do if (( i <= v )); then b+="█"; else b+="░"; fi; done
  echo "$b"
}
