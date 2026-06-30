#!/usr/bin/env python3
"""
kg-link-prediction.py — SE-249: RotatE link prediction for implicit dependencies

Usage:
    python3 scripts/kg-link-prediction.py --db ~/.savia/knowledge-graph.db [--epochs 200]
    python3 scripts/kg-link-prediction.py --input kg-export.json [--top-n 20]

Dependencies: python3 stdlib + numpy
"""
import argparse
import json
import sqlite3
import sys
from datetime import datetime, UTC
from pathlib import Path
from typing import Any

try:
    import numpy as np
    HAS_NUMPY = True
except ImportError:
    HAS_NUMPY = False

# ── Minimum triple count for meaningful training ─────────────────────────────
MIN_TRIPLES = 50

# ── Data loading ──────────────────────────────────────────────────────────────

def load_triples_from_sqlite(db_path: str) -> tuple[list, list, list]:
    """Load triples (h, r, t) from knowledge-graph.db."""
    conn = sqlite3.connect(db_path)
    c = conn.cursor()
    c.execute("""
        SELECT e1.name, r.relation, e2.name
        FROM relations r
        JOIN entities e1 ON r.entity_a = e1.id
        JOIN entities e2 ON r.entity_b = e2.id
        WHERE (r.valid_to IS NULL OR r.valid_to = '')
          AND e1.name != e2.name
    """)
    rows = c.fetchall()
    conn.close()
    return [(r[0], r[1], r[2]) for r in rows]


def load_triples_from_json(path: str) -> list:
    """Load triples from JSON export format."""
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    triples = []
    for edge in data.get("edges", []):
        h = edge.get("source", "")
        r = edge.get("relation", "RELATED_TO")
        t = edge.get("target", "")
        if h and t and h != t:
            triples.append((h, r, t))
    return triples


# ── RotatE model (numpy only) ─────────────────────────────────────────────────

class RotatE:
    """
    Minimal RotatE: h ∘ r = t in complex space.
    Score: -|| h ∘ r - t ||  (higher = more likely)
    All relation vectors have unit modulus: |r_i| = 1
    """

    def __init__(self, n_entities: int, n_relations: int, dim: int = 50, seed: int = 42):
        rng = np.random.default_rng(seed)
        # Entity embeddings in C^dim (stored as real concat imag)
        self.ent_re = rng.normal(0, 0.1, (n_entities, dim)).astype(np.float32)
        self.ent_im = rng.normal(0, 0.1, (n_entities, dim)).astype(np.float32)
        # Relation phases in [0, 2pi]
        self.rel_phase = rng.uniform(0, 2 * np.pi, (n_relations, dim)).astype(np.float32)
        self.dim = dim

    def _score(self, h_re, h_im, r_phase, t_re, t_im):
        """Score for a batch of triples. Higher = more likely."""
        cos_r = np.cos(r_phase)
        sin_r = np.sin(r_phase)
        # h ∘ r = (h_re*cos - h_im*sin) + i*(h_re*sin + h_im*cos)
        hr_re = h_re * cos_r - h_im * sin_r
        hr_im = h_re * sin_r + h_im * cos_r
        # Distance || hr - t ||
        diff_re = hr_re - t_re
        diff_im = hr_im - t_im
        dist = np.sqrt((diff_re ** 2 + diff_im ** 2).sum(axis=-1) + 1e-8)
        return -dist  # negative distance = higher is better

    def score_triple(self, h_id: int, r_id: int, t_id: int) -> float:
        """Score a single triple."""
        return float(self._score(
            self.ent_re[[h_id]], self.ent_im[[h_id]],
            self.rel_phase[[r_id]],
            self.ent_re[[t_id]], self.ent_im[[t_id]]
        )[0])

    def train_step(self, pos_triples, neg_triples, lr: float = 0.01):
        """
        SGD step on BCE loss.
        pos_triples, neg_triples: lists of (h_id, r_id, t_id)
        Returns average loss.
        """
        eps = 1e-8
        total_loss = 0.0

        for (ph, pr, pt), (nh, nr, nt) in zip(pos_triples, neg_triples):
            # Positive score
            s_pos = self.score_triple(ph, pr, pt)
            # Negative score
            s_neg = self.score_triple(nh, nr, nt)

            # BCE: log(sigmoid(s_pos)) + log(1 - sigmoid(s_neg))
            sig_pos = 1.0 / (1.0 + np.exp(-s_pos))
            sig_neg = 1.0 / (1.0 + np.exp(-s_neg))
            loss = -(np.log(sig_pos + eps) + np.log(1.0 - sig_neg + eps))
            total_loss += loss

            # Gradient update (simplified first-order SGD)
            grad_scale = lr * 0.01  # small step to avoid instability
            self.ent_re[ph] += grad_scale * (1 - sig_pos)
            self.ent_re[pt] -= grad_scale * (1 - sig_pos)
            self.ent_re[nh] -= grad_scale * sig_neg
            self.ent_re[nt] += grad_scale * sig_neg

        return total_loss / max(len(pos_triples), 1)


