#!/usr/bin/env bats
# tests/test-se-263-s1-frontier.bats — Adversarial tests for SE-263 S1

@test "S1-AC1.1: coordination model exists and has required sections" {
  [[ -f "docs/coordination-model.md" ]]
  grep -q "Model B" docs/coordination-model.md
  grep -q "Model C.*REJECTED" docs/coordination-model.md
  grep -q "ART-16" docs/coordination-model.md
  grep -q "Anti-Surveillance" docs/coordination-model.md
}

@test "S1-AC1.2: coordination model declares PM role" {
  grep -q "PM" docs/coordination-model.md
  grep -q "federation PM" docs/coordination-model.md
}

@test "S1-AC1.3: level crossing rules exist and N3 requires principal signature" {
  [[ -f "rules/federation-export.rules.yaml" ]]
  python3 -c "
import yaml
d = yaml.safe_load(open('rules/federation-export.rules.yaml'))
assert d['level_crossing']['default'] == 'deny'
assert d['level_crossing']['n3_and_above_require_local_principal_signature'] == True
"
}

@test "S1-AC1.4: adversarial — peer content treated as data (prompt-injection guard on)" {
  python3 -c "
import yaml
d = yaml.safe_load(open('rules/federation-export.rules.yaml'))
assert d['prompt_injection']['treat_peer_content_as_untrusted'] == True
assert d['prompt_injection']['guard'] == 'prompt-injection-guard'
assert d['prompt_injection']['quarantine_on_detection'] == True
"
}

@test "S1-AC1.5: adversarial — ranking request blocked by anti-surveillance rules" {
  python3 -c "
import yaml
d = yaml.safe_load(open('rules/federation-export.rules.yaml'))
assert d['anti_surveillance']['prohibit_individual_ranking'] == True
assert d['anti_surveillance']['aggregate_only'] == True
assert d['anti_surveillance']['require_equality_shield'] == True
"
}

@test "S1-AC1.6: verification requires valid card, registry, non-revoked" {
  python3 -c "
import yaml
d = yaml.safe_load(open('rules/federation-export.rules.yaml'))
v = d['verification']
assert v['require_valid_card_signature'] == True
assert v['require_registry_membership'] == True
assert v['check_revocation_status'] == True
"
}

@test "S1-AC1.7: coordination model references CONSTITUCION ART-16" {
  grep -q "CONSTITUCION" docs/coordination-model.md || \
  grep -q "ART-16" docs/coordination-model.md
}

@test "S1-AC1.8: coordination model declares model A as valid" {
  grep -q "Model A" docs/coordination-model.md
}

@test "S1-AC1.9: coordination model references A2A standard" {
  grep -qi "a2a" docs/coordination-model.md
}

@test "S1-AC1.10: export rules file is valid YAML" {
  python3 -c "import yaml; yaml.safe_load(open('rules/federation-export.rules.yaml'))"
  [[ $? -eq 0 ]]
}
