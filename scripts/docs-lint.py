#!/usr/bin/env python3
"""docs-lint.py — SE-259 Slice 1. Document style linter."""
import json, os, re, sys
from pathlib import Path
from collections import Counter

ROOT = Path(__file__).resolve().parent.parent

# ── Config ──
EMOJI_RE = re.compile(
    r'[\U0001F300-\U0001F9FF]|[\u2600-\u27BF]|[\U0001FA00-\U0001FAFF]|'
    r'\ufe0f|\u200d|[\U0001F600-\U0001F64F]'
)

INFORMAL_ES = [
    r'\bmola\b', r'\bflipa\b', r'\bchulo\b', r'\bguay\b', r'\btocho\b',
    r'\bcurrar\b', r'\bpringar\b', r'\bflipante\b', r'\bmogollón\b',
    r'\bchungo\b', r'\bpetar\b', r'\bmazo\b',
]
INFORMAL_EN = [
    r'\bawesome\b', r'\bcool\b', r'\bneat\b', r'\bsweet\b',
]

EXCLAMATION_RE = re.compile(r'!!+')

LINK_RE = re.compile(r'\[([^\]]*)\]\(([^)]*)\)')
IMG_RE = re.compile(r'!\[([^\]]*)\]\(([^)]*)\)')

SYSTEM_ENTITIES = {
    'hooks': r'\b(\d+)\s+hooks?\b',
    'skills': r'\b(\d+)\s+skills?\b',
    'agents': r'\b(\d+)\s+agents?\b',
    'commands': r'\b(\d+)\s+commands?\b',
    'scripts': r'\b(\d+)\s+scripts?\b',
}

SKIP_DIRS = {'.git', 'node_modules', '.scm', 'output', 'backups',
             'specs-archive', 'CHANGELOG.d'}
SKIP_PREFIX = ('_', '.')
SKIP_EXACT = {'CONSTITUCION.md', 'CRITERIO.md'}
EXEMPT_DIRS = {'commands', 'agents'}  # prompts operativos

RESULT = {'files': 0, 'findings': [], 'by_type': Counter()}

def find_md_files(root):
    files = []
    for p in root.rglob('*.md'):
        rel = p.relative_to(root)
        parts = rel.parts
        if any(d in SKIP_DIRS for d in parts):
            continue
        if any(p.name.startswith(prefix) for prefix in SKIP_PREFIX if p.name not in ('_template',)):
            continue
        if rel.name in SKIP_EXACT:
            continue
        if any(d in EXEMPT_DIRS for d in parts) and not any(
            d in ('docs', 'projects') for d in parts
        ):
            continue
        files.append(p)
    return files

def check_skip(content, check_id):
    return bool(re.search(rf'<!--\s*docs-lint:\s*skip.*\b{check_id}\b', content))

def lint_file(filepath):
    try:
        content = filepath.read_text(encoding='utf-8')
    except Exception:
        return
    rel = str(filepath.relative_to(ROOT))
    RESULT['files'] += 1

    def finding(check_id, severity, msg):
        RESULT['findings'].append({'file': rel, 'severity': severity, 'check': check_id, 'msg': msg})
        RESULT['by_type'][check_id] += 1

    # R1: emojis outside code blocks
    if not check_skip(content, 'R1'):
        lines = content.split('\n')
        in_code = False
        for lineno, line in enumerate(lines, 1):
            if line.strip().startswith('```'):
                in_code = not in_code
                continue
            if in_code:
                continue
            emojis = EMOJI_RE.findall(line)
            if emojis:
                finding('R1', 'WARN', f'line {lineno}: emoji(s) {emojis[:3]}')

    # R2: exclamation marks
    if not check_skip(content, 'R2'):
        for lineno, line in enumerate(content.split('\n'), 1):
            if line.strip().startswith('```'):
                continue
            if EXCLAMATION_RE.search(line):
                finding('R2', 'WARN', f'line {lineno}: double exclamation')

    # R3: informal vocabulary
    if not check_skip(content, 'R3'):
        for lineno, line in enumerate(content.split('\n'), 1):
            if line.strip().startswith('```'):
                continue
            for pat in INFORMAL_ES + INFORMAL_EN:
                if re.search(pat, line, re.IGNORECASE):
                    finding('R3', 'WARN', f'line {lineno}: informal "{pat}"')

    # R4: embedded images
    if not check_skip(content, 'R4'):
        for lineno, line in enumerate(content.split('\n'), 1):
            if line.strip().startswith('```'):
                continue
            imgs = IMG_RE.findall(line)
            for alt, url in imgs:
                if url.startswith('http'):
                    continue
                finding('R4', 'FAIL', f'line {lineno}: embedded image {url}')

    # R5: hardcoded system counts
    if not check_skip(content, 'R5'):
        for entity, pattern in SYSTEM_ENTITIES.items():
            for lineno, line in enumerate(content.split('\n'), 1):
                for m in re.finditer(pattern, line, re.IGNORECASE):
                    count = int(m.group(1))
                    if count > 1:
                        finding('R5', 'WARN', f'line {lineno}: hardcoded {entity} count ({count})')

    # R7: broken internal links
    if not check_skip(content, 'R7'):
        for lineno, line in enumerate(content.split('\n'), 1):
            if line.strip().startswith('```'):
                continue
            links = LINK_RE.findall(line)
            for text, url in links:
                if url.startswith('http') or url.startswith('#'):
                    continue
                if url.startswith('mailto:'):
                    continue
                target = filepath.parent / url.split('#')[0]
                if not target.exists():
                    finding('R7', 'FAIL', f'line {lineno}: broken link to {url}')


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else 'check'
    path = sys.argv[2] if len(sys.argv) > 2 else '.'

    target = ROOT / path
    if target.is_file():
        lint_file(target)
    else:
        for f in find_md_files(target):
            lint_file(f)

    if mode == 'baseline':
        print(json.dumps({
            'files': RESULT['files'],
            'by_type': dict(RESULT['by_type']),
        }, indent=2))
        return

    # Report
    sev_order = {'FAIL': 0, 'WARN': 1}
    findings_sorted = sorted(RESULT['findings'], key=lambda f: (sev_order.get(f['severity'], 99), f['file']))

    if mode in ('json', 'ci'):
        print(json.dumps({
            'files': RESULT['files'],
            'total_findings': len(RESULT['findings']),
            'by_type': dict(RESULT['by_type']),
            'top': findings_sorted[:20],
        }, indent=2))
    else:
        for f in findings_sorted:
            print(f"[{f['severity']}] {f['check']}: {f['file']}: {f['msg']}")
        print(f"\nFiles: {RESULT['files']}, Findings: {len(RESULT['findings'])}")
        for t, c in RESULT['by_type'].most_common():
            print(f"  {t}: {c}")

    fails = sum(1 for f in RESULT['findings'] if f['severity'] == 'FAIL')
    sys.exit(1 if fails > 0 else 0)

if __name__ == '__main__':
    main()
