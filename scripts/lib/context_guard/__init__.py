"""Context Guard — Automatic context window management with LLM-powered summarization.

Slice 1: Monitor + Tokenizer + Summarizer + Store.
Slice 2 (NOT here): MCP server, CLI, hooks, docs.

Spec: docs/specs/SPEC-CONTEXT-GUARD.spec.md
Rule #26: Python for structured logic; Bash only as thin wrapper.
"""

from __future__ import annotations

__version__ = "0.1.0"
__all__ = [
    "ContextGuardConfig",
    "ContextMonitor",
    "TierTokenizer",
    "Summarizer",
    "SummaryStore",
]

from scripts.lib.context_guard.monitor import ContextGuardConfig, ContextMonitor
from scripts.lib.context_guard.store import SummaryStore
from scripts.lib.context_guard.summarizer import Summarizer
from scripts.lib.context_guard.tokenizer import TierTokenizer
