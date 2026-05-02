"""SaviaClaw LLM Backend — provider-agnostic, always loads Savia's full context.

Uses OpenCode headless (`opencode run`) to invoke the LLM with the complete
pm-workspace context (CLAUDE.md, AGENTS.md, SKILLS.md, rules, memory). This
replaces the hardcoded `claude -p` dependency.

REQ-00: SaviaClaw IS Savia with a physical body. Every LLM call MUST load the
full workspace context. No bare API calls — that would be a different agent.
"""
import subprocess
import os

WORKSPACE_ROOT = os.path.expanduser("~/claude")
LLM_CMD = "opencode"


def talk_reply(prompt: str, timeout: int = 15) -> str | None:
    """Quick reply for Talk/ESP32 questions. Short, <200 chars, 15s timeout."""
    try:
        r = subprocess.run(
            [LLM_CMD, "run", prompt],
            capture_output=True, text=True, timeout=timeout,
            cwd=WORKSPACE_ROOT,
        )
        if r.returncode == 0:
            return r.stdout.strip()[:200]
        return None
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return None


def reason(prompt: str, timeout: int = 60) -> str | None:
    """Deep reasoning for autonomous tasks. Full response, no truncation, 60s."""
    try:
        r = subprocess.run(
            [LLM_CMD, "run", prompt],
            capture_output=True, text=True, timeout=timeout,
            cwd=WORKSPACE_ROOT,
        )
        if r.returncode == 0:
            return r.stdout.strip()
        return None
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return None


def execute(prompt: str, timeout: int = 120) -> str | None:
    """Execution mode — tool calls allowed, longer timeout. For escalations."""
    try:
        r = subprocess.run(
            [LLM_CMD, "run", prompt],
            capture_output=True, text=True, timeout=timeout,
            cwd=WORKSPACE_ROOT,
        )
        if r.returncode == 0:
            return r.stdout.strip()
        return None
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return None
