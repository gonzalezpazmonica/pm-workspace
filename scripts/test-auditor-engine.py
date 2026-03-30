#!/usr/bin/env python3
"""test-auditor-engine.py — Deterministic 9-criteria scorer for BATS tests.
SPEC-055: regex/pattern matching only, zero LLM calls.
Usage: python3 test-auditor-engine.py <test-file.bats> <project-root>
"""
import hashlib, json, os, re, sys
from datetime import date

def read_file(path):
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            return f.read()
    except FileNotFoundError:
        return ""

def find_target(test_file, root):
    content = read_file(test_file)
    m = re.search(r'(?:SCRIPT|HOOK)\s*=\s*["\']([^"\']+)["\']', content)
    if m:
        c = os.path.join(root, m.group(1))
        if os.path.isfile(c): return c
    base = os.path.basename(test_file).replace("test-","").replace("test_","").replace(".bats",".sh")
    for d in ["scripts", ".claude/hooks"]:
        c = os.path.join(root, d, base)
        if os.path.isfile(c): return c
    return None

def get_tests(content):
    return re.findall(r'@test\s+"([^"]*)"', content)

NEG_PAT = r'(error|fail|missing|invalid|bad|block|reject|skip|disabled|no.arg|graceful|empty)'
EDGE_PAT = [r'empty', r'nonexistent', r'large', r'boundary', r'max.*depth',
    r'cap.*at', r'overflow', r'zero', r'null', r'no.*arg', r'timeout']

def c1_exists(f):
    pts = 5 if os.path.isfile(f) else 0
    if read_file(f).startswith("#!/"): pts += 3
    if os.access(f, os.X_OK): pts += 2
    return min(pts, 10)

def c2_safety(c):
    if re.search(r'set -[eu]*o pipefail|grep.*set.*pipefail|head.*grep.*pipefail', c): return 10
    if re.search(r'grep.*set -\[?[euo]', c): return 10
    if re.search(r'set -uo pipefail', c): return 8
    return 0

def c3_positive(c):
    tests = get_tests(c)
    pos = [t for t in tests if not re.search(NEG_PAT, t, re.I)]
    n = len(pos)
    return 15 if n >= 5 else 10 if n >= 3 else 5 if n >= 1 else 0

def c4_negative(c):
    tests = get_tests(c)
    neg = [t for t in tests if re.search(NEG_PAT, t, re.I)]
    ne = len(re.findall(r'\[\s*"\$status"\s*-ne\s*0\s*\]', c))
    n = max(len(neg), ne)
    return 15 if n >= 4 else 10 if n >= 2 else 5 if n >= 1 else 0

def c5_edge(c):
    tests = get_tests(c)
    n = sum(1 for t in tests if any(re.search(p, t, re.I) for p in EDGE_PAT))
    return 10 if n >= 3 else 5 if n >= 1 else 0

def c6_isolation(c):
    pts = 0
    if re.search(r'setup\s*\(\)', c): pts += 4
    if re.search(r'teardown\s*\(\)', c): pts += 3
    if re.search(r'mktemp|TMPDIR|tmp_dir', c, re.I): pts += 3
    return min(pts, 10)

def c7_coverage(c, target):
    if not target: return 3
    tc = read_file(target)
    funcs = set(re.findall(r'(?:^|\s)(\w+)\s*\(\)\s*\{', tc))
    funcs |= set(re.findall(r'^def\s+(\w+)', tc, re.MULTILINE))
    if not funcs: return 5
    tested = sum(1 for fn in funcs if fn in c)
    r = tested / len(funcs)
    return 10 if r >= 0.8 else 7 if r >= 0.6 else 4 if r >= 0.3 else 2

def c8_spec(c):
    if re.search(r'SPEC-\d+', c): return 10
    if re.search(r'docs/propuestas/', c): return 10
    if re.search(r'#\s*[Rr]ef:', c): return 8
    if re.search(r'\.claude/rules/', c): return 8
    if re.search(r'\.claude/skills/', c): return 7
    return 5 if re.search(r'\[\s*-f.*\.md.*\]', c) else 0

def c9_assertions(c):
    pts = 0
    if re.search(r'\[\[.*\$output.*\]\]', c): pts += 3
    if re.search(r'\[\[.*\*.*\*', c): pts += 2
    if re.search(r'python3.*json\.load', c): pts += 3
    if re.search(r'grep -q', c): pts += 2
    if re.search(r'assert\s+', c): pts += 3
    if re.search(r'\[\s*"\$\w+".*-(?:gt|lt|ge|le|eq|ne)\s', c): pts += 2
    if re.search(r'\[\s*"\$status"', c): pts += 2
    return min(pts, 10)

def audit(test_file, root):
    c = read_file(test_file)
    target = find_target(test_file, root)
    today = date.today().isoformat()
    criteria = {
        "exists_executable": c1_exists(test_file), "safety_verification": c2_safety(c),
        "positive_cases": c3_positive(c), "negative_cases": c4_negative(c),
        "edge_cases": c5_edge(c), "isolation": c6_isolation(c),
        "coverage_breadth": c7_coverage(c, target), "spec_reference": c8_spec(c),
        "assertion_quality": c9_assertions(c),
    }
    total = sum(criteria.values())
    h = hashlib.sha256(f"{os.path.basename(test_file)}{total}{today}".encode()).hexdigest()[:8]
    return {
        "file": os.path.relpath(test_file, root),
        "target": os.path.relpath(target, root) if target else None,
        "test_count": len(get_tests(c)), "criteria": criteria,
        "total": total, "certified": total >= 80, "hash": h, "date": today,
    }

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(json.dumps({"error": "Usage: test-auditor-engine.py <file> <root>"}))
        sys.exit(1)
    print(json.dumps(audit(sys.argv[1], sys.argv[2]), indent=2))
