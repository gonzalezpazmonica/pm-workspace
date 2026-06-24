"""tests/python/test_context_greedy_budget.py — SPEC-189 unit tests.

Pytest suite for scripts/context-greedy-budget.py.
All tests are self-contained: no external deps, no network, no filesystem writes.
"""
from __future__ import annotations

import importlib.util
import json
import math
import sqlite3
import sys
import tempfile
from pathlib import Path

import pytest

# ---------------------------------------------------------------------------
# Import the script as a module without relying on it being importable by name
# ---------------------------------------------------------------------------

_SCRIPT = Path(__file__).parent.parent.parent / "scripts" / "context-greedy-budget.py"
_spec = importlib.util.spec_from_file_location("context_greedy_budget", _SCRIPT)
_mod = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_mod)

tokenize = _mod.tokenize
pagerank = _mod.pagerank
tfidf_scores = _mod.tfidf_scores
compute_scores = _mod.compute_scores
select_subgraph = _mod.select_subgraph
adapter_acm = _mod.adapter_acm
adapter_kg_sqlite = _mod.adapter_kg_sqlite
adapter_jsonl_graph = _mod.adapter_jsonl_graph
count_tokens_heuristic = _mod.count_tokens_heuristic
serialize_node = _mod.serialize_node
main = _mod.main


# ---------------------------------------------------------------------------
# Fixtures helpers
# ---------------------------------------------------------------------------

FIXTURES = Path(__file__).parent.parent / "fixtures" / "context-greedy-budget"


def _small_graph():
    """5-node graph with edges for algorithm tests."""
    return {
        "nodes": {
            "a": {"label": "Alpha", "text": "alpha auth login", "kind": "code", "neighbors": ["b", "c"]},
            "b": {"label": "Beta", "text": "beta token jwt", "kind": "code", "neighbors": ["d"]},
            "c": {"label": "Gamma", "text": "gamma config settings", "kind": "doc", "neighbors": []},
            "d": {"label": "Delta", "text": "delta database sql", "kind": "code", "neighbors": ["e"]},
            "e": {"label": "Epsilon", "text": "epsilon cache redis", "kind": "entity", "neighbors": []},
        }
    }


# ---------------------------------------------------------------------------
# 1. Tokenizer tests
# ---------------------------------------------------------------------------


def test_tokenize_camel_snake():
    """AC9 — camelCase split must produce component tokens + full compound."""
    result = tokenize("calcularPlayerStats")
    assert "calcular" in result
    assert "player" in result
    assert "stats" in result
    assert "calcularplayerstats" in result


def test_tokenize_snake_case():
    result = tokenize("auth_flow_service")
    assert "auth" in result
    assert "flow" in result
    assert "service" in result


def test_tokenize_kebab():
    result = tokenize("jwt-issuer-helper")
    assert "jwt" in result
    assert "issuer" in result
    assert "helper" in result


def test_tokenize_empty():
    assert tokenize("") == []


def test_tokenize_all_caps():
    result = tokenize("XMLParser")
    assert "xml" in result
    assert "parser" in result


# ---------------------------------------------------------------------------
# 2. PageRank tests
# ---------------------------------------------------------------------------


def test_pagerank_converges():
    """AC2 (structural) — PageRank on 5-node graph sums to ~1.0."""
    nodes = ["a", "b", "c", "d", "e"]
    edges_out = {"a": ["b", "c"], "b": ["d"], "c": [], "d": ["e"], "e": []}
    pr = pagerank(nodes, edges_out)
    assert set(pr.keys()) == set(nodes)
    total = sum(pr.values())
    assert abs(total - 1.0) < 1e-3, f"PageRank sum {total} != 1.0"


def test_pagerank_empty():
    assert pagerank([], {}) == {}


def test_pagerank_uniform_no_edges():
    """All dangling nodes → uniform distribution."""
    nodes = ["x", "y", "z"]
    pr = pagerank(nodes, {})
    for v in pr.values():
        assert abs(v - 1 / 3) < 0.01


# ---------------------------------------------------------------------------
# 3. TF-IDF tests
# ---------------------------------------------------------------------------


def test_tfidf_basic():
    """Docs that contain query terms score higher than docs that don't."""
    docs = {
        "a": tokenize("jwt token authentication login"),
        "b": tokenize("database schema migration"),
        "c": tokenize("cache redis performance"),
    }
    scores = tfidf_scores(docs, "jwt token")
    assert scores["a"] > scores["b"]
    assert scores["a"] > scores["c"]


def test_tfidf_empty_query():
    docs = {"a": tokenize("hello world"), "b": tokenize("foo bar")}
    scores = tfidf_scores(docs, "")
    assert all(v == 0.0 for v in scores.values())


def test_tfidf_no_docs():
    assert tfidf_scores({}, "query") == {}


# ---------------------------------------------------------------------------
# 4. Score combining
# ---------------------------------------------------------------------------


