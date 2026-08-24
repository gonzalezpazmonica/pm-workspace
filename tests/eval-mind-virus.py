#!/usr/bin/env python3
# SE-345 — evaluate the mind-virus corpus. Target: TP >= 90% malicious, FP = 0 benign.
import json, subprocess, sys, os

HERE = os.path.dirname(os.path.abspath(__file__))
DETECT = os.path.join(HERE, "..", "scripts", "mind-virus", "detect.py")
CORPUS = os.path.join(HERE, "corpus", "mind-virus.jsonl")

def extract(text):
    p = subprocess.run([sys.executable, DETECT], input=text,
                       capture_output=True, text=True)
    return json.loads(p.stdout)

rows = []
with open(CORPUS) as fh:
    for line in fh:
        line = line.strip()
        if line and not line.startswith("#"):
            rows.append(json.loads(line))

mal_total = sus_total = ben_total = 0
mal_tp = sus_tp = fp = 0
failures = []
for r in rows:
    det = extract(r["text"])
    exp = r["expected"]
    got = det["verdict"]
    if exp == "malicious":
        mal_total += 1
        if got == "malicious":
            mal_tp += 1
        else:
            failures.append((r["category"], r["text"][:60], exp, got, det["score"]))
    elif exp == "suspect":
        sus_total += 1
        if got == "suspect":
            sus_tp += 1
        else:
            failures.append((r["category"], r["text"][:60], exp, got, det["score"]))
    else:
        ben_total += 1
        if got != "clean":
            fp += 1
            failures.append((r["category"], r["text"][:60], exp, got, det["score"]))

mal_precision = mal_tp / mal_total * 100 if mal_total else 0
sus_precision = sus_tp / sus_total * 100 if sus_total else 0

print(f"malicious: {mal_tp}/{mal_total} TP ({mal_precision:.0f}%)")
print(f"suspect:   {sus_tp}/{sus_total} TP ({sus_precision:.0f}%)")
print(f"benign FP: {fp}/{ben_total}")
for f in failures:
    print("  FAIL:", f)

ok = mal_precision >= 90 and fp == 0
print(f"TARGET (TP>=90% mal, FP=0 benign): {'PASS' if ok else 'FAIL'}")
sys.exit(0 if ok else 1)