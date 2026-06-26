#!/usr/bin/env python3
"""scripts/agent-message-schema.py — SPEC-056: Typed Agent Message Protocol

Defines AgentMessage schema with typed ContentBlocks.

CLI:
    python3 scripts/agent-message-schema.py --validate <json-file>
    python3 scripts/agent-message-schema.py --schema
    python3 scripts/agent-message-schema.py --example
"""
from __future__ import annotations

import argparse
import json
import sys
import uuid
from dataclasses import dataclass, field, asdict
from datetime import datetime, timezone
from typing import Any


# ── Allowed content block types ───────────────────────────────────────────────
CONTENT_BLOCK_TYPES = frozenset({
    "text",
    "code",
    "result",
    "error",
    "decision",
    # Extended types from SPEC-056 schema design (backward-compat)
    "tool_result",
    "file_ref",
    "thinking",
    "image",
})

ALLOWED_ROLES = frozenset({"assistant", "orchestrator", "judge", "agent", "human", "system"})


# ── Dataclasses ───────────────────────────────────────────────────────────────

@dataclass
class ContentBlock:
    type: str          # one of CONTENT_BLOCK_TYPES
    content: str
    metadata: dict = field(default_factory=dict)

    def validate(self) -> list[str]:
        """Return list of validation errors (empty = valid)."""
        errors: list[str] = []
        if not isinstance(self.type, str) or not self.type:
            errors.append("ContentBlock.type must be a non-empty string")
        elif self.type not in CONTENT_BLOCK_TYPES:
            errors.append(
                f"ContentBlock.type '{self.type}' must be one of: "
                + ", ".join(sorted(CONTENT_BLOCK_TYPES))
            )
        if not isinstance(self.content, str):
            errors.append("ContentBlock.content must be a string")
        if not isinstance(self.metadata, dict):
            errors.append("ContentBlock.metadata must be a dict")
        return errors


@dataclass
class AgentMessage:
    id: str             # UUID
    sender: str         # agent name
    receiver: str       # agent name or "human"
    role: str           # "assistant" | "orchestrator" | "judge" (and legacy values)
    content_blocks: list[ContentBlock]
    ts: str             # ISO-8601
    session_id: str

    def validate(self) -> list[str]:
        """Return list of validation errors (empty = valid)."""
        errors: list[str] = []

        # id
        if not isinstance(self.id, str) or not self.id:
            errors.append("AgentMessage.id must be a non-empty string")
        else:
            try:
                uuid.UUID(self.id)
            except ValueError:
                errors.append(f"AgentMessage.id '{self.id}' is not a valid UUID")

        # sender / receiver
        if not isinstance(self.sender, str) or not self.sender:
            errors.append("AgentMessage.sender must be a non-empty string")
        if not isinstance(self.receiver, str) or not self.receiver:
            errors.append("AgentMessage.receiver must be a non-empty string")

        # role
        if not isinstance(self.role, str) or not self.role:
            errors.append("AgentMessage.role must be a non-empty string")

        # content_blocks — must be non-empty list
        if not isinstance(self.content_blocks, list):
            errors.append("AgentMessage.content_blocks must be a list")
        elif len(self.content_blocks) == 0:
            errors.append("AgentMessage.content_blocks must not be empty")
        else:
            for i, cb in enumerate(self.content_blocks):
                if not isinstance(cb, ContentBlock):
                    errors.append(f"content_blocks[{i}] is not a ContentBlock instance")
                else:
                    for err in cb.validate():
                        errors.append(f"content_blocks[{i}]: {err}")

        # ts — must be non-empty; basic ISO check
        if not isinstance(self.ts, str) or not self.ts:
            errors.append("AgentMessage.ts must be a non-empty ISO-8601 string")
        else:
            try:
                datetime.fromisoformat(self.ts.replace("Z", "+00:00"))
            except ValueError:
                errors.append(f"AgentMessage.ts '{self.ts}' is not a valid ISO-8601 datetime")

        # session_id
        if not isinstance(self.session_id, str) or not self.session_id:
            errors.append("AgentMessage.session_id must be a non-empty string")

        return errors


# ── JSON schema (static) ──────────────────────────────────────────────────────