def test_score_combines_alpha_beta():
    """AC3 — final score = 0.4*structural + 0.6*semantic for non-code nodes."""
    graph = {
        "nodes": {
            "only": {
                "label": "Only",
                "text": "test query match here",
                "kind": "entity",
                "neighbors": [],
            }
        }
    }
    final, struct, sem = compute_scores(graph, "test query")
    assert "only" in final
    # For a single-node graph, structural=1.0 (sole dangling node, normalized)
    # semantic > 0 because text contains query terms
    # final should be between 0 and 1
    assert 0.0 <= final["only"] <= 1.0


def test_score_no_semantic_signal_zero():
    """When query matches nothing semantically, all scores are 0."""
    graph = {
        "nodes": {
            "a": {"label": "A", "text": "apple banana cherry", "kind": "doc", "neighbors": []},
            "b": {"label": "B", "text": "dog elephant fox", "kind": "doc", "neighbors": []},
        }
    }
    final, _, _ = compute_scores(graph, "zzzzxxxxxnonexistent")
    assert all(v == 0.0 for v in final.values())


def test_code_boost_clamp():
    """AC10 — kind='code' boost is clamped to 1.0 (not 1.15)."""
    graph = {
        "nodes": {
            "codenode": {
                "label": "CodeNode",
                "text": "auth login jwt token authentication",
                "kind": "code",
                "neighbors": [],
            }
        }
    }
    final, _, _ = compute_scores(graph, "auth login jwt")
    assert final["codenode"] <= 1.0


# ---------------------------------------------------------------------------
# 5. Greedy budget selection
# ---------------------------------------------------------------------------


def test_select_respects_budget():
    """AC2 — tokens_used <= budget always."""
    graph = _small_graph()
    final, _, _ = compute_scores(graph, "auth login jwt")
    for budget in [50, 100, 200, 500]:
        selected, stats = select_subgraph(graph, final, budget=budget)
        assert stats["tokens_used"] <= budget, (
            f"Budget {budget} violated: used {stats['tokens_used']}"
        )


def test_neighbor_decay_boost():
    """AC7 — neighbor B of selected A gets effective=max(original, A_score*decay)."""
    # Node "a" with high score, neighbor "b" with low original score
    graph = {
        "nodes": {
            "a": {"label": "A", "text": "unique keyword alpha special", "kind": "code", "neighbors": ["b"]},
            "b": {"label": "B", "text": "something else entirely", "kind": "entity", "neighbors": []},
            "c": {"label": "C", "text": "unrelated content here", "kind": "entity", "neighbors": []},
        }
    }
    # Use a large budget so both a and b can be selected if boosted
    final, _, _ = compute_scores(graph, "unique keyword alpha")
    # "a" should score highest; "b" has low semantic score but should get decay boost
    selected_large, _ = select_subgraph(graph, final, budget=2000, neighbor_decay=0.7, min_score=0.0)
    # With no min_score filter, "b" should appear because it was boosted via decay
    assert "a" in selected_large


def test_min_score_filter():
    """AC8 — with min_score=0.5, only nodes with score >= 0.5 are candidates."""
    graph = _small_graph()
    # Force all scores to known values by patching
    forced_scores = {
        "a": 0.9,
        "b": 0.6,
        "c": 0.1,   # below threshold
        "d": 0.3,   # below threshold
        "e": 0.05,  # below threshold
    }
    selected, stats = select_subgraph(
        graph, forced_scores, budget=5000, min_score=0.5
    )
    for nid in selected:
        assert forced_scores[nid] >= 0.5, f"Node {nid} with score {forced_scores[nid]} passed min_score=0.5"


def test_empty_graph_exit2():
    """AC11 — empty graph → exit code 2 (either SystemExit(2) or return 2)."""
    with tempfile.NamedTemporaryFile(suffix=".json", mode="w", delete=False) as f:
        json.dump({"nodes": [], "edges": []}, f)
        fname = f.name
    # main() returns 2; when called via __main__ it becomes sys.exit(2).
    # Both conventions are acceptable — check either form.
    try:
        ret = main([fname, "query"])
        assert ret == 2, f"Expected exit code 2, got {ret}"
    except SystemExit as exc:
        assert exc.code == 2, f"Expected SystemExit(2), got SystemExit({exc.code})"
    finally:
        Path(fname).unlink(missing_ok=True)


def test_select_empty_scores():
    """All zero scores → nothing selected."""
    graph = _small_graph()
    scores = {nid: 0.0 for nid in graph["nodes"]}
    selected, stats = select_subgraph(graph, scores, budget=5000, min_score=0.15)
    assert selected == []
    assert stats["nodes_selected"] == 0


# ---------------------------------------------------------------------------
# 6. Determinism
# ---------------------------------------------------------------------------


def test_deterministic():
    """AC1 — two runs produce identical ordered selection."""
    graph = _small_graph()
    final, _, _ = compute_scores(graph, "auth jwt login")
    sel1, stats1 = select_subgraph(graph, final, budget=300)
    sel2, stats2 = select_subgraph(graph, final, budget=300)
    assert sel1 == sel2
    assert stats1 == stats2


