# Troubleshooting — Common Issues & Solutions

Quick reference for diagnosing and fixing common pm-workspace problems.

## Hook Issues

### Problem: Hook Blocking Operation Unexpectedly

**Symptoms:** Edit or bash command blocked, cryptic error message

**Causes & Solutions:**

| Cause | Check | Fix |
|---|---|---|
| Bash syntax unsafe | `bash -n script.sh` | Add `set -uo pipefail` at top of script |
| Unquoted variables | `grep '\$[A-Za-z]' script.sh` | Quote all variables: `"$VAR"` not `$VAR` |
| Script loops | Check for `for`, `while` | Use `(...)` subshell, not bare loops |
| Credentials detected | Check error message | Remove hardcoded secrets, use env vars |
| Force push detected | Check git command | Use regular push, or delete branch first |

**Quick debug:**

```bash
# Enable hook debug output
bash -x ~/.claude/hooks/block-credential-leak.sh < input.json

# Test hook directly with sample input
echo '{"tool_input":{"command":"git push"}}' | \
  bash ~/.claude/hooks/block-force-push.sh
```

### Problem: Hook Tests Failing

**Symptoms:** `bats tests/hooks/test-*.sh` shows failures

**Solution:**

```bash
# Install BATS if missing
npm install -g bats

# Verify jq is available (required by most hooks)
command -v jq || sudo apt-get install jq

# Run single hook test with verbose output
bats tests/hooks/test-block-credential-leak.sh -v

# Run all hook tests
bash scripts/test-hooks.sh
```

### Problem: False Positives (Hook Blocks Valid Code)

**Symptoms:** Legitimate operation blocked (e.g., valid test name matches pattern)

**Solution:** Check `.claude/hooks/*.sh` for exclusion lists:

```bash
# Example: scope-guard.sh excludes test files
case "$BASENAME" in
  *Test*|*test*|*.test.*) continue ;;  # Exempt from scope check
esac
```

Add your exception pattern to the relevant case statement.

---

## Test Execution Issues

### Problem: Tests Won't Run / BATS Not Found

**Solution:**

```bash
# Install BATS globally
npm install -g bats

# Or run via Docker
docker run --rm -v "$(pwd):/code" -w /code bats:latest tests/

# Verify installation
bats --versión
```

### Problem: Tests Fail With jq Errors

**Symptoms:** `jq: command not found` in test output

**Solution:**

```bash
# Install jq
sudo apt-get install -y jq
# or macOS:
brew install jq

# Verify
jq --versión
```

### Problem: Coverage Report Shows Wrong Numbers

**Symptoms:** Coverage percentage seems incorrect or incomplete

**Cause:** Test harness not collecting traces properly

**Solution:**

```bash
# For .NET
dotnet test --collect "XPlat Code Coverage" --configuration Release

# For Node.js/JavaScript
npm test -- --coverage --coverageReporters="text"

# For Python
pytest --cov=. --cov-report=term-output

# Then regenerate report
reportgenerator -reports:"**/coverage.cobertura.xml" -targetdir:"./output/coverage"
```

---

## Compliance & Security Issues

### Problem: Security Scan False Positives

**Symptoms:** Flagged secrets are actually placeholders, not real

**Example:** `USER_PASSWORD=TU_CONTRASEÑA` is flagged but not a real secret

**Solution:** Mark intentional placeholders:

```bash
# Option 1: Use UPPERCASE placeholder text (regex excludes it)
USER_PASSWORD="PLACEHOLDER_PASSWORD"
API_KEY="EXAMPLE_API_KEY"

# Option 2: Use .example or .template extensión
config.local.json.example    # Not scanned
settings.template.json       # Not scanned

# Option 3: Comment as example
# Example: password=MyActualPassword123
password = "${ENV_PASSWORD}"  # Use env var instead
```

### Problem: Compliance Gate Rejecting Valid Commit

**Symptoms:** CHANGELOG.md, frontmatter, or README issues mentioned

**Solution:**

```bash
# Check CHANGELOG format
grep -n '## \[' CHANGELOG.md | head -5
# Should show versions in descending order: v1.2.0, v1.1.1, v1.1.0

# Check command/skill line counts
wc -l .claude/commands/*.md | sort -n | tail -10
wc -l .claude/skills/*/*.md | sort -n | tail -10
# Should all be ≤ 150 lines

# Check frontmatter in new commands
head -10 .claude/commands/my-new-command.md
# Should have: name, description, arguments (if needed)

# Run compliance check manually
bash .claude/compliance/runner.sh --staged
```

---

## Context & Performance Issues

### Problem: Context Budget Exceeded

**Symptoms:** `/dev-session` or `/spec-generate` fails with context warning

**Solution:**

```bash
# Check current context usage
/context-budget --show

# If >80%, compact immediately
/compact

# Then retry operation
/dev-session start my-spec
```

