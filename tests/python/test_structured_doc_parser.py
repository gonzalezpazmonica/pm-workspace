from pathlib import Path
import pytest
from conftest_structured_doc import setup_spec_md, setup_yaml_only, FIX
from structured_doc import parse_document


def test_parse_valid_spec_md_extracts_implicit_frontmatter():
    setup_spec_md()
    res = parse_document("spec-md", FIX / "valid-spec.spec.md")
    assert res.ok
    fm = res.value.frontmatter
    assert fm["task_id"] == "DEMO-001"
    assert fm["sprint"] == "2026-31"
    assert fm["status"] == "Pendiente"


def test_parse_yaml_frontmatter():
    setup_spec_md()
    res = parse_document("spec-md", FIX / "yaml-fm.spec.md")
    assert res.ok
    assert res.value.frontmatter["task_id"] == "DEMO-005"
    assert res.value.frontmatter["sprint"] == "2026-31"


def test_parse_unknown_type_returns_failure():
    setup_spec_md()
    res = parse_document("nonexistent-type", FIX / "valid-spec.spec.md")
    assert not res.ok
    assert res.error_kind == "unknown-type"


def test_parse_missing_file_returns_failure():
    setup_spec_md()
    res = parse_document("spec-md", FIX / "does-not-exist.spec.md")
    assert not res.ok
    assert res.error_kind == "file-not-found"


def test_parse_empty_file_returns_failure():
    setup_spec_md()
    res = parse_document("spec-md", FIX / "empty.spec.md")
    assert not res.ok
    assert res.error_kind == "empty-document"


def test_parse_invalid_yaml_returns_failure():
    setup_spec_md()
    res = parse_document("spec-md", FIX / "invalid-yaml.spec.md")
    assert not res.ok
    assert res.error_kind == "invalid-yaml"


def test_parse_extracts_sections_with_levels():
    setup_spec_md()
    res = parse_document("spec-md", FIX / "valid-spec.spec.md")
    assert res.ok
    sections = res.value.sections
    titles = [s.title for s in sections]
    assert "Spec: Demo Valid" in titles
    assert "1. Context" in titles
    assert "2. Requirements" in titles
    # Headings appear at increasing line numbers
    line_starts = [s.line_start for s in sections]
    assert line_starts == sorted(line_starts)


def test_parse_yaml_only_mode():
    setup_yaml_only("raw-yaml")
    tmp = FIX / "diff-v1.spec.md"  # has YAML frontmatter; we read it raw
    # write a pure YAML doc on the fly
    pure = FIX / "_pure.yaml"
    pure.write_text("foo: 1\nbar: hello\n")
    res = parse_document("raw-yaml", pure)
    assert res.ok
    assert res.value.frontmatter == {"foo": 1, "bar": "hello"}
    pure.unlink()


def test_parse_total_lines_count():
    setup_spec_md()
    res = parse_document("spec-md", FIX / "too-long.spec.md")
    assert res.ok
    assert res.value.total_lines > 500
