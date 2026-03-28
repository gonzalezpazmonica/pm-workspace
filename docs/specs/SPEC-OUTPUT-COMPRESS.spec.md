# Spec: Output Compression Layer

**Task ID:**        SPEC-OUTPUT-COMPRESS
**PBI padre:**      Context optimization initiative
**Sprint:**         2026-07
**Fecha creacion:** 2026-03-27
**Creado por:**     sdd-spec-writer

**Developer Type:** agent-single
**Asignado a:**     claude-agent
**Estimacion:**     4h
**Estado:**         Pendiente
**Max turns:**      25
**Modelo:**         claude-sonnet-4-6

---

## 1. Contexto y Objetivo

SPEC-001 created `.claude/hooks/bash-output-compress.sh` as a PostToolUse hook.
The hook works but has a fundamental limitation documented at line 103-105 of
the script: **PostToolUse hooks cannot modify TOOL_OUTPUT**. The hook only logs
metrics. Zero tokens are actually saved from Claude's context window.

This spec creates a standalone compression script that wraps Bash commands at
invocation time, so the compressed output is what Claude actually reads. The
script is called by the existing hook (which currently does nothing useful) or
piped inline by any command that produces verbose output.

**Objetivo:** Create `scripts/output-compress.sh` that receives raw tool output
on stdin and emits compressed output on stdout. Target: 60%+ token reduction on
outputs exceeding 30 lines. The existing hook is updated to print compressed
output to stdout (which Claude Code does inject as `additionalContext`).

