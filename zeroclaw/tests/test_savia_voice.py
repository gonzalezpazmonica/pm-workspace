#!/usr/bin/env python3
"""Tests for savia-voice modules — runs without audio hardware or LLM."""
import os
import sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'savia-voice'))

passed = 0
failed = 0


def test(name, fn):
    global passed, failed
    try:
        fn()
        print(f"  OK  {name}")
        passed += 1
    except Exception as e:
        print(f"  FAIL {name}: {e}")
        failed += 1


# ── text_utils ───────────────────────────────────────────────────────────

def test_split_sentences_basic():
    from text_utils import split_sentences
    result = split_sentences("Hola. Que tal. Bien.")
    assert len(result) == 3, f"Expected 3, got {len(result)}: {result}"


def test_split_sentences_no_period():
    from text_utils import split_sentences
    result = split_sentences("Sin punto final")
    assert len(result) == 1
    assert result[0] == "Sin punto final"


def test_split_sentences_exclamation():
    from text_utils import split_sentences
    result = split_sentences("Hola! Que tal? Bien.")
    assert len(result) == 3


def test_split_sentences_empty():
    from text_utils import split_sentences
    result = split_sentences("")
    assert result == []


def test_voice_chunks_short():
    from text_utils import split_into_voice_chunks
    result = split_into_voice_chunks("Frase corta.")
    assert len(result) == 1


def test_voice_chunks_long():
    from text_utils import split_into_voice_chunks
    long = ". ".join(["Frase numero " + str(i) for i in range(20)])
    result = split_into_voice_chunks(long, max_chars=100)
    assert len(result) > 1
    assert all(len(c) <= 200 for c in result)  # with tolerance


def test_clean_for_voice_markdown():
    from text_utils import clean_for_voice
    result = clean_for_voice("**Hola** mundo `code` aqui")
    assert "**" not in result
    assert "`" not in result
    assert "Hola" in result


def test_clean_for_voice_code_block():
    from text_utils import clean_for_voice
    result = clean_for_voice("Antes\n```python\nprint('hi')\n```\nDespues")
    assert "```" not in result


def test_clean_for_voice_empty():
    from text_utils import clean_for_voice
    assert clean_for_voice("") == ""
    assert clean_for_voice(None) == ""


# ── conversation_model ───────────────────────────────────────────────────

def test_no_overlap_is_process():
    from conversation_model import classify_overlap, OverlapType
    t, a = classify_overlap("Hola Savia", 2.0, False)
    assert t == OverlapType.FOLLOWUP
    assert a == "process"


def test_stop_command_para():
    from conversation_model import classify_overlap, OverlapType
    t, a = classify_overlap("para", 0.5, True)
    assert t == OverlapType.STOP
    assert a == "stop"


def test_stop_command_callate():
    from conversation_model import classify_overlap, OverlapType
    t, a = classify_overlap("cállate", 0.8, True)
    assert t == OverlapType.STOP
    assert a == "stop"


def test_stop_command_stop():
    from conversation_model import classify_overlap, OverlapType
    t, a = classify_overlap("stop", 0.5, True)
    assert t == OverlapType.STOP
    assert a == "stop"


def test_backchannel_si():
    from conversation_model import classify_overlap, OverlapType
    t, a = classify_overlap("sí", 0.5, True)
    assert t == OverlapType.BACKCHANNEL
    assert a == "ignore"


def test_backchannel_claro():
    from conversation_model import classify_overlap, OverlapType
    t, a = classify_overlap("claro claro", 1.0, True)
    assert t == OverlapType.BACKCHANNEL
    assert a == "ignore"


def test_backchannel_long_is_not_backchannel():
    from conversation_model import classify_overlap, OverlapType
    # >2s duration → not backchannel even with backchannel words
    t, a = classify_overlap("sí sí", 3.0, True)
    assert t == OverlapType.COLLABORATIVE
    assert a == "listen"


def test_collaborative_overlap():
    from conversation_model import classify_overlap, OverlapType
    t, a = classify_overlap("pero espera que tengo una idea", 3.0, True)
    assert t == OverlapType.COLLABORATIVE
    assert a == "listen"


def test_unknown_overlap_is_collaborative():
    from conversation_model import classify_overlap, OverlapType
    t, a = classify_overlap("algo completamente diferente", 2.5, True)
    assert t == OverlapType.COLLABORATIVE
    assert a == "listen"


# ── config ───────────────────────────────────────────────────────────────

def test_config_defaults():
    from config import DEFAULTS
    assert DEFAULTS["audio"]["sample_rate"] == 16000
    assert DEFAULTS["vad"]["threshold"] == 0.5
    assert DEFAULTS["stt"]["model"] == "tiny"
    assert DEFAULTS["tts"]["engine"] == "edge-tts"
    assert DEFAULTS["claude"]["model"] == "sonnet"


def test_deep_merge():
    from config import deep_merge
    base = {"a": {"x": 1, "y": 2}, "b": 3}
    over = {"a": {"y": 99}, "c": 4}
    result = deep_merge(base, over)
    assert result["a"]["x"] == 1
    assert result["a"]["y"] == 99
    assert result["b"] == 3
    assert result["c"] == 4


