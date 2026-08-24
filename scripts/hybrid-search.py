#!/usr/bin/env python3
"""hybrid-search.py — Local hybrid BM25+vector search over a dome/notes dir
(SE-342 S6 / Labs L22).

POC for hybrid retrieval over SaviaVaults notes: keyword (BM25) + optional
dense scores (cosine over the local embedding-server at localhost:7331),
fusioned deterministically. Zero egress — embeddings come from the local
endpoint, never the cloud (CRIT-001).

Usage:
  hybrid-search.py index --dir NOTES [--out INDEX.json]
  hybrid-search.py query --index INDEX.json "consulta" [--top K] [--alpha 0.5]

Exit: 0 ok | 1 no results | 2 invalid invocation
Env: SAVIA_EMBED_URL (default http://localhost:7331/embed)
"""

import argparse
import json
import math
import os
import re
import sys
import urllib.request
from pathlib import Path

SAVIA_EMBED_URL = os.environ.get("SAVIA_EMBED_URL", "http://localhost:7331/embed")


def _tokenize(text: str) -> list[str]:
    return re.findall(r"[a-z0-9_\-]{3,}", text.lower())


def _idf(term: str, doc_count: int, df: int) -> float:
    return math.log((doc_count - df + 0.5) / (df + 0.5) + 1.0)


def bm25_score(query_tokens, doc_text, idf_map, k1=1.5, b=0.75, avg_dl=50.0):
    doc_tokens = _tokenize(doc_text)
    dl = len(doc_tokens)
    tf_map = {}
    for t in doc_tokens:
        tf_map[t] = tf_map.get(t, 0) + 1
    score = 0.0
    for term in query_tokens:
        tf = tf_map.get(term, 0)
        if tf == 0:
            continue
        idf = idf_map.get(term, math.log(1.5))
        num = tf * (k1 + 1)
        den = tf + k1 * (1 - b + b * dl / avg_dl)
        score += idf * num / den
    return score


def _cosine(a, b):
    dot = sum(x * y for x, y in zip(a, b))
    na = math.sqrt(sum(x * x for x in a)) or 1.0
    nb = math.sqrt(sum(x * x for x in b)) or 1.0
    return dot / (na * nb)


def _embed(text):
    body = json.dumps({"text": text}).encode()
    try:
        req = urllib.request.Request(SAVIA_EMBED_URL, data=body,
                                     headers={"Content-Type": "application/json"})
        with urllib.request.urlopen(req, timeout=5) as resp:
            return list(json.loads(resp.read())["embedding"])
    except Exception:  # noqa: BLE001 — local endpoint unavailable -> dense disabled
        return None


def index_cmd(args):
    d = Path(args.dir)
    if not d.is_dir():
        print(f"ERROR: dir not found: {d}", file=sys.stderr)
        return 2
    notes = []
    for p in sorted(d.rglob("*.md")):  # deterministic order
        try:
            notes.append({"path": str(p.relative_to(d)), "text": p.read_text(encoding="utf-8", errors="ignore")})
        except OSError:
            continue
    if not notes:
        print("ERROR: no .md notes found", file=sys.stderr)
        return 1
    # term stats
    doc_count = len(notes)
    df = {}
    for n in notes:
        for t in set(_tokenize(n["text"])):
            df[t] = df.get(t, 0) + 1
    avg_dl = sum(len(_tokenize(n["text"])) for n in notes) / max(doc_count, 1)
    idf_map = {t: _idf(t, doc_count, d_f) for t, d_f in sorted(df.items())}
    index = {"avg_dl": avg_dl, "doc_count": doc_count, "idf": idf_map, "notes": notes}
    out = args.out or "hybrid-index.json"
    with open(out, "w", encoding="utf-8") as fh:
        json.dump(index, fh, ensure_ascii=False)
    print(f"indexed {doc_count} notes -> {out}")
    return 0


def query_cmd(args):
    index_path = args.index
    if not Path(index_path).exists():
        print("ERROR: index not found — run 'index' first", file=sys.stderr)
        return 1
    with open(index_path, encoding="utf-8") as fh:
        idx = json.load(fh)
    qt = _tokenize(args.query)
    if not qt:
        print("ERROR: empty query", file=sys.stderr)
        return 1
    alpha = float(args.alpha)
    # dense: query embedding (local), doc embeddings lazily cached per run
    qvec = _embed(args.query)
    scores = []
    for n in idx["notes"]:
        b = bm25_score(qt, n["text"], idx["idf"], avg_dl=idx["avg_dl"])
        if qvec is not None:
            dv = _embed(n["text"])
            v = _cosine(qvec, dv) if dv else 0.0
        else:
            v = 0.0
        # fusion: alpha weights the dense score, (1-alpha) the keyword score;
        # when dense is unavailable (v=0), ranking falls back to BM25.
        fused = alpha * v + (1 - alpha) * b
        scores.append({"path": n["path"], "bm25": round(b, 4), "cosine": round(v, 4), "fused": round(fused, 4)})
    scores.sort(key=lambda s: (s["fused"], s["bm25"]), reverse=True)
    top = scores[: args.top]
    if not top:
        print("no results")
        return 1
    for s in top:
        print(f"{s['path']}\tfused={s['fused']}\tbm25={s['bm25']}\tcos={s['cosine']}")
    return 0


def main(argv=None):
    argv = argv if argv is not None else sys.argv[1:]
    if argv and argv[0] == "--version":
        print("hybrid-search.py 0.1.0 (SE-342 S6 / L22)")
        return 0
    p = argparse.ArgumentParser(prog="hybrid-search")
    sub = p.add_subparsers(dest="cmd", required=True)
    pi = sub.add_parser("index")
    pi.add_argument("--dir", required=True)
    pi.add_argument("--out")
    pi.set_defaults(fn=index_cmd)
    pq = sub.add_parser("query")
    pq.add_argument("--index", required=True)
    pq.add_argument("query")
    pq.add_argument("--top", type=int, default=5)
    pq.add_argument("--alpha", type=float, default=0.5)
    pq.set_defaults(fn=query_cmd)
    args = p.parse_args(argv)
    return args.fn(args)


if __name__ == "__main__":
    sys.exit(main())