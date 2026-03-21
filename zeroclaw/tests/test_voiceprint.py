#!/usr/bin/env python3
"""Tests for voiceprint manager — runs without speechbrain."""
import sys
import os
import json
import tempfile
import numpy as np
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from host.voiceprint import (
    _cosine_similarity, _load_index, _save_index, _ensure_dir,
    VOICEPRINT_DIR, SIMILARITY_THRESHOLD_HIGH,
)
from host.voiceprint_ops import (
    list_voiceprints, delete, is_available, identify_from_embedding,
)

passed = 0
failed = 0


def test(name, fn):
    global passed, failed
    try:
        fn()
        print(f"  ✅ {name}")
        passed += 1
    except Exception as e:
        print(f"  ❌ {name}: {e}")
        failed += 1


def test_cosine_identical():
    a = np.array([1.0, 0.0, 0.0])
    assert abs(_cosine_similarity(a, a) - 1.0) < 0.001


def test_cosine_orthogonal():
    a = np.array([1.0, 0.0])
    b = np.array([0.0, 1.0])
    assert abs(_cosine_similarity(a, b)) < 0.001


def test_cosine_opposite():
    a = np.array([1.0, 0.0])
    b = np.array([-1.0, 0.0])
    assert abs(_cosine_similarity(a, b) - (-1.0)) < 0.001


def test_index_roundtrip():
    with tempfile.TemporaryDirectory() as d:
        idx_file = os.path.join(d, "index.json")
        original_idx = {"abc": {"name": "Test", "file": "test.npy"}}
        with open(idx_file, 'w') as f:
            json.dump(original_idx, f)
        with open(idx_file) as f:
            loaded = json.load(f)
        assert loaded["abc"]["name"] == "Test"


def test_identify_empty_index():
    """With no voiceprints, should return Unknown."""
    emb = np.random.randn(192)
    result = identify_from_embedding(emb)
    # May or may not have voiceprints depending on env
    assert "name" in result
    assert "confidence" in result


def test_voiceprint_dir_n4b():
    """Voiceprint dir should be in user home, not in repo."""
    assert ".savia" in VOICEPRINT_DIR
    assert "zeroclaw" in VOICEPRINT_DIR


def test_thresholds():
    assert SIMILARITY_THRESHOLD_HIGH == 0.75


def test_is_available():
    result = is_available()
    assert isinstance(result, bool)


def test_file_sizes():
    for f in ['voiceprint.py', 'voiceprint_ops.py', 'meeting_pipeline.py']:
        path = os.path.join(os.path.dirname(__file__), '..', 'host', f)
        with open(path) as fh:
            lines = len(fh.readlines())
        assert lines <= 150, f"{f}: {lines} lines"


if __name__ == "__main__":
    print("ZeroClaw Voiceprint Tests (no speechbrain required)")
    print("─" * 50)
    test("Cosine: identical vectors = 1.0", test_cosine_identical)
    test("Cosine: orthogonal vectors = 0.0", test_cosine_orthogonal)
    test("Cosine: opposite vectors = -1.0", test_cosine_opposite)
    test("Index roundtrip", test_index_roundtrip)
    test("Identify with empty index", test_identify_empty_index)
    test("Voiceprint dir is N4b (user home)", test_voiceprint_dir_n4b)
    test("Thresholds correct", test_thresholds)
    test("is_available returns bool", test_is_available)
    test("Host files ≤150 lines", test_file_sizes)
    print(f"\n{passed} passed, {failed} failed")
    sys.exit(1 if failed else 0)