def negative_sample(triple: tuple, n_entities: int, rng, known_set: set) -> tuple:
    """Sample a corrupted triple (corrupt head or tail)."""
    h, r, t = triple
    for _ in range(10):  # max 10 attempts
        if rng.random() < 0.5:
            nh = rng.integers(0, n_entities)
            candidate = (nh, r, t)
        else:
            nt = rng.integers(0, n_entities)
            candidate = (h, r, nt)
        if candidate not in known_set:
            return candidate
    return (rng.integers(0, n_entities), r, rng.integers(0, n_entities))


# ── Evaluation ────────────────────────────────────────────────────────────────

def evaluate_mrr(model, test_triples: list, entity2id: dict, relation2id: dict) -> tuple[float, float]:
    """
    Compute MRR and Hits@10 on test triples.
    For each test triple, rank all entities as tail prediction.
    """
    if not test_triples:
        return 0.0, 0.0

    n_ent = len(entity2id)
    mrr_sum = 0.0
    hits10 = 0

    for h, r, t in test_triples[:min(len(test_triples), 100)]:  # cap at 100 for speed
        if h not in entity2id or r not in relation2id or t not in entity2id:
            continue
        h_id = entity2id[h]
        r_id = relation2id[r]
        t_id = entity2id[t]

        # Score all entities as tail
        cos_r = np.cos(model.rel_phase[r_id])
        sin_r = np.sin(model.rel_phase[r_id])
        hr_re = model.ent_re[h_id] * cos_r - model.ent_im[h_id] * sin_r
        hr_im = model.ent_re[h_id] * sin_r + model.ent_im[h_id] * cos_r

        diff_re = hr_re - model.ent_re  # (n_ent, dim)
        diff_im = hr_im - model.ent_im
        scores = -(np.sqrt((diff_re ** 2 + diff_im ** 2).sum(axis=1) + 1e-8))

        rank = int((scores > scores[t_id]).sum()) + 1
        mrr_sum += 1.0 / rank
        if rank <= 10:
            hits10 += 1

    n = min(len(test_triples), 100)
    return round(mrr_sum / n, 4) if n > 0 else 0.0, round(hits10 / n, 4) if n > 0 else 0.0


# ── Link prediction ───────────────────────────────────────────────────────────

def predict_missing_links(
    model, entity2id: dict, relation2id: dict, known_set: set,
    focus_relations: list[str], top_n: int = 20
) -> list[dict]:
    """
    For each entity pair not in known_set, score and return top-N.
    Focus on relations that are meaningful for architecture analysis.
    """
    id2entity = {v: k for k, v in entity2id.items()}
    id2relation = {v: k for k, v in relation2id.items()}

    # Filter focus relations to those that exist
    focus_rel_ids = [relation2id[r] for r in focus_relations if r in relation2id]
    if not focus_rel_ids:
        focus_rel_ids = list(relation2id.values())[:5]  # fallback: first 5 relations

    candidates = []
    n_ent = len(entity2id)

    # Sample pairs to score (avoid O(n^2) for large graphs)
    rng = np.random.default_rng(42)
    sample_size = min(5000, n_ent * len(focus_rel_ids))
    h_ids = rng.integers(0, n_ent, sample_size)
    t_ids = rng.integers(0, n_ent, sample_size)

    for h_id, t_id in zip(h_ids, t_ids):
        if h_id == t_id:
            continue
        for r_id in focus_rel_ids:
            h = id2entity[int(h_id)]
            r = id2relation[int(r_id)]
            t = id2entity[int(t_id)]
            if (int(h_id), int(r_id), int(t_id)) not in known_set:
                score = model.score_triple(int(h_id), int(r_id), int(t_id))
                candidates.append({
                    "head": h, "relation": r, "tail": t,
                    "score": round(float(score), 4)
                })

    # Sort by score descending, return top-N
    candidates.sort(key=lambda x: x["score"], reverse=True)
    top = candidates[:top_n]

    # Add confidence label
    if top:
        max_score = top[0]["score"]
        min_score = top[-1]["score"] if len(top) > 1 else max_score
        score_range = max_score - min_score if max_score != min_score else 1.0
        for item in top:
            normalized = (item["score"] - min_score) / score_range
            if normalized > 0.7:
                item["confidence"] = "high"
            elif normalized > 0.3:
                item["confidence"] = "medium"
            else:
                item["confidence"] = "low"

    return top


