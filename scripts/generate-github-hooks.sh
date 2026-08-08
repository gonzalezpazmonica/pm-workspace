#!/usr/bin/env bash
# generate-github-hooks.sh — SE-180
#
# Genera .github/hooks/savia.json desde .claude/settings.json para que
# Copilot CLI (>=1.0.60) ejecute los mismos hooks bash. Cross-frontend:
#
#   Claude Code   → lee .claude/settings.json (nativo)
#   OpenCode      → lee .claude/settings.json (via plugin savia-gates)
#   Copilot CLI   → lee .github/hooks/*.json  (generado por este script)
#
# Necesario porque Copilot CLI 1.0.60 NO lee .claude/settings.json (a pesar
# de lo que las docs dicen). Verificado en app.js del binario:
#   getHooksDir() → path.join(gitRoot, ".github", "hooks")
#
# El generated file es idempotente — siempre mismo output para mismo input.
# CI verifica que está sincronizado vía test-copilot-cli-compat.bats.
#
# Reference: SE-180 (docs/specs/SE-180-*.spec.md)
# Reference: docs/rules/domain/cross-frontend-coverage.md

set -uo pipefail

ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
SRC="${ROOT}/.claude/settings.json"
DST="${ROOT}/.github/hooks/savia.json"

[[ -f "$SRC" ]] || { echo "ERROR: $SRC missing" >&2; exit 1; }
mkdir -p "$(dirname "$DST")"

python3 - "$SRC" "$DST" <<'PY'
import json, re, sys

src, dst = sys.argv[1], sys.argv[2]
settings = json.load(open(src))
hooks_in = settings.get("hooks", {})

# Map PascalCase (Claude Code) -> camelCase (Copilot CLI).
# Reference: docs.github.com/en/copilot/reference/hooks-configuration
EVENT_MAP = {
    "PreToolUse": "preToolUse",
    "PostToolUse": "postToolUse",
    "UserPromptSubmit": "userPromptSubmitted",
    "SessionStart": "sessionStart",
    "SessionEnd": "sessionEnd",
    "Stop": "agentStop",
    "PreCompact": "preCompact",
    "SubagentStart": "subagentStart",
    "SubagentStop": "subagentStop",
}

# Map Claude Code tool names (Bash, Edit, Write) to Copilot CLI tool names.
# Copilot CLI uses lowercase tool ids. The matcher in Copilot is a regex
# anchored at full match.
TOOL_MAP = {
    "Bash": "bash",
    "Edit": "edit|str_replace_editor",
    "Write": "create|write",
    "MultiEdit": "edit|str_replace_editor",
    "Read": "view",
    "Glob": "glob",
    "Grep": "grep",
    "Task": "task|launch_subagent",
}

def translate_matcher(claude_matcher):
    """Translate a Claude Code matcher (tool name, possibly pipe-separated) to Copilot CLI regex.

    Empirical 2026-06-08: Copilot CLI rejects matchers like '*' (treats as regex,
    not glob) with 'Invalid matcher regex' and skips the hook. Empty matcher
    also problematic. When the Claude matcher means "match everything" or is
    absent, we OMIT the matcher field in the Copilot entry so it applies to
    all tools (Copilot's default when matcher is absent).
    """
    if not claude_matcher:
        return None
    s = claude_matcher.strip()
    # Claude Code "match everything" idioms — translate to no matcher
    if s in ("*", ".*", "**", "(.*)", ""):
        return None
    parts = [p.strip() for p in s.split("|")]
    translated = []
    for p in parts:
        # Skip empty parts and "match all" idioms within alternation
        if not p or p in ("*", ".*", "**"):
            continue
        translated.append(TOOL_MAP.get(p, p.lower()))
    return "|".join(translated) if translated else None

def translate_command(cmd):
    """Translate a hook command string for Copilot CLI.

    Empirical finding 2026-06-08: Copilot CLI 1.0.60 exposes
    CLAUDE_PROJECT_DIR as env var to hook scripts (verified in
    binary app.js: `env||{},CLAUDE_PROJECT_DIR:u,COPILOT_PROJECT_DIR:...`).

    Therefore, paths with $CLAUDE_PROJECT_DIR should be LEFT INTACT —
    /bin/sh expands the env var correctly at execution time. Previously
    translated to "./" relative paths but that broke because Copilot runs
    hooks from .github/hooks/ cwd, not gitRoot. Reverted.
    """
    return cmd

out = {"version": 1, "hooks": {}}

skipped_http = 0
skipped_prompt = 0
skipped_unknown_event = 0

