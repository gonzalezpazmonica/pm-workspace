#!/usr/bin/env python3
"""
security-benchmark-metrics.py — SPEC-032 Precision/Recall Metrics

Calcula metricas de precision, recall y F1 para los agentes de seguridad
comparando hallazgos reales con los esperados.

Usage:
    python3 scripts/security-benchmark-metrics.py \
        --actual findings.json --expected tests/fixtures/security-benchmark/expected-findings.json
    python3 scripts/security-benchmark-metrics.py --help

Output: JSON + tabla de metricas por CWE y global.

Ref: SPEC-032-security-benchmarks.md
"""

import argparse
import json
import sys
from typing import Any


def load_json(path: str) -> dict:
    try:
        with open(path) as f:
            return json.load(f)
    except FileNotFoundError:
        print(f"[ERROR] File not found: {path}", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"[ERROR] Invalid JSON in {path}: {e}", file=sys.stderr)
        sys.exit(1)


def normalize_finding(f: dict) -> dict:
    """Normalize a finding to a common format."""
    return {
        "id": f.get("id", ""),
        "cwe": f.get("cwe", "UNKNOWN"),
        "severity": f.get("severity", "unknown"),
        "name": f.get("name", ""),
    }


def compute_metrics(
    actual_findings: list[dict],
    expected_findings: list[dict],
) -> dict[str, Any]:
    """
    Compute precision, recall, F1, and false negative count.

    A match is defined by CWE (primary) or finding name/id (fallback).
    """
    expected_cwes = {f["cwe"] for f in expected_findings}
    expected_ids = {f["id"] for f in expected_findings}

    # True positives: actual findings that match an expected finding
    true_positives = []
    false_positives = []
    matched_expected_ids: set[str] = set()

    for actual in actual_findings:
        norm = normalize_finding(actual)
        # Match by CWE or finding id
        matched = False
        for exp in expected_findings:
            if exp["id"] in matched_expected_ids:
                continue
            if norm["cwe"] == exp["cwe"] or norm["id"] == exp["id"]:
                true_positives.append(norm)
                matched_expected_ids.add(exp["id"])
                matched = True
                break
        if not matched:
            false_positives.append(norm)

    false_negatives = [
        f for f in expected_findings if f["id"] not in matched_expected_ids
    ]

    tp = len(true_positives)
    fp = len(false_positives)
    fn = len(false_negatives)
    total_expected = len(expected_findings)
    total_actual = len(actual_findings)

    precision = tp / (tp + fp) if (tp + fp) > 0 else 0.0
    recall = tp / (tp + fn) if (tp + fn) > 0 else 0.0
    f1 = (
        2 * precision * recall / (precision + recall)
        if (precision + recall) > 0
        else 0.0
    )
    detection_rate = tp / total_expected if total_expected > 0 else 0.0
    false_positive_rate = fp / total_actual if total_actual > 0 else 0.0

    # Per-CWE breakdown
    cwe_breakdown: dict[str, dict] = {}
    for exp in expected_findings:
        cwe = exp["cwe"]
        found = exp["id"] in matched_expected_ids
        if cwe not in cwe_breakdown:
            cwe_breakdown[cwe] = {"expected": 0, "found": 0}
        cwe_breakdown[cwe]["expected"] += 1
        if found:
            cwe_breakdown[cwe]["found"] += 1

    # Threshold pass/fail
    THRESHOLD_DETECTION = 0.70
    THRESHOLD_FPR = 0.30
    passes = detection_rate >= THRESHOLD_DETECTION and false_positive_rate <= THRESHOLD_FPR

    return {
        "precision": round(precision, 4),
        "recall": round(recall, 4),
        "f1": round(f1, 4),
        "detection_rate": round(detection_rate, 4),
        "false_positive_rate": round(false_positive_rate, 4),
        "true_positives": tp,
        "false_positives": fp,
        "false_negative_count": fn,
        "total_expected": total_expected,
        "total_actual": total_actual,
        "cwe_breakdown": {
            cwe: {
                "expected": v["expected"],
                "found": v["found"],
                "detection_rate": round(v["found"] / v["expected"], 4) if v["expected"] > 0 else 0.0,
            }
            for cwe, v in sorted(cwe_breakdown.items())
        },
        "false_negative_details": [normalize_finding(f) for f in false_negatives],
        "thresholds": {
            "min_detection_rate": THRESHOLD_DETECTION,
            "max_false_positive_rate": THRESHOLD_FPR,
        },
        "pass": passes,
    }


