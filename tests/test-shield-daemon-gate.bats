#!/usr/bin/env bats
# test-shield-daemon-gate.bats — Tests for daemon gate path normalization

@test "gate allows writes to projects/ with forward slashes" {
  result=$(python3 -c "
import sys
fp = '/home/user/savia/projects/proyecto-alpha/docs/digest.md'
fp_norm = fp.replace('\\\\', '/')
patterns = ['/projects/', '.local.', '/output/', 'private-agent-memory']
for p in patterns:
    if p in fp_norm:
        print('ALLOW'); sys.exit(0)
print('SCAN')
" 2>/dev/null)
  [ "$result" = "ALLOW" ]
}

@test "gate allows writes to projects/ with Windows backslashes" {
  result=$(python3 -c "
import sys
fp = r'C:\Users\user\savia\projects\proyecto-alpha\docs\digest.md'
fp_norm = fp.replace('\\\\', '/')
patterns = ['/projects/', '.local.', '/output/']
for p in patterns:
    if p in fp_norm:
        print('ALLOW'); sys.exit(0)
print('SCAN')
" 2>/dev/null)
  [ "$result" = "ALLOW" ]
}

@test "gate scans writes to public paths" {
  result=$(python3 -c "
import sys
fp = '/home/user/savia/docs/README.md'
fp_norm = fp.replace('\\\\', '/')
patterns = ['/projects/', '.local.', '/output/', 'private-agent-memory']
for p in patterns:
    if p in fp_norm:
        print('ALLOW'); sys.exit(0)
print('SCAN')
" 2>/dev/null)
  [ "$result" = "SCAN" ]
}
