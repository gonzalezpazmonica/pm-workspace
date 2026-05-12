from conftest_structured_doc import setup_spec_md, FIX
from structured_doc import validate_document


def test_validate_valid_doc_passes():
    setup_spec_md()
    res = validate_document("spec-md", FIX / "valid-spec.spec.md")
    assert res.ok
    assert res.value.valid is True


def test_validate_missing_required_field_fails():
    setup_spec_md(schema="test-schema.json", rules=None)
    # Doc with NO task_id at all
    p = FIX / "_no-task-id.spec.md"
    p.write_text("# foo\n\n**Sprint:** x\n")
    try:
        res = validate_document("spec-md", p)
        assert res.ok
        assert res.value.valid is False
        assert any("task_id" in e.message or "task_id" in e.path
                   for e in res.value.errors)
    finally:
        p.unlink()


def test_validate_no_schema_returns_valid():
    setup_spec_md(schema=None)
    res = validate_document("spec-md", FIX / "valid-spec.spec.md")
    assert res.ok
    assert res.value.valid is True


def test_validate_returns_failure_for_missing_file():
    setup_spec_md()
    res = validate_document("spec-md", FIX / "does-not-exist.spec.md")
    assert not res.ok
    assert res.error_kind == "file-not-found"
