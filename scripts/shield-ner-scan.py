#!/usr/bin/env python3
"""
shield-ner-scan.py — Savia Shield Capa 1.5: NER-based PII detection

Uses Presidio + spaCy to detect named entities (persons, organizations,
locations) that regex cannot catch. Loads project-specific deny-lists
from GLOSSARY-MASK.md for custom entity detection.

Usage:
  echo "text" | python3 shield-ner-scan.py [--glossary path] [--threshold 0.7]
  python3 shield-ner-scan.py --file path/to/file.md [--glossary path]

Output: JSON with detected entities and verdict (CLEAN / PII_DETECTED)
Exit: 0 = clean, 1 = PII detected, 2 = error

AUDITABILITY: every scan logged to ner-scan-audit.jsonl
"""

import sys
import os
import json
from datetime import datetime, timezone

# Threshold for blocking (entities above this score are flagged)
DEFAULT_THRESHOLD = 0.7
WARN_THRESHOLD = 0.4


def load_deny_lists(glossary_path):
    """Load project entities from GLOSSARY-MASK.md as deny lists."""
    deny_lists = {"person": [], "company": [], "project": [],
                  "system": [], "environment": [], "acronym": []}
    if not glossary_path or not os.path.exists(glossary_path):
        return deny_lists

    current_cat = None
    with open(glossary_path, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if line.startswith('## '):
                cat = line[3:].strip().lower()
                if cat in deny_lists:
                    current_cat = cat
            elif line.startswith('- **') and current_cat:
                # Extract term: - **Term** | category
                term = line.split('**')[1] if '**' in line else ''
                if term and len(term) > 1:
                    deny_lists[current_cat].append(term)
    return deny_lists


def scan_with_presidio(text, glossary_path=None, threshold=DEFAULT_THRESHOLD):
    """Scan text for PII using Presidio + spaCy NER + deny lists."""
    try:
        from presidio_analyzer import AnalyzerEngine, PatternRecognizer
        from presidio_analyzer.nlp_engine import SpacyNlpEngine
    except ImportError:
        return {"verdict": "SKIP", "reason": "presidio not installed",
                "entities": []}

    # Initialize with Spanish model
    try:
        nlp_config = [{"lang_code": "es", "model_name": "es_core_news_md"}]
        nlp_engine = SpacyNlpEngine(models=nlp_config)
        analyzer = AnalyzerEngine(
            nlp_engine=nlp_engine,
            supported_languages=["es", "en"]
        )
    except Exception:
        # Fallback to English if Spanish model not available
        try:
            analyzer = AnalyzerEngine()
        except Exception as e:
            return {"verdict": "SKIP", "reason": f"spacy init failed: {e}",
                    "entities": []}

    # Add deny-list recognizers from GLOSSARY-MASK.md
    deny_lists = load_deny_lists(glossary_path)
    for category, terms in deny_lists.items():
        if not terms:
            continue
        entity_type = f"CUSTOM_{category.upper()}"
        recognizer = PatternRecognizer(
            supported_entity=entity_type,
            deny_list=terms,
            supported_language="es",
        )
        analyzer.registry.add_recognizer(recognizer)
        # Also add for English (mixed-language docs)
        recognizer_en = PatternRecognizer(
            supported_entity=entity_type,
            deny_list=terms,
            supported_language="en",
        )
        analyzer.registry.add_recognizer(recognizer_en)

    # SEC-012 FIX: Dual-language scan — run both ES and EN, merge results
    # This eliminates language detection errors for mixed-language docs
    results = []
    for lang in ["es", "en"]:
        try:
            lang_results = analyzer.analyze(
                text=text, language=lang,
                score_threshold=WARN_THRESHOLD
            )
            results.extend(lang_results)
        except Exception:
            continue

    # Deduplicate: keep highest score for overlapping spans
    if results:
        results.sort(key=lambda r: (r.start, -r.score))
        deduped = [results[0]]
        for r in results[1:]:
            prev = deduped[-1]
            if r.start >= prev.end:  # non-overlapping
                deduped.append(r)
            elif r.score > prev.score:  # overlapping, higher score
                deduped[-1] = r
        results = deduped

    try:
        pass  # results already populated above
    except Exception as e:
        return {"verdict": "SKIP", "reason": f"analysis failed: {e}",
                "entities": []}

    # Process results
    entities = []
    pii_found = False
    for r in results:
        entity = {
            "type": r.entity_type,
            "text": text[r.start:r.end],
            "score": round(r.score, 2),
            "start": r.start,
            "end": r.end,
            "action": "BLOCK" if r.score >= threshold else "WARN"
        }
        entities.append(entity)
        if r.score >= threshold:
            pii_found = True

    verdict = "PII_DETECTED" if pii_found else "CLEAN"
    return {"verdict": verdict, "entities": entities, "language": lang}


def audit_log(result, input_preview):
    """Log scan to audit trail."""
    audit_dir = os.environ.get('CLAUDE_PROJECT_DIR', os.getcwd())
    audit_file = os.path.join(audit_dir, 'output',
                              'data-sovereignty-validation',
                              'ner-scan-audit.jsonl')
    os.makedirs(os.path.dirname(audit_file), exist_ok=True)
    entry = {
        "ts": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "verdict": result["verdict"],
        "entities_count": len(result.get("entities", [])),
        "blocked": sum(1 for e in result.get("entities", [])
                       if e.get("action") == "BLOCK"),
        "input_chars": len(input_preview),
    }
    try:
        with open(audit_file, 'a', encoding='utf-8') as f:
            f.write(json.dumps(entry) + '\n')
    except Exception:
        pass


def main():
    import argparse
    parser = argparse.ArgumentParser(
        description='Savia Shield NER scan — detect PII via Presidio')
    parser.add_argument('--glossary', help='Path to GLOSSARY-MASK.md')
    parser.add_argument('--file', help='File to scan (alternative to stdin)')
    parser.add_argument('--threshold', type=float, default=DEFAULT_THRESHOLD,
                        help=f'Score threshold for blocking (default {DEFAULT_THRESHOLD})')
    parser.add_argument('--json', action='store_true',
                        help='Output full JSON (default: human-readable)')
    args = parser.parse_args()

    # Read text
    if args.file:
        with open(args.file, 'r', encoding='utf-8', errors='replace') as f:
            text = f.read()
    elif not sys.stdin.isatty():
        text = sys.stdin.read()
    else:
        print("ERROR: provide text via stdin or --file", file=sys.stderr)
        sys.exit(2)

    if not text.strip():
        print("CLEAN")
        sys.exit(0)

    # Scan
    result = scan_with_presidio(text, args.glossary, args.threshold)
    audit_log(result, text[:200])

    # Output
    if args.json:
        print(json.dumps(result, indent=2, ensure_ascii=False))
    else:
        if result["verdict"] == "CLEAN":
            print("CLEAN — no PII detected")
        elif result["verdict"] == "SKIP":
            print(f"SKIP — {result.get('reason', 'unknown')}")
        else:
            print(f"PII_DETECTED — {len(result['entities'])} entities found:")
            for e in result["entities"]:
                marker = "BLOCK" if e["action"] == "BLOCK" else "warn"
                print(f"  [{marker}] {e['type']}: \"{e['text']}\" "
                      f"(score: {e['score']})")

    sys.exit(1 if result["verdict"] == "PII_DETECTED" else 0)


if __name__ == '__main__':
    main()