def get_json_schema() -> dict[str, Any]:
    return {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "title": "AgentMessage",
        "description": "SPEC-056 Typed Agent Message Protocol",
        "type": "object",
        "required": ["id", "sender", "receiver", "role", "content_blocks", "ts", "session_id"],
        "additionalProperties": False,
        "properties": {
            "id": {
                "type": "string",
                "format": "uuid",
                "description": "UUID v4 unique per message",
            },
            "sender": {
                "type": "string",
                "minLength": 1,
                "description": "Agent name sending the message",
            },
            "receiver": {
                "type": "string",
                "minLength": 1,
                "description": "Target agent name or 'human'",
            },
            "role": {
                "type": "string",
                "enum": sorted(ALLOWED_ROLES),
                "description": "Message role",
            },
            "content_blocks": {
                "type": "array",
                "minItems": 1,
                "items": {
                    "type": "object",
                    "required": ["type", "content"],
                    "additionalProperties": False,
                    "properties": {
                        "type": {
                            "type": "string",
                            "enum": sorted(CONTENT_BLOCK_TYPES),
                        },
                        "content": {"type": "string"},
                        "metadata": {"type": "object"},
                    },
                },
            },
            "ts": {
                "type": "string",
                "description": "ISO-8601 UTC timestamp",
            },
            "session_id": {
                "type": "string",
                "minLength": 1,
            },
        },
    }


# ── Example message ───────────────────────────────────────────────────────────

def get_example() -> dict[str, Any]:
    return {
        "id": "550e8400-e29b-41d4-a716-446655440000",
        "sender": "dotnet-developer",
        "receiver": "code-reviewer",
        "role": "assistant",
        "content_blocks": [
            {
                "type": "text",
                "content": "Implementation complete. 3 files modified.",
                "metadata": {},
            },
            {
                "type": "result",
                "content": "42/42 tests passed",
                "metadata": {"tool": "dotnet test", "status": "pass"},
            },
            {
                "type": "code",
                "content": "public class UserService { ... }",
                "metadata": {"language": "csharp", "path": "src/UserService.cs"},
            },
        ],
        "ts": "2026-03-30T10:00:00Z",
        "session_id": "session-abc-123",
    }


# ── Deserialization helper ────────────────────────────────────────────────────

def from_dict(data: dict[str, Any]) -> AgentMessage:
    """Deserialize a dict into an AgentMessage (raises KeyError/TypeError on bad input)."""
    raw_blocks = data.get("content_blocks", [])
    if not isinstance(raw_blocks, list):
        raise TypeError("content_blocks must be a list")

    blocks: list[ContentBlock] = []
    for rb in raw_blocks:
        if not isinstance(rb, dict):
            raise TypeError(f"Each content_block must be a dict, got {type(rb)}")
        blocks.append(
            ContentBlock(
                type=rb.get("type", ""),
                content=rb.get("content", ""),
                metadata=rb.get("metadata", {}),
            )
        )

    return AgentMessage(
        id=data.get("id", ""),
        sender=data.get("sender", ""),
        receiver=data.get("receiver", ""),
        role=data.get("role", ""),
        content_blocks=blocks,
        ts=data.get("ts", ""),
        session_id=data.get("session_id", ""),
    )


def validate_file(path: str) -> tuple[bool, list[str]]:
    """Load JSON from path and validate. Returns (ok, errors)."""
    try:
        with open(path, encoding="utf-8") as fh:
            data = json.load(fh)
    except FileNotFoundError:
        return False, [f"File not found: {path}"]
    except json.JSONDecodeError as exc:
        return False, [f"JSON decode error: {exc}"]

    try:
        msg = from_dict(data)
    except (TypeError, KeyError) as exc:
        return False, [f"Deserialization error: {exc}"]

    errors = msg.validate()
    return len(errors) == 0, errors


# ── CLI ───────────────────────────────────────────────────────────────────────

def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="agent-message-schema.py",
        description="SPEC-056 Typed Agent Message Protocol — schema tool",
    )
    group = p.add_mutually_exclusive_group(required=True)
    group.add_argument(
        "--validate",
        metavar="JSON_FILE",
        help="Validate a JSON file against AgentMessage schema. Exit 0 if valid.",
    )
    group.add_argument(
        "--schema",
        action="store_true",
        help="Print the JSON Schema for AgentMessage.",
    )
    group.add_argument(
        "--example",
        action="store_true",
        help="Print a valid example AgentMessage as JSON.",
    )
    return p


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    if args.schema:
        print(json.dumps(get_json_schema(), indent=2))
        return 0

    if args.example:
        print(json.dumps(get_example(), indent=2))
        return 0

    if args.validate:
        ok, errors = validate_file(args.validate)
        if ok:
            print(f"OK: {args.validate} is a valid AgentMessage")
            return 0
        else:
            print(f"INVALID: {args.validate}", file=sys.stderr)
            for err in errors:
                print(f"  - {err}", file=sys.stderr)
            return 1

    return 0  # unreachable


if __name__ == "__main__":
    sys.exit(main())