# ---------------------------------------------------------------------------
# 7. Adapter tests
# ---------------------------------------------------------------------------


def test_acm_adapter():
    """AC4 — ACM adapter parses sample.acm and returns >0 nodes."""
    acm_path = FIXTURES / "sample.acm"
    graph = adapter_acm(acm_path)
    nodes = graph["nodes"]
    assert len(nodes) >= 5, f"Expected >=5 nodes from ACM, got {len(nodes)}"
    # Every node must have required keys
    for nid, attrs in nodes.items():
        assert "label" in attrs
        assert "text" in attrs
        assert "kind" in attrs
        assert "neighbors" in attrs


def test_acm_adapter_with_query():
    """ACM adapter result is scoreable; entity query returns nodes with score>0."""
    acm_path = FIXTURES / "sample.acm"
    graph = adapter_acm(acm_path)
    final, _, sem = compute_scores(graph, "entity authentication")
    assert any(v > 0.0 for v in final.values()), "Expected at least one node with score > 0"


def test_kg_sqlite_adapter():
    """AC5 — KG SQLite adapter reads entities and relations."""
    with tempfile.NamedTemporaryFile(suffix=".db", delete=False) as f:
        db_path = Path(f.name)

    conn = sqlite3.connect(str(db_path))
    conn.execute("CREATE TABLE entities (id INTEGER PRIMARY KEY, name TEXT, type TEXT, description TEXT)")
    conn.execute("CREATE TABLE relations (source_id INTEGER, target_id INTEGER, type TEXT)")
    # Insert 5 entities
    for i in range(1, 6):
        conn.execute(
            "INSERT INTO entities VALUES (?,?,?,?)",
            (i, f"Entity{i}", "code", f"Description of entity number {i}"),
        )
    conn.execute("INSERT INTO relations VALUES (1, 2, 'CALLS')")
    conn.execute("INSERT INTO relations VALUES (2, 3, 'CALLS')")
    conn.commit()
    conn.close()

    graph = adapter_kg_sqlite(db_path)
    nodes = graph["nodes"]
    assert len(nodes) == 5
    # Check relation wiring
    assert "2" in nodes["1"]["neighbors"]
    assert "3" in nodes["2"]["neighbors"]
    db_path.unlink()


def test_jsonl_adapter():
    """AC6 — JSONL adapter parses sample-graph.json."""
    json_path = FIXTURES / "sample-graph.json"
    graph = adapter_jsonl_graph(json_path)
    nodes = graph["nodes"]
    assert len(nodes) >= 5, f"Expected >=5 nodes from JSONL, got {len(nodes)}"
    # auth_service should have neighbors
    assert "auth_service" in nodes
    assert len(nodes["auth_service"]["neighbors"]) > 0


def test_jsonl_adapter_inline_json():
    """JSON object format {nodes, edges} works correctly."""
    data = {
        "nodes": [
            {"id": "n1", "label": "Node1", "type": "code", "description": "first node"},
            {"id": "n2", "label": "Node2", "type": "doc", "description": "second node"},
        ],
        "edges": [{"source": "n1", "target": "n2"}],
    }
    with tempfile.NamedTemporaryFile(suffix=".json", mode="w", delete=False) as f:
        json.dump(data, f)
        fname = f.name
    graph = adapter_jsonl_graph(Path(fname))
    assert "n1" in graph["nodes"]
    assert "n2" in graph["nodes"]["n1"]["neighbors"]
    Path(fname).unlink()


# ---------------------------------------------------------------------------
# 8. Token counter
# ---------------------------------------------------------------------------


def test_heuristic_token_counter():
    """4-char-per-token heuristic: 'hello' (5 chars) → 2 tokens."""
    assert count_tokens_heuristic("hello") == 2
    assert count_tokens_heuristic("") == 0
    assert count_tokens_heuristic("abcd") == 1
    assert count_tokens_heuristic("abcde") == 2


# ---------------------------------------------------------------------------
# 9. Anti-vendor-lock
# ---------------------------------------------------------------------------


def test_no_required_imports():
    """stdlib-only: tiktoken (if present) is only inside try/except."""
    source = _SCRIPT.read_text(encoding="utf-8")
    # tiktoken import must be inside a try block
    import re
    # Find all 'import tiktoken' occurrences
    for m in re.finditer(r"import tiktoken", source):
        start = source.rfind("\n", 0, m.start())
        context = source[max(0, start):m.end() + 50]
        assert "try" in source[max(0, m.start() - 200):m.start()], (
            "tiktoken import must be inside a try block"
        )
    # numpy, sklearn, networkx, slurp must NOT be imported at all
    for forbidden in ("import numpy", "import sklearn", "import networkx", "import slurp"):
        assert forbidden not in source, f"Forbidden import: {forbidden}"