def print_table(metrics: dict) -> None:
    """Print a human-readable table of metrics."""
    status = "PASS" if metrics["pass"] else "FAIL"
    bar = "=" * 50

    print(f"\n{bar}")
    print("  Security Benchmark Metrics")
    print(bar)
    print(f"  Status ................. {status}")
    print(f"  Precision .............. {metrics['precision']:.4f}")
    print(f"  Recall ................. {metrics['recall']:.4f}")
    print(f"  F1 Score ............... {metrics['f1']:.4f}")
    print(f"  Detection Rate ......... {metrics['detection_rate']:.4f}  (min: {metrics['thresholds']['min_detection_rate']})")
    print(f"  False Positive Rate .... {metrics['false_positive_rate']:.4f}  (max: {metrics['thresholds']['max_false_positive_rate']})")
    print(f"  True Positives ......... {metrics['true_positives']}/{metrics['total_expected']}")
    print(f"  False Positives ........ {metrics['false_positives']}")
    print(f"  False Negatives ........ {metrics['false_negative_count']}")
    print(f"\n  By CWE:")
    for cwe, v in metrics["cwe_breakdown"].items():
        found_str = f"{v['found']}/{v['expected']}"
        rate_str = f"{v['detection_rate']:.0%}"
        print(f"    {cwe:<12} {found_str:>6}  {rate_str:>5}")
    if metrics["false_negative_details"]:
        print(f"\n  Missed findings:")
        for fn in metrics["false_negative_details"]:
            print(f"    [{fn['severity'].upper():8}] {fn['cwe']} — {fn['name']}")
    print(bar)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Compute precision/recall/F1 for security agent findings."
    )
    parser.add_argument(
        "--actual",
        required=True,
        help="Path to actual findings JSON (output from security agent)",
    )
    parser.add_argument(
        "--expected",
        required=True,
        help="Path to expected findings JSON (fixture)",
    )
    parser.add_argument(
        "--output",
        default=None,
        help="Write JSON metrics to this file (default: stdout)",
    )
    parser.add_argument(
        "--table-only",
        action="store_true",
        help="Print table only, no JSON output",
    )
    parser.add_argument(
        "--json-only",
        action="store_true",
        help="Print JSON only, no table",
    )
    args = parser.parse_args()

    actual_data = load_json(args.actual)
    expected_data = load_json(args.expected)

    # Accept both {"findings": [...]} and plain list
    actual_findings = actual_data.get("findings", actual_data) if isinstance(actual_data, dict) else actual_data
    expected_findings = expected_data.get("findings", expected_data) if isinstance(expected_data, dict) else expected_data

    if not isinstance(actual_findings, list):
        print("[ERROR] actual findings must be a list or {findings: [...]}", file=sys.stderr)
        sys.exit(1)
    if not isinstance(expected_findings, list):
        print("[ERROR] expected findings must be a list or {findings: [...]}", file=sys.stderr)
        sys.exit(1)

    metrics = compute_metrics(actual_findings, expected_findings)

    if not args.table_only:
        json_output = json.dumps(metrics, indent=2)
        if args.output:
            with open(args.output, "w") as f:
                f.write(json_output)
            print(f"[INFO] Metrics written to: {args.output}", file=sys.stderr)
        else:
            print(json_output)

    if not args.json_only:
        print_table(metrics)

    sys.exit(0 if metrics["pass"] else 1)


if __name__ == "__main__":
    main()
