#!/usr/bin/env python3
"""
shield-ner-daemon.py — Savia Shield NER daemon (persistent spaCy in RAM)

Loads Presidio + spaCy ONCE and serves NER scans via HTTP on localhost.
Reduces NER latency from ~15s (cold start) to ~100ms (warm).

Usage:
  python3 scripts/shield-ner-daemon.py [--port 8444]
  Then: curl -X POST http://localhost:8444/scan -d '{"text":"Juan Garcia"}'

Response: {"verdict":"PII_DETECTED","entities":[...],"latency_ms":85}
"""

import http.server
import json
import os
import sys
import time
from pathlib import Path

DEFAULT_PORT = 8444
PROJECT_DIR = os.environ.get("CLAUDE_PROJECT_DIR",
    str(Path(__file__).resolve().parent.parent))

# Globals — loaded once at startup
analyzer = None
glossary_loaded = False


def init_presidio():
    """Load Presidio + spaCy model once at startup."""
    global analyzer, glossary_loaded
    from presidio_analyzer import AnalyzerEngine, PatternRecognizer
    from presidio_analyzer.nlp_engine import SpacyNlpEngine

    print("Loading spaCy es_core_news_md...", file=sys.stderr)
    t0 = time.time()
    nlp_config = [{"lang_code": "es", "model_name": "es_core_news_md"}]
    nlp_engine = SpacyNlpEngine(models=nlp_config)
    analyzer = AnalyzerEngine(nlp_engine=nlp_engine,
                               supported_languages=["es", "en"])
    print(f"  spaCy loaded in {time.time()-t0:.1f}s", file=sys.stderr)

    # Load deny-lists from GLOSSARY-MASK.md
    for g in Path(PROJECT_DIR).glob("projects/*/GLOSSARY-MASK.md"):
        load_glossary_denylists(str(g))
        break

    glossary_loaded = True
    print(f"  Analyzer ready, {len(analyzer.registry.recognizers)} "
          f"recognizers", file=sys.stderr)


def load_glossary_denylists(glossary_path):
    """Load project entities as deny-list recognizers."""
    from presidio_analyzer import PatternRecognizer
    if not os.path.exists(glossary_path):
        return
    current_cat = None
    entities = {}
    with open(glossary_path, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if line.startswith('## '):
                current_cat = line[3:].strip().lower()
                if current_cat not in entities:
                    entities[current_cat] = []
            elif line.startswith('- **') and current_cat:
                term = line.split('**')[1] if '**' in line else ''
                if term and len(term) > 1:
                    entities[current_cat].append(term)

    for cat, terms in entities.items():
        if not terms:
            continue
        entity_type = f"CUSTOM_{cat.upper()}"
        for lang in ["es", "en"]:
            rec = PatternRecognizer(supported_entity=entity_type,
                                    deny_list=terms,
                                    supported_language=lang)
            analyzer.registry.add_recognizer(rec)
    print(f"  Glossary: {sum(len(v) for v in entities.values())} "
          f"deny-list terms", file=sys.stderr)


def scan_text(text, threshold=0.7):
    """Scan text for PII. Returns dict with verdict + entities."""
    t0 = time.time()
    results = []
    for lang in ["es", "en"]:
        try:
            r = analyzer.analyze(text=text, language=lang,
                                  score_threshold=0.4)
            results.extend(r)
        except Exception:
            continue

    # Deduplicate overlapping spans
    if results:
        results.sort(key=lambda r: (r.start, -r.score))
        deduped = [results[0]]
        for r in results[1:]:
            if r.start >= deduped[-1].end:
                deduped.append(r)
            elif r.score > deduped[-1].score:
                deduped[-1] = r
        results = deduped

    entities = []
    pii_found = False
    for r in results:
        action = "BLOCK" if r.score >= threshold else "WARN"
        entities.append({
            "type": r.entity_type,
            "text": text[r.start:r.end],
            "score": round(r.score, 2),
            "action": action
        })
        if r.score >= threshold:
            pii_found = True

    latency = int((time.time() - t0) * 1000)
    return {
        "verdict": "PII_DETECTED" if pii_found else "CLEAN",
        "entities": entities,
        "latency_ms": latency
    }


class NERHandler(http.server.BaseHTTPRequestHandler):

    def do_POST(self):
        if self.path == "/scan":
            length = int(self.headers.get('Content-Length', 0))
            body = json.loads(self.rfile.read(length))
            text = body.get("text", "")
            threshold = body.get("threshold", 0.7)
            result = scan_text(text, threshold)
            resp = json.dumps(result).encode('utf-8')
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(resp)))
            self.end_headers()
            self.wfile.write(resp)
        else:
            self.send_response(404)
            self.end_headers()

    def do_GET(self):
        if self.path == "/health":
            resp = json.dumps({"status": "ok",
                               "model": "es_core_news_md"}).encode()
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(resp)
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, format, *args):
        pass


def main():
    import argparse
    parser = argparse.ArgumentParser(
        description='Savia Shield NER daemon')
    parser.add_argument('--port', type=int, default=DEFAULT_PORT)
    args = parser.parse_args()

    init_presidio()

    print(f"NER daemon on port {args.port}", file=sys.stderr)
    server = http.server.HTTPServer(('127.0.0.1', args.port), NERHandler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nNER daemon stopped.", file=sys.stderr)


if __name__ == '__main__':
    main()