### Problem: Commands Running Slow

**Symptoms:** Slash command takes >30 seconds

**Cause:** Loading too much context or running serial when should be parallel

**Solution:**

```bash
# Check if skill is loading unnecessary files
grep -n "^Read" .claude/skills/my-skill/SKILL.md
# Reduce file reads, load on-demand instead

# Use parallel execution if possible
# Instead of: agent1 → agent2 → agent3 (serial, 120s)
# Use: agent1 ‖ agent2 ‖ agent3 (parallel, 40s)
```

---

## Hook Debugging Deep Dive

### Enable Hook Tracing

```bash
# Set debug mode in environment
export CLAUDE_HOOK_DEBUG=1

# Run hook with full trace
bash -x ~/.claude/hooks/scope-guard.sh < input.json

# Check hook logs (if persistent logging enabled)
tail -100 ~/.pm-workspace/hook-trace.log
```

### Inspect Hook Input

Hooks receive JSON via stdin. To see what's being passed:

```bash
# Before a tool execution, echo the input
cat > debug-hook-input.sh << 'EOF'
#!/bin/bash
INPUT=$(cat)
echo "Hook received: $INPUT" >> /tmp/hook-debug.log
echo "$INPUT" | jq . >> /tmp/hook-debug.log
echo "$INPUT"  # Pass through to actual hook
EOF

chmod +x debug-hook-input.sh

# Then swap in settings.json temporarily to debug
```

### Test Hook in Isolation

```bash
# Create sample JSON matching hook's expected format
cat > test-input.json << 'EOF'
{
  "tool_name": "Edit",
  "tool_input": {
    "file_path": "src/UserService.cs",
    "old_string": "public User Create()",
    "new_string": "public User CreateAsync()"
  }
}
EOF

# Run hook against sample
bash ~/.claude/hooks/tdd-gate.sh < test-input.json
echo "Exit code: $?"
```

---

## Specific Hook Troubleshooting

### `block-credential-leak` False Positives

**Issue:** Real passwords flagged

**Check:** `grep -E '(password|secret)=' ~/.claude/hooks/block-credential-leak.sh`

**Regex patterns match:**
- `password="ACTUAL_PASSWORD"` — BLOCKED
- `password="${ENV_PASSWORD}"` — ALLOWED
- `password="PLACEHOLDER"` — ALLOWED

Fix: Use env vars or uppercase placeholders.

### `tdd-gate` Blocking Valid Edit

**Issue:** Editing test file, but hook requires test for test (circular)

**Check:** Pattern in hook:

```bash
case "$BASENAME" in
  *Test*|*test*|*.test.*|*.spec.*) exit 0 ;;  # Skip tests themselves
esac
```

Fix: Ensure test filename matches one of these patterns.

### `pre-commit-review` Requiring Impossible Condition

**Issue:** Want to commit but hook wants impossible combination

**Check:** Which check is failing: branch? tests? format? code review?

```bash
# Run checks individually to identify culprit
bash ~/.claude/hooks/pre-commit-review.sh --check-branch
bash ~/.claude/hooks/pre-commit-review.sh --check-tests
bash ~/.claude/hooks/pre-commit-review.sh --check-format
bash ~/.claude/hooks/pre-commit-review.sh --check-review
```

Fix: Address the specific failing check, or request hook override from team lead.

---

## Skipping Hooks Temporarily (Last Resort)

**WARNING:** Only for development/debugging. Never skip in production.

```bash
# Skip a single hook for one command (if supported)
SKIP_HOOKS="tdd-gate" bash command.sh

# Temporarily disable all PreToolUse hooks (not recommended)
# Edit settings.json, comment out PreToolUse section, then restore

# After skipping, ALWAYS:
# 1. Understand why you skipped
# 2. Fix the underlying issue
# 3. Re-enable the hook
# 4. Commit with explanation
```

---

## When to Escalate

**Escalate to team if:**

1. Hook blocks legitimate operation consistently → report false positive
2. Test coverage report mysteriously drops → audit CI/CD
3. Hook timeout: scripts exceed 30s → profile and optimize
4. Context exhaustion: frequent >85% usage → review context loading strategy
5. Conflicting requirements: two rules contradict → rules need reconciliation

**Report with:**

```
Hook/Issue: [name]
Reproduction: [steps to reproduce]
Expected: [what should happen]
Actual: [what happened]
Environment: [OS, tool versions]
Logs: [relevant error messages]
```

---

## See Also

- `docs/HOOKS.md` — Complete hook reference
- `docs/ARCHITECTURE.md` — System design
- Command: `/help hooks` — List all hooks
- Command: `/agent-trace` — View recent executions
- Script: `scripts/validate-ci-local.sh` — Run full pre-commit suite locally