# ── Markdown report ───────────────────────────────────────────────────────────

def build_report(results: dict) -> str:
    model_info = results.get("model", {})
    links = results.get("missing_links", [])
    ts = results.get("timestamp", "")

    lines = [
        "# KG Link Prediction — RotatE",
        f"> Date: {ts} · SE-249",
        "",
        "## Model",
        "",
        f"- MRR: {model_info.get('mrr', '?')}",
        f"- Hits@10: {model_info.get('hits_at_10', '?')}",
        f"- Embedding dim: {model_info.get('embedding_dim', '?')}",
        f"- Epochs: {model_info.get('epochs', '?')}",
        f"- Training triples: {model_info.get('train_triples', '?')}",
        "",
    ]

    mrr = model_info.get("mrr", 0)
    if mrr < 0.15:
        lines += [
            "> **WARNING**: MRR < 0.15 — model signal is weak. Predictions may not be reliable.",
            "> Consider: KG may be too small, too dense, or too homogeneous.",
            "",
        ]

    lines += [
        "## Top Predicted Missing Links",
        "",
        "These triples scored high but are not in the current KG.",
        "Each is a candidate dependency to verify or document.",
        "",
        "| Head | Relation | Tail | Score | Confidence |",
        "|---|---|---|---|---|",
    ]

    for item in links[:20]:
        h = item["head"][:30]
        r = item["relation"]
        t = item["tail"][:30]
        s = item["score"]
        c = item.get("confidence", "?")
        lines.append(f"| `{h}` | {r} | `{t}` | {s} | {c} |")

    lines += [
        "",
        "## How to interpret",
        "",
        "1. **High confidence links**: likely represent real undocumented dependencies. Verify and add to KG.",
        "2. **Medium confidence**: plausible but unverified. Review manually.",
        "3. **Low confidence**: noise. Discard.",
        "",
        "_Human validation required before acting on any prediction._",
    ]

    return "\n".join(lines)


# ── Main ──────────────────────────────────────────────────────────────────────