for claude_event, entries in hooks_in.items():
    copilot_event = EVENT_MAP.get(claude_event)
    if not copilot_event:
        skipped_unknown_event += 1
        continue
    out["hooks"].setdefault(copilot_event, [])
    for entry in entries:
        matcher = entry.get("matcher")
        copilot_matcher = translate_matcher(matcher)
        for h in entry.get("hooks", []):
            htype = h.get("type", "command")
            if htype == "http":
                # Copilot CLI (>=1.0.60) REJECTS THE ENTIRE hook file if an
                # authorization-affecting HTTP hook (preToolUse / preMcpToolCall /
                # permissionRequest) uses a non-https URL. Verified empirically
                # 2026-06-08: savia.json was rejected wholesale because the shield
                # gate used http://127.0.0.1:8444/gate, silently disabling ALL
                # hooks under Copilot. So we skip non-https http hooks here — the
                # rest of the bash hooks then load. The shield gate is localhost-
                # only and non-essential under Copilot; it remains active under
                # Claude Code / OpenCode via .claude/settings.json (single source).
                url = h.get("url", "") or ""
                if not url.lower().startswith("https://"):
                    skipped_http += 1
                    sys.stderr.write(
                        f"WARN skipping non-https http hook in {claude_event}: {url}\n"
                    )
                    continue
                http_entry = {
                    "type": "http",
                    "url": h.get("url"),
                    "headers": h.get("headers", {}),
                    "timeoutSec": h.get("timeout", 30),
                }
                if copilot_matcher:
                    http_entry["matcher"] = copilot_matcher
                out["hooks"][copilot_event].append(http_entry)
                continue
            if htype == "prompt":
                # Copilot CLI supports prompt hooks only on sessionStart per docs.
                # Skip in non-sessionStart events; warn at end.
                if copilot_event != "sessionStart":
                    skipped_prompt += 1
                    continue
                out["hooks"][copilot_event].append({
                    "type": "prompt",
                    "prompt": h.get("prompt"),
                    "timeoutSec": h.get("timeout", 30),
                })
                continue
            # command type (default)
            cmd = h.get("command", "")
            if not cmd:
                continue
            # Extract the hook path from the Claude Code command. Two shapes:
            #   1) "$CLAUDE_PROJECT_DIR"/.opencode/hooks/X.sh  → relative .opencode/hooks/X.sh
            #   2) bash "$CLAUDE_PROJECT_DIR"/scripts/X.sh ... → relative scripts/X.sh
            # We pass the relative path to run-savia-hook.sh, which resolves
            # the workspace root itself (multiple fallback strategies).
            relpath = None
            # Pattern 1: direct invocation of the .sh
            m = re.match(r'^"?\$CLAUDE_PROJECT_DIR"?/(\S+\.sh)(?:\s|$)', cmd)
            if m:
                relpath = m.group(1)
            else:
                # Pattern 2: bash "$CLAUDE_PROJECT_DIR"/path/X.sh [args]
                m = re.match(r'^bash\s+"?\$CLAUDE_PROJECT_DIR"?/(\S+\.sh)', cmd)
                if m:
                    relpath = m.group(1)
            if not relpath:
                # Unknown shape — skip with warning. We do NOT inline it
                # because complex inline commands have been the source of
                # multiple bugs (SE-180 round 1+2).
                sys.stderr.write(f"WARN skipping unparseable command in {claude_event}: {cmd[:80]}\n")
                continue
            # Single launcher in the bash field (no env vars, no command
            # substitution, no semicolons — Copilot CLI's command parser
            # has shown issues with inline shell complexity).
            entry_out = {
                "type": "command",
                "bash": f"bash .github/hooks/run-savia-hook.sh {relpath}",
                "timeoutSec": h.get("timeout", 30),
            }
            if copilot_matcher:
                entry_out["matcher"] = copilot_matcher
            out["hooks"][copilot_event].append(entry_out)
    # Drop event key if it ended up empty
    if not out["hooks"][copilot_event]:
        del out["hooks"][copilot_event]

# Add metadata header as a comment-like field (Copilot CLI ignores it)
out["_meta"] = {
    "generated_from": ".claude/settings.json",
    "generator": "scripts/generate-github-hooks.sh",
    "spec": "SE-180",
    "purpose": "Cross-frontend hooks for Copilot CLI (>=1.0.60). Single source of truth: .claude/settings.json. Do not edit this file directly.",
    "skipped_unknown_events": skipped_unknown_event,
    "skipped_prompt_outside_sessionStart": skipped_prompt,
    "skipped_non_https_http_hooks": skipped_http,
}

with open(dst, "w") as f:
    json.dump(out, f, indent=2)
    f.write("\n")

# Report
total = sum(len(v) for v in out["hooks"].values())
print(f"Generated {dst}")
print(f"  Total Copilot CLI hook entries: {total}")
for ev, lst in sorted(out["hooks"].items()):
    print(f"    {ev}: {len(lst)}")
if skipped_unknown_event:
    print(f"  Skipped (unknown event): {skipped_unknown_event}", file=sys.stderr)
if skipped_prompt:
    print(f"  Skipped (prompt hook outside sessionStart): {skipped_prompt}", file=sys.stderr)
if skipped_http:
    print(f"  Skipped (non-https http hook — would invalidate whole file): {skipped_http}", file=sys.stderr)
PY