**Criterios de Aceptacion del PBI:**
- [ ] Token savings are real (compressed output reaches Claude's context)
- [ ] 60%+ reduction on `git log`, `git diff`, `dotnet test`, `validate-ci-local`
- [ ] Zero information loss on outputs under 30 lines
- [ ] No blocking behavior or latency impact on short commands

---

## 2. Contrato Tecnico

### 2.1 Interfaz / Firma

```bash
# scripts/output-compress.sh
# Usage: echo "$OUTPUT" | bash scripts/output-compress.sh [--command CMD] [--max-lines N]
#
# Arguments:
#   --command CMD    Original command string (for specialized filters). Default: "generic"
#   --max-lines N    Maximum output lines after compression. Default: 50
#
# Input:  stdin (raw tool output, any encoding)
# Output: stdout (compressed output, UTF-8, no ANSI codes)
# Exit:   0 always (compression failure = pass through original)
```

### 2.2 Compression Rules (ordered pipeline)

```
Step 1: Strip ANSI escape codes (sed 's/\x1b\[[0-9;]*[a-zA-Z]//g')
Step 2: Remove carriage returns and progress bar lines (\r, spinner chars)
Step 3: Collapse blank lines (multiple blanks -> single blank)
Step 4: Deduplicate consecutive identical lines ("...repeated N times")
Step 5: Apply command-specific filter (see 2.3)
Step 6: Group similar warnings (e.g., 47 "warning CS1591" -> "warning CS1591 (x47)")
Step 7: Truncate stack traces (keep first+last frame, collapse middle)
Step 8: Cap at --max-lines with footer "[... N lines omitted, ~T tokens saved]"
```

### 2.3 Command-Specific Filters

Each filter is a bash function. Selection by pattern matching on `--command`.

```bash
# Filter: git_log
# Match: *"git log"*
# Keep: commit hash (short) + subject line
# Drop: Author, Date, GPG signature, decoration noise
# Output: "abc1234 feat: description" format, one per line

# Filter: git_diff
# Match: *"git diff"*
# Keep: file headers (diff --git, +++, ---), hunk headers (@@), changed lines (+/-)
# Drop: context lines (lines without +/-) when total diff > 100 lines
# Output: diff summary with file list + hunks

# Filter: git_status
# Match: *"git status"*
# Keep: modified/added/deleted/untracked file paths
# Drop: branch info header, hints ("use git add...", "use git checkout...")

# Filter: dotnet_test
# Match: *"dotnet test"*
# Keep: test result summary, failed test names + error messages, coverage %
# Drop: build output, "Determining projects to restore", assembly paths

# Filter: dotnet_build
# Match: *"dotnet build"*
# Keep: error lines (": error "), warning lines grouped by code, summary line
# Drop: "Determining projects to restore", "Restored", timestamps, info lines

# Filter: validate_ci
# Match: *"validate-ci"*
# Keep: PASS/FAIL/WARN lines only
# Drop: separator lines, banner decorations, blank lines between checks

# Filter: npm_pnpm
# Match: *"npm "*|*"pnpm "*
# Keep: errors, warnings (deduplicated), summary line
# Drop: "added N packages", progress, "up to date", audit info

# Filter: generic (fallback)
# Apply: steps 1-4 + 6-8 from section 2.2
```

### 2.4 Dependencies

None. Pure bash (sed, awk, grep, head, tail, wc). No external binaries.

---

## 3. Inputs / Outputs Contract

### Inputs

```
stdin: string
  Raw tool output. May contain:
  - ANSI color codes (\x1b[31m, etc.)
  - Carriage returns (\r) from progress bars
  - UTF-8 text (international characters preserved)
  - Binary garbage (gracefully ignored)
  Size: 0 bytes to ~500KB typical, up to 2MB max

--command: string (optional)
  The original command that produced the output.
  Examples: "git log --oneline -20", "dotnet test", "bash scripts/validate-ci-local.sh"
  Default: "generic"

--max-lines: integer (optional)
  Maximum lines in compressed output.
  Default: 50
  Range: 10-200
```

### Outputs

```
stdout: string (UTF-8, no ANSI codes)
  Compressed output. Properties:
  - Lines <= --max-lines
  - No ANSI escape sequences
  - No carriage return artifacts
  - Consecutive duplicates collapsed
  - Similar warnings grouped
  - Stack traces truncated
  - Footer with compression stats if truncation applied:
    "[... 247 lines -> 48 lines, ~198 tokens saved]"

exit code: 0 (always)
  Compression failure = pass through original (never crash)
```

---

## 4. Reglas de Negocio

| # | Regla | Comportamiento |
|---|-------|---------------|
| RN-01 | Output <= 30 lines passes through unmodified (only ANSI stripped) | No compression, preserve every line |
| RN-02 | Output > 30 lines enters full compression pipeline | All 8 steps applied |
| RN-03 | Command-specific filter selected by longest match on --command | "dotnet test" matches before "dotnet" |
| RN-04 | Dedup threshold: 2+ consecutive identical lines -> collapse | "line [...repeated N times]" |
| RN-05 | Warning grouping threshold: 3+ identical warning codes -> group | "CS1591 (x47)" |
| RN-06 | Stack trace truncation: keep first 2 frames + last 2 frames | "[... N frames omitted]" |
| RN-07 | Empty input -> empty output (no footer, no stats) | exit 0 |
| RN-08 | Binary/non-text input -> pass through first 5 lines + "[binary output truncated]" | Graceful degradation |
| RN-09 | Compression must complete in <2 seconds for 500KB input | No external processes, pure sed/awk/grep |
| RN-10 | Footer token estimate: chars/4 (same as existing hook) | Approximate, not exact |

---

## 5. Test Scenarios

### Test 1: Short output passthrough
```
Given stdin with 15 lines of "git status" output containing ANSI codes
And --command "git status"
When piped through output-compress.sh
Then stdout has exactly 15 lines
And no ANSI codes remain
And exit code is 0
```

### Test 2: Git log compression
```
Given stdin with 200 lines of "git log" output (full format with author, date, body)
And --command "git log"
When piped through output-compress.sh
Then stdout has <= 50 lines
And each line matches pattern "^[a-f0-9]+ .+" (hash + subject)
And footer shows "[... 200 lines -> N lines, ~T tokens saved]"
And exit code is 0
```

### Test 3: Consecutive line deduplication
```
Given stdin with 100 lines where lines 10-60 are identical ("Restoring packages...")
And --command "generic"
When piped through output-compress.sh
Then the 50 identical lines are collapsed to 1 line: "Restoring packages... [...repeated 51 times]"
And total output < 60 lines
```

### Test 4: Dotnet test summary extraction
```
Given stdin with 300 lines of "dotnet test" output containing:
  - 200 lines of build output
  - 80 lines of test execution
  - "Failed! - Failed: 2, Passed: 45, Skipped: 0, Total: 47"
  - 2 failed test blocks with stack traces
And --command "dotnet test"
When piped through output-compress.sh
Then stdout contains the summary line "Failed! - Failed: 2, Passed: 45"
And stdout contains both failed test names
And stdout does NOT contain "Determining projects to restore"
And stdout has <= 50 lines
```

### Test 5: Warning grouping
```
Given stdin with 80 lines containing 47 lines of "warning CS1591: Missing XML comment"
And 3 lines of "warning CS0168: variable declared but never used"
And --command "dotnet build"
When piped through output-compress.sh
Then stdout contains "CS1591 (x47)" or equivalent grouped form
And stdout contains "CS0168 (x3)" or equivalent grouped form
And total warning lines <= 5
```

### Test 6: Stack trace truncation
```
Given stdin with a .NET stack trace of 25 frames
And --command "dotnet test"
When piped through output-compress.sh
Then stdout contains the first 2 frames
And stdout contains the last 2 frames
And stdout contains "[... 21 frames omitted]"
```

### Test 7: Empty input
```
Given stdin is empty
When piped through output-compress.sh
Then stdout is empty
And exit code is 0
```

### Test 8: validate-ci-local compression
```
Given stdin with 60 lines of validate-ci-local.sh output containing:
  - Banner lines ("--- Validacion CI Local ---")
  - 8 PASS lines
  - 1 FAIL line
  - Separator decorations
And --command "validate-ci-local"
When piped through output-compress.sh
Then stdout contains all PASS and FAIL lines
And stdout does NOT contain "---" separator lines
And stdout has <= 15 lines
```

### Test 9: Max-lines override
```
Given stdin with 500 lines
And --command "generic"
And --max-lines 20
When piped through output-compress.sh
Then stdout has <= 20 lines
And footer is present with compression stats
```

### Test 10: Performance (under 2 seconds)
```
Given stdin with 10000 lines of mixed content (~500KB)
And --command "generic"
When piped through output-compress.sh
Then execution time < 2 seconds
And exit code is 0
```

---

## 6. Ficheros a Crear / Modificar

### Crear (nuevos)
```
scripts/output-compress.sh              # Main compression script (stdin->stdout)
tests/test-output-compress.sh           # BATS-compatible test suite (10 scenarios above)
tests/fixtures/output-compress/         # Directory for test fixture files
tests/fixtures/output-compress/git-log-200.txt          # 200-line git log output
tests/fixtures/output-compress/dotnet-test-fail.txt     # dotnet test with 2 failures
tests/fixtures/output-compress/dotnet-build-warnings.txt # build with 47 CS1591 warnings
tests/fixtures/output-compress/ci-local-output.txt      # validate-ci-local output
tests/fixtures/output-compress/dedup-lines.txt          # 100 lines with 51 repeats
tests/fixtures/output-compress/stack-trace-25.txt       # 25-frame .NET stack trace
```

### Modificar (existentes)
```
.claude/hooks/bash-output-compress.sh   # Replace metrics-only logic with:
                                        #   COMPRESSED=$(echo "$OUTPUT" | bash "$PROJECT_DIR/scripts/output-compress.sh" --command "$COMMAND")
                                        #   echo "$COMPRESSED"
                                        #   (stdout from PostToolUse hook becomes additionalContext)
```

### NO tocar
```
.claude/settings.json                   # Hook registration already exists
scripts/context-tracker.sh              # Compression-report subcommand already exists
```

---

## 7. Codigo de Referencia

### Existing hook pattern (same project):
```
.claude/hooks/bash-output-compress.sh   # Current implementation (metrics only, lines 1-106)
```

### Compression functions to preserve and extend:
```bash
# From current hook — keep these as basis, move to output-compress.sh:
# compress_generic()    -> line 31-43
# compress_git_log()    -> line 46-51
# compress_git_diff()   -> line 53-58
# compress_test_output() -> line 60-65
# compress_npm()        -> line 67-72
```

### Context tracker integration pattern:
```bash
# From current hook line 96-99:
bash "$TRACKER" log "bash-compress" "$COMMAND_BASE" "$TOKENS_SAVED" 2>/dev/null || true
```

---

## 8. Configuracion de Entorno

```bash
# No solution file — pure bash scripts
# Workspace root
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Verification commands
bash scripts/output-compress.sh --command "generic" < /dev/null  # empty input test
echo -e "line1\nline2\nline3" | bash scripts/output-compress.sh  # passthrough test
bash tests/test-output-compress.sh                                # full test suite
shellcheck scripts/output-compress.sh                             # lint
wc -l scripts/output-compress.sh                                  # must be <= 150
```

---

## 9. Restricciones y Convenciones

- Script MUST start with `#!/usr/bin/env bash` and `set -uo pipefail`
- Script MUST be <= 150 lines (Rule: file-size-limit.md)
- Script MUST pass `shellcheck` without errors
- Script MUST NOT use external binaries beyond: bash, sed, awk, grep, head, tail, wc, tr, cut
- Script MUST NOT write to any file (pure stdin->stdout filter)
- Script MUST NOT read any file except stdin (no config files, no state)
- All compression functions MUST be idempotent (compressing already-compressed output = same output)
- Test fixtures MUST use generic data (no PII, Rule #20)
- Test script MUST follow existing BATS pattern in `tests/` directory
- Hook update MUST preserve existing metrics logging to context-tracker

---

## 10. Checklist Pre-Entrega

### Implementacion
- [ ] `scripts/output-compress.sh` exists and is executable
- [ ] Script <= 150 lines
- [ ] Script passes `shellcheck`
- [ ] All 8 compression steps implemented
- [ ] All 7 command-specific filters implemented (git_log, git_diff, git_status, dotnet_test, dotnet_build, validate_ci, npm_pnpm)
- [ ] Generic fallback filter works for unknown commands
- [ ] `--command` and `--max-lines` arguments parsed correctly
- [ ] Empty input produces empty output
- [ ] Output <= 30 lines passes through (ANSI stripped only)
- [ ] `.claude/hooks/bash-output-compress.sh` updated to call the new script
- [ ] Hook stdout emits compressed output (not just metrics)
- [ ] All 10 test scenarios pass
- [ ] All test fixtures created with realistic but generic data
- [ ] Performance: 500KB input processes in < 2 seconds

### Especifico para agente
- [ ] No decisions outside this spec
- [ ] No files created beyond section 6
- [ ] Compression functions follow patterns from section 7
- [ ] Exit code is always 0

---

## 11. Notas para el Revisor

1. **Critical architecture change**: The current hook does NOTHING useful (PostToolUse
   hooks cannot replace TOOL_OUTPUT). This spec fixes that by having the hook emit
   compressed output to stdout, which Claude Code injects as `additionalContext`.
   Verify this mechanism actually works in a live session.

2. **Risk: information loss**: The 30-line threshold and specialized filters are
   conservative. If a developer reports missing information, the first fix is to
   add a new specialized filter, not to raise the threshold.

3. **Idempotency matters**: Compressed output may be re-read by Claude in context.
   Running compression again on already-compressed output must produce identical
   output (no "repeated 1 times" artifacts, no double-footer).

4. **Token estimation**: chars/4 is rough but consistent with the existing hook
   and context-tracker. Do not introduce a different estimation method.
