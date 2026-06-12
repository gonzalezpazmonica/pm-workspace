"""Tests for scripts/context-greedy-budget.py — SPEC-189.

Covers tokenizer, scoring components, greedy budget selection, adapters,
formatters, and end-to-end CLI behavior.
"""
from __future__ import annotations

import importlib.util
import json
import sqlite3
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "context-greedy-budget.py"
FIXTURES = ROOT / "tests" / "fixtures" / "context-greedy-budget"


def _load_module():
    """Load the script as a module so we can call its internals directly."""
    spec = importlib.util.spec_from_file_location("cgb", SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


@pytest.fixture(scope="module")
def cgb():
    return _load_module()


# ─────────────────────────────────────────────────────────────────────────────
# Tokenizer
# ─────────────────────────────────────────────────────────────────────────────


def test_tokenize_camel_case_breaks_into_parts(cgb):
    tokens = cgb.tokenize("calcularPlayerStats")
    assert "calcular" in tokens
    assert "player" in tokens
    assert "stats" in tokens
    assert "calcularplayerstats" in tokens


def test_tokenize_snake_case(cgb):
    tokens = cgb.tokenize("auth_flow_controller")
    assert "auth" in tokens
    assert "flow" in tokens
    assert "controller" in tokens


def test_tokenize_uppercase_run(cgb):
    tokens = cgb.tokenize("XMLParser")
    assert "xml" in tokens
    assert "parser" in tokens


def test_tokenize_empty_returns_empty_list(cgb):
    assert cgb.tokenize("") == []


def test_tokenize_lowercases(cgb):
    tokens = cgb.tokenize("ABCdef")
    assert all(t == t.lower() for t in tokens)


# ─────────────────────────────────────────────────────────────────────────────
# PageRank
# ─────────────────────────────────────────────────────────────────────────────


def test_pagerank_empty_graph(cgb):
    assert cgb.pagerank([], {}) == {}


def test_pagerank_uniform_for_disconnected(cgb):
    nodes = ["a", "b", "c"]
    rank = cgb.pagerank(nodes, {})
    # All nodes are dangling and disconnected -> uniform within tolerance
    values = list(rank.values())
    assert max(values) - min(values) < 1e-6
    assert abs(sum(values) - 1.0) < 1e-3


def test_pagerank_hub_outranks_leaf(cgb):
    # b and c both point to a -> a should have highest rank
    nodes = ["a", "b", "c"]
    edges = {"b": ["a"], "c": ["a"]}
    rank = cgb.pagerank(nodes, edges)
    assert rank["a"] > rank["b"]
    assert rank["a"] > rank["c"]


# ─────────────────────────────────────────────────────────────────────────────
# TF-IDF
# ─────────────────────────────────────────────────────────────────────────────


def test_tfidf_empty_query_returns_zeros(cgb):
    docs = {"a": ["foo", "bar"], "b": ["baz"]}
    scores = cgb.tfidf_scores(docs, "")
    assert all(v == 0.0 for v in scores.values())


def test_tfidf_perfect_match_high_score(cgb):
    docs = {
        "a": ["authenticate", "user"],
        "b": ["payment", "service"],
        "c": ["random", "noise"],
    }
    scores = cgb.tfidf_scores(docs, "authenticate user")
    assert scores["a"] > scores["b"]
    assert scores["a"] > scores["c"]
    assert scores["a"] > 0.5


def test_tfidf_no_match_zero(cgb):
    docs = {"a": ["foo"], "b": ["bar"]}
    scores = cgb.tfidf_scores(docs, "completely different")
    assert scores["a"] == 0.0
    assert scores["b"] == 0.0


# ─────────────────────────────────────────────────────────────────────────────
# Score combination
# ─────────────────────────────────────────────────────────────────────────────


def test_compute_scores_returns_three_dicts(cgb):
    graph = {
        "nodes": {
            "a": {"label": "Alpha", "text": "alpha node", "kind": "doc", "neighbors": ["b"]},
            "b": {"label": "Beta", "text": "beta node", "kind": "doc", "neighbors": []},
        }
    }
    final, structural, semantic = cgb.compute_scores(graph, "alpha")
    assert set(final.keys()) == {"a", "b"}
    assert set(structural.keys()) == {"a", "b"}
    assert set(semantic.keys()) == {"a", "b"}
    assert all(0.0 <= v <= 1.0 for v in final.values())


def test_code_boost_clamp_at_one(cgb):
    # node with very high base score AND kind=code → clamped to 1.0
    graph = {
        "nodes": {
            "x": {
                "label": "Match",
                "text": "perfect match for query " * 5,
                "kind": "code",
                "neighbors": [],
            }
        }
    }
    final, _, _ = cgb.compute_scores(graph, "perfect match query")
    assert final["x"] <= 1.0


def test_compute_scores_empty_graph(cgb):
    final, structural, semantic = cgb.compute_scores({"nodes": {}}, "anything")
    assert final == {}
    assert structural == {}
    assert semantic == {}


# ─────────────────────────────────────────────────────────────────────────────
# Greedy budget selection
# ─────────────────────────────────────────────────────────────────────────────


def _simple_graph():
    return {
        "nodes": {
            "a": {"label": "A", "text": "alpha first", "kind": "doc", "neighbors": ["b"]},
            "b": {"label": "B", "text": "beta two", "kind": "doc", "neighbors": ["c"]},
            "c": {"label": "C", "text": "gamma three", "kind": "doc", "neighbors": []},
            "d": {"label": "D", "text": "delta four", "kind": "doc", "neighbors": []},
        }
    }


def test_select_respects_budget_zero(cgb):
    graph = _simple_graph()
    scores = {"a": 0.9, "b": 0.5, "c": 0.3, "d": 0.2}
    selected, stats = cgb.select_subgraph(graph, scores, budget=0)
    assert selected == []
    assert stats["tokens_used"] == 0


def test_select_respects_budget_small(cgb):
    graph = _simple_graph()
    scores = {"a": 0.9, "b": 0.5, "c": 0.3, "d": 0.2}
    selected, stats = cgb.select_subgraph(graph, scores, budget=8, min_score=0.0)
    assert stats["tokens_used"] <= 8


def test_select_respects_budget_large_includes_all(cgb):
    graph = _simple_graph()
    scores = {"a": 0.9, "b": 0.5, "c": 0.3, "d": 0.2}
    selected, stats = cgb.select_subgraph(graph, scores, budget=10000, min_score=0.0)
    assert len(selected) == 4
    assert stats["nodes_selected"] == 4


def test_select_min_score_filter_excludes_low(cgb):
    graph = _simple_graph()
    scores = {"a": 0.9, "b": 0.5, "c": 0.3, "d": 0.05}
    selected, _ = cgb.select_subgraph(graph, scores, budget=10000, min_score=0.2)
    assert "d" not in selected
    assert "a" in selected and "b" in selected and "c" in selected


def test_select_neighbor_decay_boosts_neighbor(cgb):
    # b is a neighbor of a. With high decay, b should be selected even if its
    # original score was lower than another non-neighbor.
    graph = {
        "nodes": {
            "a": {"label": "A", "text": "a", "kind": "doc", "neighbors": ["b"]},
            "b": {"label": "B", "text": "b", "kind": "doc", "neighbors": []},
            "z": {"label": "Z", "text": "z", "kind": "doc", "neighbors": []},
        }
    }
    scores = {"a": 1.0, "b": 0.2, "z": 0.3}
    # budget large enough for 2 nodes
    selected, _ = cgb.select_subgraph(graph, scores, budget=100, min_score=0.15, neighbor_decay=1.0)
    # a is selected first; with neighbor_decay=1.0, b gets boosted to 1.0,
    # which is greater than z's 0.3. So second pick is b.
    assert selected[0] == "a"
    assert "b" in selected


def test_select_deterministic_same_input_same_output(cgb):
    graph = _simple_graph()
    scores = {"a": 0.5, "b": 0.5, "c": 0.5, "d": 0.5}
    sel1, stats1 = cgb.select_subgraph(graph, scores, budget=20, min_score=0.0)
    sel2, stats2 = cgb.select_subgraph(graph, scores, budget=20, min_score=0.0)
    assert sel1 == sel2
    assert stats1 == stats2


def test_select_tie_break_alphabetical(cgb):
    graph = _simple_graph()
    scores = {"a": 0.5, "b": 0.5, "c": 0.5, "d": 0.5}
    selected, _ = cgb.select_subgraph(graph, scores, budget=10000, min_score=0.0)
    # All tied; alphabetical order
    assert selected == ["a", "b", "c", "d"]


def test_select_empty_candidates_with_min_score(cgb):
    graph = _simple_graph()
    scores = {"a": 0.05, "b": 0.05, "c": 0.05, "d": 0.05}
    selected, stats = cgb.select_subgraph(graph, scores, budget=10000, min_score=0.5)
    assert selected == []
    assert stats["nodes_total"] == 4


def test_select_budget_never_exceeded_random_inputs(cgb):
    """Property: for any candidate set, tokens_used <= budget."""
    import random

    rng = random.Random(42)
    for _ in range(20):
        n = rng.randint(2, 20)
        nodes = {
            f"n{i}": {
                "label": f"Node{i}",
                "text": "lorem ipsum dolor " * rng.randint(1, 10),
                "kind": "doc",
                "neighbors": [],
            }
            for i in range(n)
        }
        graph = {"nodes": nodes}
        scores = {nid: rng.random() for nid in nodes}
        budget = rng.randint(10, 200)
        _, stats = cgb.select_subgraph(graph, scores, budget=budget, min_score=0.0)
        assert stats["tokens_used"] <= budget, (
            f"budget={budget} but tokens_used={stats['tokens_used']}"
        )


# ─────────────────────────────────────────────────────────────────────────────
# Token counters
# ─────────────────────────────────────────────────────────────────────────────


def test_heuristic_token_counter(cgb):
    assert cgb.count_tokens_heuristic("") == 0
    assert cgb.count_tokens_heuristic("abcd") == 1
    assert cgb.count_tokens_heuristic("abcdefgh") == 2


def test_make_token_counter_falls_back(cgb):
    counter = cgb.make_token_counter("nonsense")
    assert counter is cgb.count_tokens_heuristic


# ─────────────────────────────────────────────────────────────────────────────
# Adapters: ACM
# ─────────────────────────────────────────────────────────────────────────────


def test_adapter_acm_parses_headings(cgb):
    graph = cgb.adapter_acm(FIXTURES / "sample.acm")
    nodes = graph["nodes"]
    assert "authentication-service" in nodes
    assert "userrepository" in nodes
    assert nodes["authentication-service"]["kind"] == "doc"


def test_adapter_acm_extracts_arrow_neighbors(cgb):
    graph = cgb.adapter_acm(FIXTURES / "sample.acm")
    auth = graph["nodes"]["authentication-service"]
    assert "userrepository" in auth["neighbors"]
    assert "jwtissuer" in auth["neighbors"]


def test_adapter_acm_missing_file(cgb):
    with pytest.raises(FileNotFoundError):
        cgb.adapter_acm(FIXTURES / "nonexistent.acm")


# ─────────────────────────────────────────────────────────────────────────────
# Adapters: JSONL/JSON
# ─────────────────────────────────────────────────────────────────────────────


def test_adapter_jsonl_graph_json_object(cgb):
    graph = cgb.adapter_jsonl_graph(FIXTURES / "sample-graph.json")
    nodes = graph["nodes"]
    assert "auth_service" in nodes
    assert "user_repo" in nodes["auth_service"]["neighbors"]
    assert "jwt_issuer" in nodes["auth_service"]["neighbors"]
    assert nodes["auth_service"]["kind"] == "code"


def test_adapter_jsonl_graph_jsonl_one_per_line(cgb, tmp_path):
    p = tmp_path / "g.jsonl"
    lines = [
        json.dumps({"id": "a", "label": "A", "text": "alpha", "neighbors": ["b"]}),
        json.dumps({"id": "b", "label": "B", "text": "beta", "neighbors": []}),
    ]
    p.write_text("\n".join(lines), encoding="utf-8")
    graph = cgb.adapter_jsonl_graph(p)
    assert set(graph["nodes"]) == {"a", "b"}
    assert graph["nodes"]["a"]["neighbors"] == ["b"]


def test_adapter_jsonl_invalid_raises(cgb, tmp_path):
    p = tmp_path / "broken.json"
    p.write_text("{this is not json}", encoding="utf-8")
    with pytest.raises(ValueError):
        cgb.adapter_jsonl_graph(p)


# ─────────────────────────────────────────────────────────────────────────────
# Adapters: KG-SQLite
# ─────────────────────────────────────────────────────────────────────────────


@pytest.fixture
def kg_db(tmp_path):
    p = tmp_path / "kg.db"
    conn = sqlite3.connect(str(p))
    conn.execute("CREATE TABLE entities (id INTEGER PRIMARY KEY, name TEXT, type TEXT, description TEXT)")
    conn.execute("CREATE TABLE relations (source_id INTEGER, target_id INTEGER, type TEXT)")
    rows = [
        (1, "AuthService", "code", "Validates credentials"),
        (2, "UserRepo", "code", "User database access"),
        (3, "JwtIssuer", "code", "JWT token signing"),
    ]
    conn.executemany("INSERT INTO entities (id, name, type, description) VALUES (?, ?, ?, ?)", rows)
    conn.executemany(
        "INSERT INTO relations (source_id, target_id, type) VALUES (?, ?, ?)",
        [(1, 2, "depends"), (1, 3, "depends")],
    )
    conn.commit()
    conn.close()
    return p


def test_adapter_kg_sqlite_loads_entities_and_relations(cgb, kg_db):
    graph = cgb.adapter_kg_sqlite(kg_db)
    assert set(graph["nodes"]) == {"1", "2", "3"}
    assert "2" in graph["nodes"]["1"]["neighbors"]
    assert "3" in graph["nodes"]["1"]["neighbors"]
    assert graph["nodes"]["1"]["label"] == "AuthService"


def test_adapter_kg_sqlite_missing_file(cgb, tmp_path):
    with pytest.raises(FileNotFoundError):
        cgb.adapter_kg_sqlite(tmp_path / "nonexistent.db")


# ─────────────────────────────────────────────────────────────────────────────
# Auto-detect
# ─────────────────────────────────────────────────────────────────────────────


def test_auto_detect_acm(cgb, tmp_path):
    assert cgb.auto_detect_adapter(tmp_path / "x.acm") == "acm"


def test_auto_detect_db(cgb, tmp_path):
    assert cgb.auto_detect_adapter(tmp_path / "x.db") == "kg-sqlite"


def test_auto_detect_jsonl(cgb, tmp_path):
    assert cgb.auto_detect_adapter(tmp_path / "x.jsonl") == "jsonl-graph"


def test_auto_detect_unknown_falls_back(cgb, tmp_path):
    assert cgb.auto_detect_adapter(tmp_path / "x.xyz") == "jsonl-graph"


# ─────────────────────────────────────────────────────────────────────────────
# Formatters
# ─────────────────────────────────────────────────────────────────────────────


def test_format_markdown_includes_header_and_nodes(cgb):
    graph = _simple_graph()
    selected = ["a", "b"]
    stats = {"nodes_selected": 2, "nodes_total": 4, "tokens_used": 10, "tokens_budget": 100, "coverage_pct": 50.0}
    scores = {"a": 0.9, "b": 0.5}
    out = cgb.format_markdown(graph, selected, stats, scores, "alpha")
    assert "# Context Subgraph" in out
    assert "## Selected Nodes" in out
    assert "alpha" in out
    assert "Selected 2/4 nodes" in out


def test_format_json_parseable(cgb):
    graph = _simple_graph()
    selected = ["a"]
    stats = {"nodes_selected": 1, "nodes_total": 4, "tokens_used": 5, "tokens_budget": 100, "coverage_pct": 25.0}
    scores = {"a": 0.9}
    out = cgb.format_json(graph, selected, stats, scores, "alpha")
    parsed = json.loads(out)
    assert parsed["query"] == "alpha"
    assert len(parsed["nodes"]) == 1


def test_format_jsonl_one_node_per_line(cgb):
    graph = _simple_graph()
    selected = ["a", "b"]
    stats = {"nodes_selected": 2, "nodes_total": 4, "tokens_used": 10, "tokens_budget": 100, "coverage_pct": 50.0}
    scores = {"a": 0.9, "b": 0.5}
    out = cgb.format_jsonl(graph, selected, stats, scores, "alpha")
    lines = [ln for ln in out.split("\n") if ln.strip()]
    # 1 meta + 2 nodes
    assert len(lines) == 3
    for line in lines:
        json.loads(line)  # all parseable


# ─────────────────────────────────────────────────────────────────────────────
# CLI smoke (subprocess)
# ─────────────────────────────────────────────────────────────────────────────


def _run_cli(*args) -> tuple[int, str, str]:
    proc = subprocess.run(
        [sys.executable, str(SCRIPT), *args],
        capture_output=True,
        text=True,
        timeout=30,
    )
    return proc.returncode, proc.stdout, proc.stderr


def test_cli_help_exits_zero():
    rc, out, _ = _run_cli("--help")
    assert rc == 0
    assert "context-greedy-budget" in out
    assert "SPEC-189" in out


def test_cli_acm_smoke():
    rc, out, err = _run_cli(
        str(FIXTURES / "sample.acm"),
        "authentication user",
        "--budget",
        "300",
    )
    assert rc == 0, f"stderr: {err}"
    assert "Context Subgraph" in out
    # Auth-related node should be selected
    assert "AuthenticationService" in out or "Authentication Service" in out or "UserRepository" in out


def test_cli_json_format():
    rc, out, _ = _run_cli(
        str(FIXTURES / "sample-graph.json"),
        "auth jwt",
        "--budget",
        "200",
        "--format",
        "json",
    )
    assert rc == 0
    parsed = json.loads(out)
    assert "stats" in parsed
    assert "nodes" in parsed
    assert parsed["query"] == "auth jwt"


def test_cli_input_not_found_exits_3(tmp_path):
    rc, _, err = _run_cli(str(tmp_path / "nope.acm"), "anything")
    assert rc == 3
    assert "not found" in err.lower()


def test_cli_explain_writes_table_to_stderr():
    rc, out, err = _run_cli(
        str(FIXTURES / "sample.acm"),
        "authentication user",
        "--budget",
        "500",
        "--explain",
    )
    assert rc == 0
    # explain output goes to stderr
    assert "id" in err
    assert "score" in err
    assert "structural" in err
    assert "semantic" in err


def test_cli_deterministic_same_input_same_output():
    args = [str(FIXTURES / "sample.acm"), "authentication", "--budget", "400"]
    rc1, out1, _ = _run_cli(*args)
    rc2, out2, _ = _run_cli(*args)
    assert rc1 == 0 and rc2 == 0
    assert out1 == out2


# ─────────────────────────────────────────────────────────────────────────────
# Anti-vendor-lock-in checks
# ─────────────────────────────────────────────────────────────────────────────


def test_no_required_external_deps_in_imports():
    """Verify the script only imports stdlib + optional tiktoken under try/except."""
    src = SCRIPT.read_text(encoding="utf-8")
    forbidden_top_level = ["import slurp", "import networkx", "import numpy", "import sklearn"]
    for tok in forbidden_top_level:
        assert tok not in src, f"Forbidden top-level import found: {tok}"
    # tiktoken must be guarded
    assert "import tiktoken" in src
    # find the tiktoken import line and check it's inside a try block
    lines = src.splitlines()
    for i, line in enumerate(lines):
        if "import tiktoken" in line:
            # walk back up to find a try statement before any def at column 0
            found_try = False
            for j in range(i - 1, max(i - 8, -1), -1):
                if lines[j].strip().startswith("try"):
                    found_try = True
                    break
                if lines[j].strip().startswith("def ") and not lines[j].startswith(" "):
                    break
            assert found_try, "tiktoken must be imported inside a try/except"
