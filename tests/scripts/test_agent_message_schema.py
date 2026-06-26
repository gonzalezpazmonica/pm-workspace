"""tests/scripts/test_agent_message_schema.py — SPEC-056

Tests for scripts/agent-message-schema.py: AgentMessage validation,
JSON Schema output, and CLI behavior.
"""
from __future__ import annotations

import importlib.util
import json
import sys
import tempfile
import uuid
from pathlib import Path

import pytest

# ── Load module ───────────────────────────────────────────────────────────────
REPO_ROOT = Path(__file__).resolve().parent.parent.parent
SCRIPT = REPO_ROOT / "scripts" / "agent-message-schema.py"


def _load():
    spec = importlib.util.spec_from_file_location("agent_message_schema", SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    sys.modules["agent_message_schema"] = mod
    spec.loader.exec_module(mod)
    return mod


mod = _load()

AgentMessage = mod.AgentMessage
ContentBlock = mod.ContentBlock
from_dict = mod.from_dict
get_json_schema = mod.get_json_schema
get_example = mod.get_example
validate_file = mod.validate_file
main = mod.main
CONTENT_BLOCK_TYPES = mod.CONTENT_BLOCK_TYPES


# ── Helpers ───────────────────────────────────────────────────────────────────

def _valid_msg(**overrides):
    base = dict(
        id=str(uuid.uuid4()),
        sender="dotnet-developer",
        receiver="code-reviewer",
        role="assistant",
        content_blocks=[ContentBlock(type="text", content="done")],
        ts="2026-03-30T10:00:00Z",
        session_id="session-abc",
    )
    base.update(overrides)
    return AgentMessage(**base)


# ── Tests ─────────────────────────────────────────────────────────────────────

class TestValidateAcceptsValidMessage:
    """TC-1: validate accepts a fully valid AgentMessage."""

    def test_valid_message_has_no_errors(self):
        msg = _valid_msg()
        errors = msg.validate()
        assert errors == [], f"Expected no errors, got: {errors}"

    def test_valid_message_multiple_blocks(self):
        msg = _valid_msg(
            content_blocks=[
                ContentBlock(type="text", content="Step 1"),
                ContentBlock(type="result", content="42/42 passed", metadata={"tool": "pytest"}),
                ContentBlock(type="code", content="x = 1", metadata={"lang": "python"}),
            ]
        )
        assert msg.validate() == []


class TestValidateRejectsMissingId:
    """TC-2: validate rejects AgentMessage with empty/missing id."""

    def test_empty_id(self):
        msg = _valid_msg(id="")
        errors = msg.validate()
        assert any("id" in e.lower() for e in errors), f"Expected id error, got: {errors}"

    def test_non_uuid_id(self):
        msg = _valid_msg(id="not-a-uuid")
        errors = msg.validate()
        assert any("uuid" in e.lower() or "id" in e.lower() for e in errors)

    def test_valid_uuid_accepted(self):
        msg = _valid_msg(id="550e8400-e29b-41d4-a716-446655440000")
        errors = msg.validate()
        assert errors == []


class TestValidateRejectsEmptyContentBlocks:
    """TC-3: validate rejects AgentMessage with empty content_blocks list."""

    def test_empty_list(self):
        msg = _valid_msg(content_blocks=[])
        errors = msg.validate()
        assert any("content_blocks" in e.lower() or "empty" in e.lower() for e in errors), \
            f"Expected content_blocks error, got: {errors}"

    def test_none_replaced_by_empty_list(self):
        # Direct construction with empty list
        msg = AgentMessage(
            id=str(uuid.uuid4()),
            sender="a",
            receiver="b",
            role="assistant",
            content_blocks=[],
            ts="2026-01-01T00:00:00Z",
            session_id="s1",
        )
        errors = msg.validate()
        assert len(errors) > 0


class TestSchemaProducesValidJSONSchema:
    """TC-4: --schema produces a valid JSON Schema dict."""

    def test_schema_has_required_keys(self):
        schema = get_json_schema()
        assert "$schema" in schema
        assert "title" in schema
        assert "type" in schema
        assert schema["type"] == "object"

    def test_schema_properties_include_all_fields(self):
        schema = get_json_schema()
        props = schema.get("properties", {})
        for field in ("id", "sender", "receiver", "role", "content_blocks", "ts", "session_id"):
            assert field in props, f"Missing property: {field}"

    def test_schema_required_lists_all_fields(self):
        schema = get_json_schema()
        required = schema.get("required", [])
        for field in ("id", "sender", "receiver", "role", "content_blocks", "ts", "session_id"):
            assert field in required

    def test_schema_is_json_serializable(self):
        schema = get_json_schema()
        text = json.dumps(schema)
        parsed = json.loads(text)
        assert parsed["title"] == "AgentMessage"


class TestExampleIsParseableAndValid:
    """TC-5: --example produces a parseable, valid AgentMessage."""

    def test_example_parses_to_agent_message(self):
        example = get_example()
        msg = from_dict(example)
        assert isinstance(msg, AgentMessage)

    def test_example_is_valid(self):
        example = get_example()
        msg = from_dict(example)
        errors = msg.validate()
        assert errors == [], f"Example has validation errors: {errors}"

    def test_example_is_json_serializable(self):
        example = get_example()
        text = json.dumps(example)
        parsed = json.loads(text)
        assert parsed["sender"] == "dotnet-developer"


class TestContentBlockTypeValidation:
    """TC-6: ContentBlock.type must be one of the allowed values."""

    def test_valid_types_accepted(self):
        for t in ["text", "code", "result", "error", "decision"]:
            cb = ContentBlock(type=t, content="x")
            errors = cb.validate()
            assert errors == [], f"Type '{t}' should be valid, got: {errors}"

    def test_invalid_type_rejected(self):
        cb = ContentBlock(type="unknown_type_xyz", content="x")
        errors = cb.validate()
        assert len(errors) > 0, "Expected error for unknown type"
        assert any("type" in e.lower() for e in errors)

    def test_empty_type_rejected(self):
        cb = ContentBlock(type="", content="x")
        errors = cb.validate()
        assert len(errors) > 0

    def test_all_spec_types_exist_in_set(self):
        required_types = {"text", "code", "result", "error", "decision"}
        assert required_types.issubset(CONTENT_BLOCK_TYPES)


class TestValidateFileFunction:
    """TC-7: validate_file helper reads JSON file and validates it."""

    def test_valid_file_returns_ok(self):
        example = get_example()
        with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as fh:
            json.dump(example, fh)
            fpath = fh.name
        ok, errors = validate_file(fpath)
        assert ok is True
        assert errors == []

    def test_invalid_file_missing_id(self):
        data = get_example()
        del data["id"]
        with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as fh:
            json.dump(data, fh)
            fpath = fh.name
        ok, errors = validate_file(fpath)
        assert ok is False
        assert len(errors) > 0

    def test_nonexistent_file_returns_error(self):
        ok, errors = validate_file("/tmp/nonexistent_spec056_xyz.json")
        assert ok is False
        assert any("not found" in e.lower() or "file" in e.lower() for e in errors)


class TestCLISchema:
    """TC-8: CLI --schema prints valid JSON."""

    def test_cli_schema_exit_0(self, capsys):
        rc = main(["--schema"])
        assert rc == 0
        captured = capsys.readouterr()
        parsed = json.loads(captured.out)
        assert parsed["title"] == "AgentMessage"


class TestCLIExample:
    """TC-9: CLI --example prints valid message JSON."""

    def test_cli_example_exit_0(self, capsys):
        rc = main(["--example"])
        assert rc == 0
        captured = capsys.readouterr()
        parsed = json.loads(captured.out)
        assert "sender" in parsed
        assert "content_blocks" in parsed


class TestCLIValidate:
    """TC-10: CLI --validate exits 0 for valid, 1 for invalid."""

    def test_valid_file(self, capsys, tmp_path):
        example = get_example()
        p = tmp_path / "msg.json"
        p.write_text(json.dumps(example))
        rc = main(["--validate", str(p)])
        assert rc == 0

    def test_invalid_file(self, capsys, tmp_path):
        data = get_example()
        data["content_blocks"] = []
        p = tmp_path / "invalid.json"
        p.write_text(json.dumps(data))
        rc = main(["--validate", str(p)])
        assert rc == 1
