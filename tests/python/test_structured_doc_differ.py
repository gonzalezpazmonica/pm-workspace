from conftest_structured_doc import setup_spec_md, FIX
from structured_doc import diff_documents


def test_diff_no_changes_when_same_file():
    setup_spec_md()
    res = diff_documents("spec-md",
                         FIX / "diff-v1.spec.md",
                         FIX / "diff-v1.spec.md")
    assert res.ok
    assert res.value.changes == []
    assert res.value.regression is False


def test_diff_detects_frontmatter_modified():
    setup_spec_md()
    res = diff_documents("spec-md",
                         FIX / "diff-v1.spec.md",
                         FIX / "diff-v2.spec.md")
    assert res.ok
    kinds = {c.kind for c in res.value.changes}
    assert "frontmatter-modified" in kinds  # sprint changed


def test_diff_detects_frontmatter_added_and_removed():
    setup_spec_md()
    res = diff_documents("spec-md",
                         FIX / "diff-v1.spec.md",
                         FIX / "diff-v2.spec.md")
    assert res.ok
    kinds = {c.kind for c in res.value.changes}
    assert "frontmatter-added" in kinds   # new_field added in v2
    assert "frontmatter-removed" in kinds  # status removed in v2


def test_diff_detects_section_added_and_removed():
    setup_spec_md()
    res = diff_documents("spec-md",
                         FIX / "diff-v1.spec.md",
                         FIX / "diff-v2.spec.md")
    assert res.ok
    kinds = {c.kind for c in res.value.changes}
    assert "section-added" in kinds    # "3. New Section"
    assert "section-removed" in kinds  # "2. Requirements"


def test_diff_regression_flag_set_when_destructive():
    setup_spec_md()
    res = diff_documents("spec-md",
                         FIX / "diff-v1.spec.md",
                         FIX / "diff-v2.spec.md")
    assert res.ok
    assert res.value.regression is True