def test_deep_merge_no_mutation():
    from config import deep_merge
    base = {"a": {"x": 1}}
    over = {"a": {"y": 2}}
    deep_merge(base, over)
    assert "y" not in base["a"]


def test_load_config_returns_all_sections():
    from config import load_config
    cfg = load_config()
    for section in ["audio", "vad", "stt", "tts", "claude"]:
        assert section in cfg, f"Missing section: {section}"


# ── tts_cache ────────────────────────────────────────────────────────────

def test_cache_phrases_not_empty():
    from tts_cache import CACHE_PHRASES, FILLERS, STALLS
    assert len(CACHE_PHRASES) >= 10
    assert len(FILLERS) >= 3
    assert len(STALLS) >= 3


def test_cache_key_normalization():
    from tts_cache import TTSCache
    c = TTSCache()
    assert c._key("Hola.") == "hola"
    assert c._key("  Vale...  ") == "vale"
    assert c._key("Pues mira…") == "pues mira"


def test_cache_categorize_question():
    from tts_cache import TTSCache, QUESTION_MAP
    c = TTSCache()
    cat = c._categorize(QUESTION_MAP, "qué proyectos tengo", "inicio")
    assert cat == "inicio"


def test_cache_categorize_reflexion():
    from tts_cache import TTSCache, QUESTION_MAP
    c = TTSCache()
    cat = c._categorize(QUESTION_MAP, "cómo funciona esto", "inicio")
    assert cat == "reflexion"


def test_cache_categorize_default():
    from tts_cache import TTSCache, QUESTION_MAP
    c = TTSCache()
    cat = c._categorize(QUESTION_MAP, "zzz raro input", "inicio")
    assert cat == "inicio"


def test_cache_get_empty():
    from tts_cache import TTSCache
    c = TTSCache()
    assert c.get("cualquier cosa") is None


def test_filler_categories_match_question_map():
    from tts_cache import FILLERS, QUESTION_MAP
    cats_used = set(QUESTION_MAP.values())
    cats_available = set(FILLERS.keys())
    for cat in cats_used:
        assert cat in cats_available, f"QUESTION_MAP uses '{cat}' not in FILLERS"


def test_stall_categories_match_stall_map():
    from tts_cache import STALLS, STALL_MAP
    cats_used = set(STALL_MAP.values())
    cats_available = set(STALLS.keys())
    for cat in cats_used:
        assert cat in cats_available, f"STALL_MAP uses '{cat}' not in STALLS"


# ── file sizes ───────────────────────────────────────────────────────────

def test_file_sizes():
    base = os.path.join(os.path.dirname(__file__), '..', 'savia-voice')
    for name in os.listdir(base):
        if name.endswith('.py'):
            path = os.path.join(base, name)
            with open(path) as f:
                lines = len(f.readlines())
            assert lines <= 250, f"{name} has {lines} lines (max 250)"


if __name__ == "__main__":
    print("Savia Voice Unit Tests (no hardware required)")
    print("-" * 50)

    print("\n  text_utils:")
    test("split_sentences basic", test_split_sentences_basic)
    test("split_sentences no period", test_split_sentences_no_period)
    test("split_sentences exclamation", test_split_sentences_exclamation)
    test("split_sentences empty", test_split_sentences_empty)
    test("voice_chunks short", test_voice_chunks_short)
    test("voice_chunks long", test_voice_chunks_long)
    test("clean_for_voice markdown", test_clean_for_voice_markdown)
    test("clean_for_voice code block", test_clean_for_voice_code_block)
    test("clean_for_voice empty", test_clean_for_voice_empty)

    print("\n  conversation_model:")
    test("no overlap → process", test_no_overlap_is_process)
    test("stop: para", test_stop_command_para)
    test("stop: cállate", test_stop_command_callate)
    test("stop: stop", test_stop_command_stop)
    test("backchannel: sí", test_backchannel_si)
    test("backchannel: claro claro", test_backchannel_claro)
    test("long backchannel → collaborative", test_backchannel_long_is_not_backchannel)
    test("collaborative overlap", test_collaborative_overlap)
    test("unknown → collaborative", test_unknown_overlap_is_collaborative)

    print("\n  config:")
    test("defaults present", test_config_defaults)
    test("deep_merge works", test_deep_merge)
    test("deep_merge no mutation", test_deep_merge_no_mutation)
    test("load_config all sections", test_load_config_returns_all_sections)

    print("\n  tts_cache:")
    test("cache phrases not empty", test_cache_phrases_not_empty)
    test("key normalization", test_cache_key_normalization)
    test("categorize question", test_cache_categorize_question)
    test("categorize reflexion", test_cache_categorize_reflexion)
    test("categorize default", test_cache_categorize_default)
    test("get empty cache", test_cache_get_empty)
    test("filler categories consistent", test_filler_categories_match_question_map)
    test("stall categories consistent", test_stall_categories_match_stall_map)

    print("\n  file sizes:")
    test("all files <= 250 lines", test_file_sizes)

    print(f"\n{'=' * 50}")
    print(f"  {passed} passed, {failed} failed")
    sys.exit(1 if failed else 0)