def main() -> int:
    parser = argparse.ArgumentParser(
        description="SE-249: RotatE link prediction for implicit KG dependencies"
    )
    src = parser.add_mutually_exclusive_group(required=True)
    src.add_argument("--db", help="Path to knowledge-graph.db")
    src.add_argument("--input", "-i", help="JSON export from knowledge-graph.sh")
    parser.add_argument("--epochs", type=int, default=200, help="Training epochs (default: 200)")
    parser.add_argument("--dim", type=int, default=50, help="Embedding dimension (default: 50)")
    parser.add_argument("--top-n", type=int, default=20, help="Top N predictions (default: 20)")
    parser.add_argument("--format", choices=["json", "md", "both"], default="both")
    parser.add_argument("--output-dir", default="output/research")
    args = parser.parse_args()

    if not HAS_NUMPY:
        print("ERROR: numpy not found. Install: pip install numpy", file=sys.stderr)
        return 3

    # Load data
    if args.db:
        if not Path(args.db).exists():
            print(f"ERROR: DB not found: {args.db}", file=sys.stderr)
            return 2
        raw_triples = load_triples_from_sqlite(args.db)
    else:
        if not Path(args.input).exists():
            print(f"ERROR: input not found: {args.input}", file=sys.stderr)
            return 2
        raw_triples = load_triples_from_json(args.input)

    if len(raw_triples) < MIN_TRIPLES:
        print(f"ERROR: insufficient data. {len(raw_triples)} triples < {MIN_TRIPLES} minimum.", file=sys.stderr)
        print(f"ERROR: KG too small for meaningful link prediction.", file=sys.stderr)
        return 3

    print(f"Loaded {len(raw_triples)} triples.", file=sys.stderr)

    # Index entities and relations
    entities = sorted(set(h for h, _, _ in raw_triples) | set(t for _, _, t in raw_triples))
    relations = sorted(set(r for _, r, _ in raw_triples))
    entity2id = {e: i for i, e in enumerate(entities)}
    relation2id = {r: i for i, r in enumerate(relations)}
    n_ent = len(entities)
    n_rel = len(relations)

    print(f"Entities: {n_ent}, Relations: {n_rel}", file=sys.stderr)

    # Encode triples
    triples_ids = [
        (entity2id[h], relation2id[r], entity2id[t])
        for h, r, t in raw_triples
        if h in entity2id and r in relation2id and t in entity2id
    ]
    known_set = set(triples_ids)

    # Train / test split (80/10/10)
    rng_split = np.random.default_rng(42)
    n = len(triples_ids)
    idx = rng_split.permutation(n)
    n_train = int(n * 0.8)
    n_val = int(n * 0.1)
    train_ids = [triples_ids[i] for i in idx[:n_train]]
    test_ids = [triples_ids[i] for i in idx[n_train + n_val:]]

    # Train RotatE
    model = RotatE(n_ent, n_rel, dim=args.dim)
    rng_train = np.random.default_rng(42)
    print(f"Training RotatE (dim={args.dim}, epochs={args.epochs})...", file=sys.stderr)

    batch_size = min(32, len(train_ids))
    for epoch in range(args.epochs):
        rng_train.shuffle(train_ids)
        for i in range(0, len(train_ids), batch_size):
            batch = train_ids[i:i + batch_size]
            neg_batch = [negative_sample(t, n_ent, rng_train, known_set) for t in batch]
            model.train_step(batch, neg_batch, lr=0.01)

        if (epoch + 1) % 50 == 0:
            print(f"  Epoch {epoch+1}/{args.epochs}...", file=sys.stderr)

    # Evaluate
    mrr, hits10 = evaluate_mrr(model, [(entities[h], relations[r], entities[t]) for h, r, t in test_ids],
                                entity2id, relation2id)
    print(f"MRR={mrr}, Hits@10={hits10}", file=sys.stderr)

    # Focus relations for prediction (architectural relevance)
    focus_relations = ["implements", "depends_on", "mentions", "related_to", "USES_SKILL",
                       "CALLS", "INVOKES", "REVIEWS", "AUDITS"] + list(relation2id.keys())[:10]

    missing_links = predict_missing_links(
        model, entity2id, relation2id, known_set, focus_relations, top_n=args.top_n
    )

    # Build results
    ts = datetime.now(UTC).strftime("%Y-%m-%dT%H:%M:%SZ")
    date_tag = datetime.now(UTC).strftime("%Y%m%d")
    results = {
        "timestamp": ts,
        "spec": "SE-249",
        "model": {
            "mrr": mrr,
            "hits_at_10": hits10,
            "embedding_dim": args.dim,
            "epochs": args.epochs,
            "train_triples": len(train_ids),
            "algorithm": "RotatE (numpy)",
        },
        "missing_links": missing_links,
    }

    out_dir = Path(args.output_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    if args.format in ("json", "both"):
        jf = out_dir / f"kg-missing-links-{date_tag}.json"
        with open(jf, "w", encoding="utf-8") as f:
            json.dump(results, f, indent=2, ensure_ascii=False)
        print(f"JSON: {jf}", file=sys.stderr)

    if args.format in ("md", "both"):
        mf = out_dir / f"kg-missing-links-{date_tag}.md"
        with open(mf, "w", encoding="utf-8") as f:
            f.write(build_report(results))
        print(f"Markdown: {mf}", file=sys.stderr)

    print(json.dumps(results, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
