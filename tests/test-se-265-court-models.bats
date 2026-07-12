#!/usr/bin/env bats
# tests/test-se-265-court-models.bats — Tests for SE-265 model tier assignment

@test "SE265-T01: court rules has models section" {
  python3 -c "
import yaml
d = yaml.safe_load(open('rules/court.rules.yaml'))
assert 'models' in d
assert d['models']['default'] == 'mid'
"
}

@test "SE265-T02: security-judge assigned heavy by default" {
  python3 -c "
import yaml
d = yaml.safe_load(open('rules/court.rules.yaml'))
assert d['models']['per_judge']['security-judge'] == 'heavy'
"
}

@test "SE265-T03: correctness-judge assigned heavy by default" {
  python3 -c "
import yaml
d = yaml.safe_load(open('rules/court.rules.yaml'))
assert d['models']['per_judge']['correctness-judge'] == 'heavy'
"
}

@test "SE265-T04: cognitive-judge assigned fast by default" {
  python3 -c "
import yaml
d = yaml.safe_load(open('rules/court.rules.yaml'))
assert d['models']['per_judge']['cognitive-judge'] == 'fast'
"
}

@test "SE265-T05: spec-judge assigned fast by default" {
  python3 -c "
import yaml
d = yaml.safe_load(open('rules/court.rules.yaml'))
assert d['models']['per_judge']['spec-judge'] == 'fast'
"
}

@test "SE265-T06: architecture-judge assigned mid by default" {
  python3 -c "
import yaml
d = yaml.safe_load(open('rules/court.rules.yaml'))
assert d['models']['per_judge']['architecture-judge'] == 'mid'
"
}

@test "SE265-T07: all 5 judges have model assignments" {
  python3 -c "
import yaml
d = yaml.safe_load(open('rules/court.rules.yaml'))
judges = d['models']['per_judge']
assert len(judges) == 5
for j in ['security-judge','correctness-judge','architecture-judge','cognitive-judge','spec-judge']:
    assert j in judges, f'{j} missing'
"
}

@test "SE265-T08: safety flag prevents degrading critical judges" {
  python3 -c "
import yaml
d = yaml.safe_load(open('rules/court.rules.yaml'))
assert d['models']['safety']['security_and_correctness_require_heavy'] == True
"
}

@test "SE265-T09: budget has max_tokens and per_judge_min" {
  python3 -c "
import yaml
d = yaml.safe_load(open('rules/court.rules.yaml'))
assert d['models']['budget']['max_total_tokens'] > 0
assert d['models']['budget']['per_judge_min_tokens'] > 0
"
}

@test "SE265-T10: operator can override model assignments" {
  python3 -c "
import yaml
d = yaml.safe_load(open('rules/court.rules.yaml'))
assert d['models']['safety']['allow_operator_override'] == True
"
}
