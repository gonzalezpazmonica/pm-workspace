"""Agent markdown parser.

Parses an OpenCode agent markdown file into a structured AST:
- frontmatter (YAML)
- body lines
- headers (with text and level)
- tools list (from frontmatter `tools:` field)
- prompt body (markdown after frontmatter)

Pure Python. No bash. Conforms to Rule #26.
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import List, Optional

import yaml


FRONTMATTER_RE = re.compile(r"^---\s*\n(.*?)\n---\s*\n", re.DOTALL)
HEADER_RE = re.compile(r"^(#{1,6})\s+(.+?)\s*$")


@dataclass
class Header:
    level: int
    text: str
    line_no: int  # 1-indexed line in the original file


@dataclass
class AgentAST:
    path: Path
    frontmatter: dict = field(default_factory=dict)
    body: str = ""
    headers: List[Header] = field(default_factory=list)
    line_count: int = 0
    body_line_count: int = 0
    tools: List[str] = field(default_factory=list)
    description: str = ""
    name: str = ""
    parse_errors: List[str] = field(default_factory=list)

    @property
    def is_orchestrator(self) -> bool:
        kind = (self.frontmatter.get("kind") or "").lower()
        return kind == "orchestrator"


def parse_agent(path: Path) -> AgentAST:
    """Parse an agent markdown file. Never raises on malformed input.

    Returns an AgentAST with parse_errors populated if anything was tolerated.
    """
    ast = AgentAST(path=Path(path))
    if not ast.path.exists():
        ast.parse_errors.append(f"file not found: {path}")
        return ast

    raw = ast.path.read_text(encoding="utf-8")
    ast.line_count = raw.count("\n") + (0 if raw.endswith("\n") else 1)

    body = raw
    fm_match = FRONTMATTER_RE.match(raw)
    if fm_match:
        fm_text = fm_match.group(1)
        try:
            fm = yaml.safe_load(fm_text) or {}
            if not isinstance(fm, dict):
                ast.parse_errors.append("frontmatter not a mapping")
                fm = {}
        except yaml.YAMLError as e:
            ast.parse_errors.append(f"frontmatter yaml error: {e}")
            fm = {}
        ast.frontmatter = fm
        body = raw[fm_match.end():]

    ast.body = body
    ast.body_line_count = body.count("\n") + (0 if body.endswith("\n") else 1)

    # Extract headers from body, with line numbers in the *original* file.
    fm_offset = (raw[:fm_match.end()].count("\n") + 1) if fm_match else 0
    for idx, line in enumerate(body.splitlines()):
        m = HEADER_RE.match(line)
        if m:
            ast.headers.append(
                Header(level=len(m.group(1)), text=m.group(2).strip(), line_no=fm_offset + idx + 1)
            )

    # Tools — accept list, comma string, or mapping {name: bool/None}.
    tools_raw = ast.frontmatter.get("tools")
    if isinstance(tools_raw, list):
        ast.tools = [str(t).strip() for t in tools_raw if str(t).strip()]
    elif isinstance(tools_raw, str):
        ast.tools = [t.strip() for t in tools_raw.replace("\n", ",").split(",") if t.strip()]
    elif isinstance(tools_raw, dict):
        # Only count keys whose value is truthy (or explicitly None as "declared").
        ast.tools = [str(k).strip() for k, v in tools_raw.items() if v is not False and str(k).strip()]
    else:
        ast.tools = []

    ast.name = str(ast.frontmatter.get("name") or ast.path.stem)
    ast.description = str(ast.frontmatter.get("description") or "")
    return ast


def discover_agents(root: Path) -> List[Path]:
    """Find all .opencode/agents/*.md (excluding directories)."""
    agents_dir = Path(root) / ".opencode" / "agents"
    if not agents_dir.is_dir():
        return []
    return sorted(p for p in agents_dir.glob("*.md") if p.is_file())
