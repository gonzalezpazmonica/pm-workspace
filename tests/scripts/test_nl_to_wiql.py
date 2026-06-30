"""tests/scripts/test_nl_to_wiql.py — SE-031 pytest suite for nl-to-wiql.py."""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

SCRIPT = Path(__file__).parent.parent.parent / "scripts" / "nl-to-wiql.py"


def run(query: str, backend: str = "ado", json_out: bool = False):
    cmd = [sys.executable, str(SCRIPT), "--query", query, "--backend", backend]
    if json_out:
        cmd.append("--json")
    result = subprocess.run(cmd, capture_output=True, text=True)
    return result


class TestCurrentIteration:
    def test_sprint_actual_contains_current_iteration(self):
        r = run("sprint actual")
        assert "@CurrentIteration" in r.stdout

    def test_current_sprint_ado(self):
        r = run("current sprint", backend="ado")
        assert "@CurrentIteration" in r.stdout

    def test_sprint_actual_jira(self):
        r = run("sprint actual", backend="jira")
        assert "openSprints()" in r.stdout

    def test_sprint_actual_json_output(self):
        r = run("sprint actual", json_out=True)
        data = json.loads(r.stdout)
        assert "@CurrentIteration" in data["translated_query"]
        assert data["query_type"] == "WIQL"


class TestMyItems:
    def test_mis_items_contains_me(self):
        r = run("mis items")
        assert "@Me" in r.stdout

    def test_my_items_english(self):
        r = run("my items assigned to me")
        assert "@Me" in r.stdout

    def test_mis_items_jira(self):
        r = run("mis items", backend="jira")
        assert "currentUser()" in r.stdout


class TestBlockedState:
    def test_bloqueados_produces_blocked_state(self):
        r = run("items bloqueados")
        assert "Blocked" in r.stdout

    def test_blocked_english(self):
        r = run("blocked items")
        assert "Blocked" in r.stdout

    def test_blocked_jira(self):
        r = run("blocked", backend="jira")
        assert "Blocked" in r.stdout


class TestBackendDifference:
    def test_ado_produces_wiql_syntax(self):
        r = run("sprint actual", backend="ado", json_out=True)
        data = json.loads(r.stdout)
        assert data["query_type"] == "WIQL"
        assert "FROM WorkItems" in data["translated_query"]

    def test_jira_produces_jql_syntax(self):
        r = run("sprint actual", backend="jira", json_out=True)
        data = json.loads(r.stdout)
        assert data["query_type"] == "JQL"
        assert "FROM WorkItems" not in data["translated_query"]

    def test_ado_uses_system_fields(self):
        r = run("mis items bloqueados", backend="ado")
        assert "[System." in r.stdout

    def test_jira_no_system_fields(self):
        r = run("mis items bloqueados", backend="jira")
        assert "[System." not in r.stdout


class TestJsonOutput:
    def test_json_output_is_valid(self):
        r = run("sprint actual", json_out=True)
        assert r.returncode == 0
        data = json.loads(r.stdout)  # must not raise
        assert isinstance(data, dict)

    def test_json_has_required_fields(self):
        r = run("mis items activos", json_out=True)
        data = json.loads(r.stdout)
        assert "query_type" in data
        assert "translated_query" in data
        assert "nl_input" in data
        assert "mock_result" in data

    def test_json_mock_result_has_items(self):
        r = run("sprint actual", json_out=True)
        data = json.loads(r.stdout)
        assert "items" in data["mock_result"]
        assert isinstance(data["mock_result"]["items"], list)

    def test_json_matched_patterns_list(self):
        r = run("sprint actual mis items", json_out=True)
        data = json.loads(r.stdout)
        assert isinstance(data["matched_patterns"], list)
        assert len(data["matched_patterns"]) >= 2


class TestEmptyQueryError:
    def test_empty_query_exits_nonzero(self):
        r = run("   ")
        assert r.returncode != 0

    def test_empty_query_error_message(self):
        r = run("   ")
        assert "empty" in r.stderr.lower() or r.returncode != 0


class TestCombinedPatterns:
    def test_mis_items_sprint_actual_combined(self):
        r = run("mis items sprint actual", json_out=True)
        data = json.loads(r.stdout)
        q = data["translated_query"]
        assert "@Me" in q
        assert "@CurrentIteration" in q

    def test_bugs_bloqueados(self):
        r = run("bugs bloqueados", json_out=True)
        data = json.loads(r.stdout)
        q = data["translated_query"]
        assert "Bug" in q
        assert "Blocked" in q
