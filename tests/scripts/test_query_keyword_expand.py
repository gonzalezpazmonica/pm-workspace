"""tests/scripts/test_query_keyword_expand.py — SPEC-073

Tests for scripts/query-keyword-expand.py: CamelCase splitting,
snake_case splitting, acronym expansion, domain synonyms, and output structure.
"""
from __future__ import annotations

import importlib.util
import json
import sys
from pathlib import Path

import pytest

# ── Load module ───────────────────────────────────────────────────────────────
REPO_ROOT = Path(__file__).resolve().parent.parent.parent
SCRIPT = REPO_ROOT / "scripts" / "query-keyword-expand.py"


def _load():
    spec = importlib.util.spec_from_file_location("query_keyword_expand", SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


mod = _load()
expand_query = mod.expand_query
split_camel = mod.split_camel
split_snake = mod.split_snake
main = mod.main
SYNONYMS = mod.SYNONYMS
ACRONYMS = mod.ACRONYMS


# ── TC-1: CamelCase split ─────────────────────────────────────────────────────

class TestCamelCaseSplit:
    """CamelCase terms are split into lowercase parts."""

    def test_auth_service(self):
        parts = split_camel("authService")
        assert "auth" in parts
        assert "service" in parts

    def test_user_controller(self):
        parts = split_camel("UserController")
        assert "user" in parts
        assert "controller" in parts

    def test_original_preserved_when_multiple_parts(self):
        parts = split_camel("authService")
        # Original lowercase version included
        assert "authservice" in parts

    def test_single_word_no_split(self):
        parts = split_camel("auth")
        # Single lowercase word — no split needed
        assert parts == ["auth"]

    def test_empty_string(self):
        parts = split_camel("")
        assert parts == []

    def test_multi_word_camel(self):
        parts = split_camel("getUserById")
        assert "get" in parts
        assert "user" in parts
        assert "by" in parts
        assert "id" in parts


# ── TC-2: snake_case split ────────────────────────────────────────────────────

class TestSnakeCaseSplit:
    """snake_case terms are split on underscores."""

    def test_auth_service(self):
        parts = split_snake("auth_service")
        assert "auth" in parts
        assert "service" in parts

    def test_three_parts(self):
        parts = split_snake("get_user_by_id")
        assert "get" in parts
        assert "user" in parts
        assert "by" in parts
        assert "id" in parts

    def test_no_underscore_returns_empty(self):
        parts = split_snake("authservice")
        assert parts == []

    def test_leading_underscore(self):
        parts = split_snake("_private_var")
        # Empty token from leading underscore is filtered
        assert "private" in parts
        assert "var" in parts


# ── TC-3: Auth synonym expansion ─────────────────────────────────────────────

class TestAuthSynonymExpansion:
    """'auth' expands to include 'authentication'."""

    def test_auth_expands_to_authentication(self):
        result = expand_query("auth")
        all_terms = result["expanded"] + result["search_terms"]
        assert any("authentication" in t for t in all_terms)

    def test_auth_expands_to_login(self):
        result = expand_query("auth")
        all_terms = result["expanded"] + result["search_terms"]
        assert any("login" in t for t in all_terms)

    def test_auth_expands_to_jwt(self):
        result = expand_query("auth")
        all_terms = result["expanded"] + result["search_terms"]
        assert any("jwt" in t for t in all_terms)

    def test_synonyms_dict_contains_auth(self):
        result = expand_query("auth service")
        assert "auth" in result["synonyms"]
        assert len(result["synonyms"]["auth"]) > 0


# ── TC-4: Acronym expansion ───────────────────────────────────────────────────

class TestAcronymExpansion:
    """Known acronyms are expanded."""

    def test_ado_expands_to_azure_devops(self):
        result = expand_query("ADO")
        all_terms = result["expanded"] + result["search_terms"]
        # "Azure DevOps" should appear as a term or its components
        combined = " ".join(all_terms).lower()
        assert "azure" in combined or "devops" in combined or "azure devops" in combined

    def test_kg_expands_to_knowledge_graph(self):
        result = expand_query("KG search")
        all_terms = result["expanded"] + result["search_terms"]
        combined = " ".join(all_terms).lower()
        assert "knowledge" in combined or "knowledge graph" in combined

    def test_acronyms_map_not_empty(self):
        assert len(ACRONYMS) > 0
        assert "ADO" in ACRONYMS
        assert "KG" in ACRONYMS


# ── TC-5: Output JSON has all required fields ─────────────────────────────────

class TestOutputStructure:
    """Output has all required keys with correct types."""

    def test_output_has_original(self):
        result = expand_query("buscar auth service")
        assert "original" in result
        assert result["original"] == "buscar auth service"

    def test_output_has_expanded(self):
        result = expand_query("buscar auth service")
        assert "expanded" in result
        assert isinstance(result["expanded"], list)

    def test_output_has_synonyms(self):
        result = expand_query("buscar auth service")
        assert "synonyms" in result
        assert isinstance(result["synonyms"], dict)

    def test_output_has_search_terms(self):
        result = expand_query("buscar auth service")
        assert "search_terms" in result
        assert isinstance(result["search_terms"], list)

    def test_all_four_keys_present(self):
        result = expand_query("test query")
        for key in ("original", "expanded", "synonyms", "search_terms"):
            assert key in result, f"Missing key: {key}"


# ── TC-6: search_terms is non-empty ──────────────────────────────────────────

class TestSearchTermsNonEmpty:
    """search_terms list is non-empty for valid queries."""

    def test_simple_query_has_terms(self):
        result = expand_query("auth")
        assert len(result["search_terms"]) > 0

    def test_multi_word_query_has_terms(self):
        result = expand_query("buscar auth service")
        assert len(result["search_terms"]) > 0

    def test_camel_case_query_has_terms(self):
        result = expand_query("authService")
        assert len(result["search_terms"]) > 0


# ── TC-7: Empty query graceful exit ──────────────────────────────────────────

class TestEmptyQueryGracefulExit:
    """Empty or whitespace-only query returns valid structure without error."""

    def test_empty_string(self):
        result = expand_query("")
        assert result["original"] == ""
        assert isinstance(result["expanded"], list)
        assert isinstance(result["search_terms"], list)

    def test_whitespace_only(self):
        result = expand_query("   ")
        assert isinstance(result["expanded"], list)

    def test_cli_empty_query_exits_zero(self, capsys):
        rc = main(["--query", ""])
        assert rc == 0


# ── TC-8: synonyms dict non-empty for known term ─────────────────────────────

class TestSynonymsDictNonEmpty:
    """synonyms dict contains entries for known domain terms."""

    def test_auth_synonym_present(self):
        result = expand_query("auth")
        assert "auth" in result["synonyms"]
        assert len(result["synonyms"]["auth"]) >= 3

    def test_spec_synonym_present(self):
        result = expand_query("spec")
        assert "spec" in result["synonyms"]
        assert len(result["synonyms"]["spec"]) > 0

    def test_unknown_term_has_empty_synonyms(self):
        result = expand_query("xyzunknownterm999")
        # No synonym found for unknown term — synonyms dict is empty or missing the key
        assert result["synonyms"].get("xyzunknownterm999") is None


# ── TC-9: CLI output is valid JSON ────────────────────────────────────────────

class TestCLIOutput:
    """CLI produces valid JSON with all required fields."""

    def test_cli_json_structure(self, capsys):
        rc = main(["--query", "buscar auth service"])
        assert rc == 0
        captured = capsys.readouterr()
        parsed = json.loads(captured.out)
        for key in ("original", "expanded", "synonyms", "search_terms"):
            assert key in parsed

    def test_cli_original_preserved(self, capsys):
        rc = main(["--query", "ADO queries"])
        assert rc == 0
        captured = capsys.readouterr()
        parsed = json.loads(captured.out)
        assert parsed["original"] == "ADO queries"
