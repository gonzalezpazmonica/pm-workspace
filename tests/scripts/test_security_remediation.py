"""tests/scripts/test_security_remediation.py -- SPEC-070

Tests for scripts/security-remediation-generator.py.
"""
from __future__ import annotations

import importlib.util
import json
import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
SCRIPT = REPO_ROOT / "scripts" / "security-remediation-generator.py"


def _load():
    spec = importlib.util.spec_from_file_location("sec_rem_gen", SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    sys.modules["sec_rem_gen"] = mod
    spec.loader.exec_module(mod)
    return mod


mod = _load()
generate = mod.generate
main = mod.main

SQLI = "sql-injection"
XSS = "xss"
CRED = "hardcoded-cred"
PATH = "path-traversal"
CMDI = "command-injection"
DESER = "insecure-deserialization"
CSRF = "csrf"
SDATA = "sensitive-data-exposure"
BAUTH = "broken-auth"
REDIR = "open-redirect"


class TestSqlInjection:
    def test_type_normalized(self):
        r = generate(SQLI)
        assert r["vulnerability_type"] == SQLI

    def test_fix_mentions_parameterized(self):
        r = generate(SQLI)
        combined = r["fix_description"] + r["code_patch_suggestion"]
        assert "parameterized" in combined.lower()

    def test_severity_high(self):
        assert generate(SQLI)["severity"] == "high"

    def test_references_not_empty(self):
        assert len(generate(SQLI)["references"]) > 0

    def test_owasp_reference_present(self):
        combined = " ".join(generate(SQLI)["references"])
        assert "owasp" in combined.lower()

    def test_alias_sqli(self):
        assert generate("sqli")["vulnerability_type"] == SQLI

    def test_alias_underscore(self):
        assert generate("sql_injection")["vulnerability_type"] == SQLI


class TestHardcodedCred:
    def test_type_normalized(self):
        assert generate(CRED)["vulnerability_type"] == CRED

    def test_fix_mentions_env_var(self):
        r = generate(CRED)
        combined = r["fix_description"] + r["code_patch_suggestion"]
        assert "env" in combined.lower() or "environ" in combined.lower()

    def test_severity_high(self):
        assert generate(CRED)["severity"] == "high"

    def test_references_not_empty(self):
        assert len(generate(CRED)["references"]) > 0

    def test_alias_hardcoded_secret(self):
        assert generate("hardcoded-secret")["vulnerability_type"] == CRED

    def test_alias_hardcoded_password(self):
        assert generate("hardcoded-password")["vulnerability_type"] == CRED

    def test_patch_shows_environ(self):
        patch = generate(CRED)["code_patch_suggestion"]
        assert "environ" in patch


class TestXss:
    def test_type_normalized(self):
        assert generate(XSS)["vulnerability_type"] == XSS

    def test_fix_mentions_escaping(self):
        r = generate(XSS)
        combined = r["fix_description"] + r["code_patch_suggestion"]
        assert "escap" in combined.lower()

    def test_severity_high(self):
        assert generate(XSS)["severity"] == "high"

    def test_references_not_empty(self):
        assert len(generate(XSS)["references"]) > 0

    def test_alias_cross_site_scripting(self):
        assert generate("cross-site-scripting")["vulnerability_type"] == XSS

    def test_patch_shows_html_escape(self):
        assert "escape" in generate(XSS)["code_patch_suggestion"].lower()


class TestSeverityAssignment:
    @pytest.mark.parametrize("vuln_type,expected_sev", [
        (SQLI, "high"), (XSS, "high"), (CRED, "high"),
        (PATH, "high"), (CMDI, "high"), (DESER, "high"),
        (CSRF, "medium"), (SDATA, "medium"), (BAUTH, "high"),
        (REDIR, "medium"),
    ])
    def test_severity(self, vuln_type, expected_sev):
        assert generate(vuln_type)["severity"] == expected_sev


class TestReferences:
    @pytest.mark.parametrize("vuln_type", [SQLI, XSS, CRED, PATH, CMDI, CSRF, BAUTH])
    def test_references_not_empty(self, vuln_type):
        r = generate(vuln_type)
        assert isinstance(r["references"], list)
        assert len(r["references"]) > 0

    def test_references_are_strings(self):
        for ref in generate(SQLI)["references"]:
            assert isinstance(ref, str) and len(ref) > 0


class TestConfidence:
    @pytest.mark.parametrize("vuln_type", [
        SQLI, XSS, CRED, PATH, CMDI, CSRF, SDATA, BAUTH, REDIR, "unknown-xyz",
    ])
    def test_confidence_in_range(self, vuln_type):
        c = generate(vuln_type)["confidence"]
        assert 0.0 <= c <= 1.0

    def test_known_higher_than_unknown(self):
        assert generate(SQLI)["confidence"] > generate("totally-unknown-vuln-xyz")["confidence"]


class TestJsonOutput:
    REQUIRED = ["vulnerability_type", "severity", "fix_description",
                "code_patch_suggestion", "references", "confidence"]

    def test_all_required_fields(self):
        r = generate(SQLI)
        for field in self.REQUIRED:
            assert field in r

    def test_serializable(self):
        parsed = json.loads(json.dumps(generate(XSS)))
        assert "vulnerability_type" in parsed

    @pytest.mark.parametrize("vuln_type", [SQLI, XSS, CRED, "unknown-vuln"])
    def test_fields_present_all_types(self, vuln_type):
        r = generate(vuln_type)
        for field in ["fix_description", "code_patch_suggestion", "references", "confidence"]:
            assert field in r


class TestFixDescription:
    @pytest.mark.parametrize("vuln_type", [
        SQLI, XSS, CRED, PATH, CMDI, DESER, CSRF, SDATA, BAUTH, REDIR,
    ])
    def test_not_empty(self, vuln_type):
        r = generate(vuln_type)
        assert isinstance(r["fix_description"], str)
        assert len(r["fix_description"].strip()) > 0

    def test_patch_not_empty(self):
        r = generate(SQLI)
        assert isinstance(r["code_patch_suggestion"], str)
        assert len(r["code_patch_suggestion"].strip()) > 0


class TestCli:
    def test_main_produces_json(self, capsys):
        rc = main(["--type", SQLI])
        assert rc == 0
        parsed = json.loads(capsys.readouterr().out)
        assert "vulnerability_type" in parsed

    def test_main_with_code_flag_includes_snippet(self, capsys):
        snippet = "execute(query)"
        rc = main(["--type", SQLI, "--code", snippet])
        assert rc == 0
        parsed = json.loads(capsys.readouterr().out)
        assert snippet in parsed["code_patch_suggestion"]
