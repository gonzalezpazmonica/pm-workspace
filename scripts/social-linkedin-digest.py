#!/usr/bin/env python3
"""social-linkedin-digest.py — SE-385 §12/§14/§15: digests locales MVP1.

Genera en ~/.savia/social/linkedin/derived/:
  themes.md         — temas por frecuencia de términos (heurístico)
  savia-history.md  — posts que mencionan conceptos Savia, con temporalidad
  writing-style.md  — perfil estilístico básico (solo SELF_AUTHORED)
Determinista, local, sin red. Los posts jamás se vuelcan completos:
solo índices y extractos <=200 chars (progressive disclosure).
"""
from __future__ import annotations

import json
import os
import re
import sys
from collections import Counter

STOP = set("de la el los las un una unos unas y o u e a al del en con por que se su sus sin son fue era les le te os mi mis tu tus para como desde sobre entre hasta segun mas muy no si también tambien pero cuando esta este esto estos estas the and for with not all are was were have has had https com www linkedin fe posts".split())

SAVIA_TERMS = ["savia", "pm-workspace", "soberan", "humano decide", "criterio",
               "agentes", "agéntico", "agentico", "memoria", "sdd",
               "autonom", "inferencia", "privacidad", "open source", "harness"]

DEFAULT_STORE = os.path.expanduser("~/.savia/social/linkedin")


def load(store: str) -> list:
    path = os.path.join(store, "normalized", "artifacts.jsonl")
    if not os.path.exists(path):
        return []
    out = []
    for line in open(path, encoding="utf-8"):
        try:
            out.append(json.loads(line))
        except json.JSONDecodeError:
            continue
    return out


def main() -> int:
    store = os.environ.get("SOCIAL_STORE", DEFAULT_STORE)
    arts = load(store)
    derived = os.path.join(store, "derived")
    os.makedirs(derived, exist_ok=True)

    posts = [a for a in arts if a["artifact_type"] in ("post", "article")]

    # themes.md
    freq = Counter()
    for a in posts:
        for t in re.findall(r"[a-záéíóúñü_\-]{4,}", a["text"].lower()):
            if t not in STOP:
                freq[t] += 1
    with open(os.path.join(derived, "themes.md"), "w", encoding="utf-8") as f:
        f.write("# Themes (derivado, reconstruible)\n\n| término | apariciones |\n|---|---|\n")
        for t, n in freq.most_common(30):
            f.write(f"| {t} | {n} |\n")
        f.write(f"\nCorpus: {len(posts)} posts/articles. Extractos máx 200 chars (L1).\n")

    # savia-history.md (con temporalidad, §14)
    hits = []
    for a in sorted(posts, key=lambda x: x.get("created_at", "")):
        low = a["text"].lower()
        matched = [t for t in SAVIA_TERMS if t in low]
        if matched:
            hits.append((a.get("created_at", "s/f"), a["id"],
                         ",".join(matched[:4]), a["text"][:200]))
    with open(os.path.join(derived, "savia-history.md"), "w", encoding="utf-8") as f:
        f.write("# Savia History (derivado; idea pública ≠ posición actual, §13/§14)\n\n")
        f.write("Estados temporales: HISTORICAL por defecto; ninguna entrada es creencia actual.\n\n")
        f.write("| fecha | id | términos | extracto (<=200 chars) |\n|---|---|---|---|\n")
        for d, i, terms, ex in hits:
            f.write(f"| {d} | {i} | {terms} | {ex} |\n")
        f.write(f"\nPUBLIC IDEA vs REPO IMPLEMENTATION: correlación temporal no implica causalidad.\n")

    # writing-style.md (solo SELF_AUTHORED)
    own = [a for a in posts if a.get("authored") == "SELF_AUTHORED"]
    sents = [s.strip() for a in own for s in re.split(r"[.!?]\s", a["text"]) if len(s.strip()) > 20]
    lens = sorted(len(s.split()) for s in sents)
    med = lens[len(lens)//2] if lens else 0
    openings = Counter(s.split()[0].lower() for s in sents if s.split())
    lexicon = Counter()
    for s in sents:
        for t in re.findall(r"[a-záéíóúñü_\-]{6,}", s.lower()):
            if t not in STOP:
                lexicon[t] += 1
    with open(os.path.join(derived, "writing-style.md"), "w", encoding="utf-8") as f:
        f.write("# Writing Style (derivado; precede preferencia humana explícita)\n\n")
        f.write("```yaml\nlanguage: es\ncorpus_posts: %d\nsentences: %d\n" % (len(own), len(sents)))
        f.write("median_sentence_words: %d\n" % med)
        f.write("top_openings: %s\n" % json.dumps([o for o, _ in openings.most_common(8)]))
        f.write("lexicon_top: %s\n" % json.dumps([t for t, _ in lexicon.most_common(20)]))
        f.write("confidence: low (MVP1 heurístico)\nevidence_count: %d\n```\n" % len(own))

    print(f"digest: {len(posts)} posts → {len(hits)} savia-hits, derived/ actualizado")
    return 0


if __name__ == "__main__":
    sys.exit(main())
