import pytest
from conftest_structured_doc import setup_spec_md, FIX
from structured_doc import lint_document


def test_lint_valid_spec_emits_no_errors():
    setup_spec_md()
    res = lint_document("spec-md", FIX / "valid-spec.spec.md")
    assert res.ok
    assert res.value.summary.errors == 0


def test_lint_missing_fields_emits_errors():
    setup_spec_md()
    res = lint_document("spec-md", FIX / "missing-fields.spec.md")
    assert res.ok
    rule_ids = {f.rule_id for f in res.value.findings}
    assert "missing-required-field" in rule_ids
    # Two missing fields: sprint, status
    missing_findings = [f for f in res.value.findings
                        if f.rule_id == "missing-required-field"]
    assert len(missing_findings) == 2
    paths = {f.path for f in missing_findings}
    assert paths == {"frontmatter.sprint", "frontmatter.status"}


def test_lint_too_long_emits_warning():
    setup_spec_md()
    res = lint_document("spec-md", FIX / "too-long.spec.md")
    assert res.ok
    long_findings = [f for f in res.value.findings if f.rule_id == "spec-too-long"]
    assert len(long_findings) == 1
    assert long_findings[0].severity == "warning"


def test_lint_broken_reference_emits_error():
    setup_spec_md(rules="test-rules-with-refs.yaml", schema=None)
    res = lint_document("spec-md", FIX / "broken-ref.spec.md")
    assert res.ok
    refs = [f for f in res.value.findings if f.rule_id == "broken-spec-reference"]
    assert len(refs) == 1
    assert "SPEC-DOES-NOT-EXIST-XYZ" in refs[0].message


def test_lint_valid_reference_no_error():
    setup_spec_md(rules="test-rules-with-refs.yaml", schema=None)
    res = lint_document("spec-md", FIX / "valid-ref.spec.md")
    assert res.ok
    refs = [f for f in res.value.findings if f.rule_id == "broken-spec-reference"]
    assert refs == []


def test_lint_findings_summary_counts_by_severity():
    setup_spec_md()
    res = lint_document("spec-md", FIX / "missing-fields.spec.md")
    assert res.ok
    s = res.value.summary
    assert s.errors == 2
    assert s.warnings == 0


def test_lint_no_rules_returns_empty_report():
    setup_spec_md(rules=None)
    res = lint_document("spec-md", FIX / "valid-spec.spec.md")
    assert res.ok
    assert res.value.findings == []


def test_lint_findings_serialize_to_canonical_json():
    setup_spec_md()
    res = lint_document("spec-md", FIX / "missing-fields.spec.md")
    assert res.ok
    data = res.value.model_dump()
    assert "findings" in data
    assert "summary" in data
    f0 = data["findings"][0]
    assert set(f0.keys()) >= {"severity", "rule_id", "path", "message"}
