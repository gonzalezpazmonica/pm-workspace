#!/usr/bin/env python3
"""topic-cluster.py — SE-033 Slice 2 BERTopic clustering wrapper.

Agrupa documentos (retros, PBIs, incidents, lessons) en clusters tematicos
via BERTopic (UMAP + HDBSCAN + c-TF-IDF). Genera labels legibles.

Usage:
    echo '{"documents":[{"id":"a","text":"..."},...]}' | python3 scripts/topic-cluster.py --min-cluster-size 3

Input:
    {
      "documents": [
        {"id": "str", "text": "str", "metadata": {...}}
      ],
      "min_cluster_size": 3,  # optional, default 3
      "nr_topics": null        # optional, "auto" | int | null
    }

Output:
    {
      "topics": [
        {"id": 0, "label": "topic keyword summary",
         "keywords": ["w1","w2"], "size": 7, "documents": ["id1","id2"]}
      ],
      "outliers": ["id_unclustered1"],
      "backend": "bertopic|fallback-keyword",
      "model_info": {"sbert":"...", "docs":N, "clusters":K},
      "latency_ms": int
    }

Exit codes:
    0 - OK
    1 - parse error or insufficient input
    2 - usage error

Ref: SE-033, docs/propuestas/SE-033-topic-cluster-skill.md
Safety: read-only input, no egress salvo 1st model download (opt-in).
"""

import argparse
import json
import re
import sys
import time
from collections import Counter

DEFAULT_MIN_CLUSTER = 3
DEFAULT_MIN_DOCS = 3
STOPWORDS = {
    "the", "a", "an", "and", "or", "but", "is", "are", "was", "were",
    "de", "la", "el", "un", "una", "y", "o", "que", "en", "con", "para",
    "to", "of", "in", "on", "at", "by", "for", "with", "as", "from",
    "this", "that", "it", "we", "you", "they", "i", "be", "has", "have",
}


def parse_args():
    p = argparse.ArgumentParser(description="BERTopic cluster wrapper (SE-033).")
    p.add_argument("--min-cluster-size", type=int, default=DEFAULT_MIN_CLUSTER)
    p.add_argument("--nr-topics", default=None, help='"auto" | int | None')
    p.add_argument("--json", action="store_true", help="Pretty JSON output")
    return p.parse_args()


def fallback_keyword_cluster(documents, min_cluster_size):
    """Keyword-based clustering when BERTopic unavailable.

    Extracts top keywords per doc, groups by shared keyword prefix.
    Produces sensible-but-rough clusters without any ML dependency.
    """
    doc_keywords = {}
    all_words = Counter()
    for d in documents:
        text = d.get("text", "").lower()
        words = re.findall(r"\b[a-z][a-z0-9-]{2,}\b", text)
        words = [w for w in words if w not in STOPWORDS]
        doc_keywords[d["id"]] = Counter(words)
        all_words.update(set(words))

    top_words = [w for w, c in all_words.most_common(30) if c >= 2]
    clusters = {}
    assigned = set()
    for w in top_words:
        members = [d["id"] for d in documents
                   if doc_keywords.get(d["id"], {}).get(w, 0) > 0
                   and d["id"] not in assigned]
        if len(members) >= min_cluster_size:
            clusters[w] = members
            assigned.update(members)

    topics = []
    for i, (keyword, members) in enumerate(clusters.items()):
        topics.append({
            "id": i,
            "label": f"cluster-{keyword}",
            "keywords": [keyword],
            "size": len(members),
            "documents": members,
        })
    outliers = [d["id"] for d in documents if d["id"] not in assigned]
    return topics, outliers, "fallback-keyword"


def try_bertopic(documents, min_cluster_size, nr_topics):
    """Attempt BERTopic clustering. Returns (topics, outliers, backend, info) or None."""
    try:
        import contextlib
        import io
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            from bertopic import BERTopic
            from sentence_transformers import SentenceTransformer
        sys.stderr.write(buf.getvalue())
    except ImportError:
        return None

    try:
        import contextlib
        import io
        buf = io.StringIO()
        texts = [d["text"] for d in documents]
        ids = [d["id"] for d in documents]
        with contextlib.redirect_stdout(buf):
            sbert = SentenceTransformer("all-MiniLM-L6-v2")
            model = BERTopic(
                embedding_model=sbert,
                min_topic_size=min_cluster_size,
                nr_topics=nr_topics,
                verbose=False,
            )
            topics_assigned, _ = model.fit_transform(texts)
        sys.stderr.write(buf.getvalue())

        topic_info = model.get_topic_info()
        topics_out = []
        outliers = []
        for i, tid in enumerate(topics_assigned):
            if tid == -1:
                outliers.append(ids[i])

        for _, row in topic_info.iterrows():
            tid = int(row["Topic"])
            if tid == -1:
                continue
            members = [ids[j] for j, t in enumerate(topics_assigned) if t == tid]
            words = model.get_topic(tid) or []
            keywords = [w for w, _ in words[:5]]
            label = " ".join(keywords[:3]) if keywords else f"topic-{tid}"
            topics_out.append({
                "id": tid,
                "label": label,
                "keywords": keywords,
                "size": len(members),
                "documents": members,
            })
        return topics_out, outliers, "bertopic", {
            "sbert": "all-MiniLM-L6-v2",
            "docs": len(documents),
            "clusters": len(topics_out),
        }
    except (OSError, RuntimeError, ValueError, ImportError) as e:
        sys.stderr.write(f"topic-cluster: bertopic failed: {e}\n")
        return None


def main():
    args = parse_args()
    if args.min_cluster_size < 2:
        sys.stderr.write("ERROR: --min-cluster-size must be >= 2\n")
        return 2

    try:
        data = json.load(sys.stdin)
    except json.JSONDecodeError as e:
        sys.stderr.write(f"ERROR: invalid JSON input: {e}\n")
        return 1

    documents = data.get("documents", [])
    if not isinstance(documents, list):
        sys.stderr.write("ERROR: 'documents' must be a list\n")
        return 1
    if len(documents) < DEFAULT_MIN_DOCS:
        sys.stderr.write(f"ERROR: at least {DEFAULT_MIN_DOCS} documents required (got {len(documents)})\n")
        return 1
    for i, d in enumerate(documents):
        if not isinstance(d, dict) or "id" not in d or "text" not in d:
            sys.stderr.write(f"ERROR: document[{i}] must have 'id' and 'text'\n")
            return 1

    nr_topics = data.get("nr_topics", args.nr_topics)
    if isinstance(nr_topics, str) and nr_topics.isdigit():
        nr_topics = int(nr_topics)

    start = time.time()
    result = try_bertopic(documents, args.min_cluster_size, nr_topics)
    if result is not None:
        topics, outliers, backend, model_info = result
    else:
        topics, outliers, backend = fallback_keyword_cluster(documents, args.min_cluster_size)
        model_info = {"docs": len(documents), "clusters": len(topics)}

    latency_ms = int((time.time() - start) * 1000)

    out = {
        "topics": topics,
        "outliers": outliers,
        "backend": backend,
        "model_info": model_info,
        "latency_ms": latency_ms,
    }
    indent = 2 if args.json else None
    sys.stdout.write(json.dumps(out, ensure_ascii=False, indent=indent))
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
