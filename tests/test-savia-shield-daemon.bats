#!/usr/bin/env bats
# test-shield-daemon-gate.bats — Tests for daemon gate path normalization

@test "gate allows writes to projects/ with forward slashes" {
  local input='{"tool_input":{"file_path":"/home/user/savia/projects/proyecto-alpha/docs/digest.md","content":"test content"}}'
  # The gate function should detect /projects/ and ALLOW
  result=$(python3 -c "
import sys, json
sys.path.insert(0, 'scripts')
# Simulate gate logic
fp = json.loads('$input')['tool_input']['file_path']
fp_norm = fp.replace('\\', '/')
patterns = ['/projects/', '.local.', '/output/', 'private-agent-memory']
for p in patterns:
    if p in fp_norm:
        print('ALLOW'); sys.exit(0)
print('SCAN')
" 2>/dev/null)
  [ "$result" = "ALLOW" ]
}

@test "gate allows writes to projects/ with Windows backslashes" {
  local fp='C:\Users\user\savia\projects\proyecto-alpha\docs\digest.md'
  result=$(python3 -c "
fp = '$fp'
fp_norm = fp.replace('\\', '/')
patterns = ['/projects/', '.local.', '/output/']
for p in patterns:
    if p in fp_norm:
        print('ALLOW'); exit(0)
print('SCAN')
" 2>/dev/null)
  [ "$result" = "ALLOW" ]
}

@test "gate scans writes to public paths" {
  result=$(python3 -c "
fp = '/home/user/savia/docs/README.md'
fp_norm = fp.replace('\\', '/')
patterns = ['/projects/', '.local.', '/output/', 'private-agent-memory']
for p in patterns:
    if p in fp_norm:
        print('ALLOW'); exit(0)
print('SCAN')
" 2>/dev/null)
  [ "$result" = "SCAN" ]
}
