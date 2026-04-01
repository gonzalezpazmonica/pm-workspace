#!/usr/bin/env python3
"""Unit tests for subproject detection helpers in savia-bridge.py."""

import sys
import os
import tempfile
from pathlib import Path

# Add scripts/ to path so we can import helper functions
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

# We need to extract the helper functions without running the server.
# Import them by exec'ing just the function definitions.
_bridge_path = Path(__file__).parent.parent / "savia-bridge.py"
_code = _bridge_path.read_text(encoding="utf-8")

# Extract helper functions
_ns = {"Path": Path, "__builtins__": __builtins__}
for func_name in ("_EXCLUDED_SUBDIRS", "_detect_subprojects", "_parse_confidentiality", "_umbrella_display_name"):
    start = _code.find(f"\n_EXCLUDED_SUBDIRS" if func_name == "_EXCLUDED_SUBDIRS" else f"\ndef {func_name}")
    if start < 0:
        continue
    # Find the end (next top-level def or class)
    end = _code.find("\ndef ", start + 10)
    if end < 0:
        end = len(_code)
    snippet = _code[start:end]
    exec(snippet, _ns)

_detect_subprojects = _ns["_detect_subprojects"]
_parse_confidentiality = _ns["_parse_confidentiality"]
_umbrella_display_name = _ns["_umbrella_display_name"]


def _make_tree(base: Path, structure: dict):
    """Create a directory tree from a dict. Keys are names, values are:
    - dict: subdirectory with contents
    - str: file with content
    - None: empty file
    """
    base.mkdir(parents=True, exist_ok=True)
    for name, content in structure.items():
        p = base / name
        if isinstance(content, dict):
            _make_tree(p, content)
        else:
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_text(content or "", encoding="utf-8")


class TestDetectSubprojects:
    def test_empty_dir(self, tmp_path):
        assert _detect_subprojects(tmp_path) == []

    def test_subdir_with_readme(self, tmp_path):
        _make_tree(tmp_path, {
            "child1": {"README.md": "# Child 1"},
            "child2": {"README.md": "# Child 2"},
        })
        children = _detect_subprojects(tmp_path)
        names = [c.name for c in children]
        assert names == ["child1", "child2"]

    def test_subdir_with_git(self, tmp_path):
        _make_tree(tmp_path, {
            "repo": {".git": {"HEAD": "ref: refs/heads/main"}},
        })
        children = _detect_subprojects(tmp_path)
        assert len(children) == 1
        assert children[0].name == "repo"

    def test_excludes_dotdirs(self, tmp_path):
        _make_tree(tmp_path, {
            ".hidden": {"README.md": "hidden"},
            "visible": {"README.md": "visible"},
        })
        children = _detect_subprojects(tmp_path)
        assert len(children) == 1
        assert children[0].name == "visible"

    def test_excludes_known_dirs(self, tmp_path):
        _make_tree(tmp_path, {
            "output": {"README.md": "output"},
            "digests": {"README.md": "digests"},
            "specs": {"README.md": "specs"},
            "real-child": {"README.md": "child"},
        })
        children = _detect_subprojects(tmp_path)
        assert len(children) == 1
        assert children[0].name == "real-child"

    def test_no_readme_no_git_excluded(self, tmp_path):
        _make_tree(tmp_path, {
            "empty-dir": {"some-file.txt": "data"},
        })
        assert _detect_subprojects(tmp_path) == []

    def test_sorted_alphabetically(self, tmp_path):
        _make_tree(tmp_path, {
            "zebra": {"README.md": "z"},
            "alpha": {"README.md": "a"},
            "middle": {"README.md": "m"},
        })
        children = _detect_subprojects(tmp_path)
        names = [c.name for c in children]
        assert names == ["alpha", "middle", "zebra"]


class TestParseConfidentiality:
    def test_no_file(self, tmp_path):
        assert _parse_confidentiality(tmp_path) == {}

    def test_heading_format(self, tmp_path):
        """Parse the heading format used by trazabios_main."""
        _make_tree(tmp_path, {
            "trazabios": {"README.md": ""},
            "trazabios-pm": {"README.md": ""},
            "trazabios-vass": {"README.md": ""},
            "confidentiality.md": (
                "# Confidentiality\n\n"
                "### N4-SHARED — trazabios_main/trazabios/\n\n"
                "Shared with client.\n\n"
                "### N4-VASS — trazabios_main/trazabios-vass/\n\n"
                "Internal VASS.\n\n"
                "### N4b-PM — trazabios_main/trazabios-pm/\n\n"
                "PM only.\n"
            ),
        })
        result = _parse_confidentiality(tmp_path)
        assert result["trazabios"] == "N4-SHARED"
        assert result["trazabios-vass"] == "N4-VASS"
        assert result["trazabios-pm"] == "N4b-PM"

    def test_table_format(self, tmp_path):
        _make_tree(tmp_path, {
            "shared": {"README.md": ""},
            "private": {"README.md": ""},
            "confidentiality.md": (
                "| Level | Dir |\n"
                "|---|---|\n"
                "| N4-SHARED | shared/ |\n"
                "| N4b-PM | private/ |\n"
            ),
        })
        result = _parse_confidentiality(tmp_path)
        assert result["shared"] == "N4-SHARED"
        assert result["private"] == "N4b-PM"

    def test_substring_names_resolved_correctly(self, tmp_path):
        """'trazabios' should not match 'trazabios-pm' line."""
        _make_tree(tmp_path, {
            "app": {"README.md": ""},
            "app-admin": {"README.md": ""},
            "confidentiality.md": (
                "### N4-SHARED — project/app/\n\n"
                "### N4b-PM — project/app-admin/\n\n"
            ),
        })
        result = _parse_confidentiality(tmp_path)
        assert result["app"] == "N4-SHARED"
        assert result["app-admin"] == "N4b-PM"


class TestUmbrellaDisplayName:
    def test_strips_main_suffix(self, tmp_path):
        d = tmp_path / "trazabios_main"
        d.mkdir()
        assert _umbrella_display_name(d) == "Trazabios"

    def test_strips_dash_main(self, tmp_path):
        d = tmp_path / "project-main"
        d.mkdir()
        assert _umbrella_display_name(d) == "Project"

    def test_extracts_from_claude_md(self, tmp_path):
        d = tmp_path / "my_project_main"
        d.mkdir()
        (d / "claude-my-project.md").write_text("# My Cool Project \u2014 Config\n\nContent here.", encoding="utf-8")
        assert _umbrella_display_name(d) == "My Cool Project"

    def test_no_claude_file_uses_titlecase(self, tmp_path):
        d = tmp_path / "multi-word-project_main"
        d.mkdir()
        assert _umbrella_display_name(d) == "Multi Word Project"


if __name__ == "__main__":
    import pytest
    sys.exit(pytest.main([__file__, "-v"]))
