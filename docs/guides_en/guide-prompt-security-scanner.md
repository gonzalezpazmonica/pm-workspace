# Prompt Security Scanner

> Version: v4.7 | Era: 176 | Since: 2026-04-03

## What it is

A static analyzer that detects security vulnerabilities in agent, skill, and command prompts. It applies 10 rules (PS-01 to PS-10) using pure regex — no LLM, instant execution. It identifies prompt injections, credential leaks, role hijacking, and other attack vectors.

## Requirements

Pre-installed since v4.7. No external dependencies.

## Basic usage

```bash
# Scan a single file
bash scripts/prompt-security-scan.sh .claude/agents/mi-agente.md

# Scan an entire directory
bash scripts/prompt-security-scan.sh .claude/agents/

# Quiet mode (errors only)
bash scripts/prompt-security-scan.sh --quiet .claude/

# Scan a specific path
bash scripts/prompt-security-scan.sh --path .claude/skills/
```

Typical output:
```
[PS-03] Role hijack pattern in agent-x.md:12
        "ignore previous instructions"
        Severity: HIGH
```

## The 10 rules

| Rule | Detects |
|------|---------|
| PS-01 | Prompt injection (bait patterns) |
| PS-02 | Data exfiltration (leakage) |
| PS-03 | Role hijacking |
| PS-04 | Credential leaks |
| PS-05 | Arbitrary code execution |
| PS-06 | Suspicious base64 blobs |
| PS-07 | Personal data (PII) in prompts |
| PS-08 | Model not specified in frontmatter |
| PS-09 | Wildcard tools (excessive access) |
| PS-10 | Combined risk patterns |

## Integration

- **validate-ci-local.sh**: the scanner runs as part of local CI validation
- **commit-guardian**: can invoke the scanner in pre-commit for staged files in `.claude/`
- **prompt-security-scan.sh --quiet**: CI mode, returns exit code 1 if critical findings are found

## Configuration

No configuration required. The 10 rules are hardcoded as regex to ensure determinism.

To exclude a file from the scan, use `--path` pointing only to the relevant directory.

## Troubleshooting

**False positive**: review the detected pattern. If it is a documented example (inside a code block), the scanner may detect it. Use `--quiet` to filter only critical findings.

**Does not detect a known pattern**: verify that the file has the `.md` extension. The scanner only processes markdown files.

**CI integration fails**: verify that `scripts/prompt-security-scan.sh` has execution permissions: `chmod +x scripts/prompt-security-scan.sh`
