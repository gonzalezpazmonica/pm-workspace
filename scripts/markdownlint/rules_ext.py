"""Extended markdownlint rules — content, links, and references."""
import re
from .config import in_fenced_block


def md024(linter, fp, lines):
    """MD024: No duplicate heading text (supports siblings_only)."""
    cfg_val = linter.cfg.get("MD024", {})
    siblings_only = isinstance(cfg_val, dict) and cfg_val.get(
        "siblings_only", False)
    headings = []
    for i, line in enumerate(lines):
        if in_fenced_block(lines, i):
            continue
        m = re.match(r'^(#{1,6})\s+(.*?)\s*$', line)
        if m:
            headings.append((i+1, len(m.group(1)), m.group(2)))
    if siblings_only:
        for idx in range(1, len(headings)):
            ln, lvl, txt = headings[idx]
            for prev_idx in range(idx-1, -1, -1):
                _, plvl, ptxt = headings[prev_idx]
                if plvl < lvl:
                    break
                if plvl == lvl and ptxt == txt:
                    linter.add(fp, ln, "MD024", "no-duplicate-heading",
                               "Multiple headings with the same content")
                    break
    else:
        seen = {}
        for ln, _, txt in headings:
            if txt in seen:
                linter.add(fp, ln, "MD024", "no-duplicate-heading",
                           "Multiple headings with the same content")
            else:
                seen[txt] = ln


def md031(linter, fp, lines):
    """MD031: Fenced code blocks should be surrounded by blank lines."""
    in_fence = False
    for i, line in enumerate(lines):
        if re.match(r'^(`{3,}|~{3,})', line):
            if not in_fence:
                if i > 0 and lines[i-1].strip() != '':
                    linter.add(fp, i+1, "MD031", "blanks-around-fences",
                               "Fenced code blocks should be surrounded "
                               "by blank lines")
                in_fence = True
            else:
                if i < len(lines)-1 and lines[i+1].strip() != '':
                    linter.add(fp, i+1, "MD031", "blanks-around-fences",
                               "Fenced code blocks should be surrounded "
                               "by blank lines")
                in_fence = False


def md032(linter, fp, lines):
    """MD032: Lists should be surrounded by blank lines."""
    for i, line in enumerate(lines):
        if in_fenced_block(lines, i):
            continue
        is_list = re.match(r'^(\s*[-*+]|\s*\d+\.)\s', line)
        if not is_list:
            continue
        prev = lines[i-1] if i > 0 else ''
        prev_is_list = re.match(r'^(\s*[-*+]|\s*\d+\.)\s', prev)
        prev_is_blank = prev.strip() == ''
        prev_is_bq = prev.strip().startswith('>')
        if not prev_is_list and not prev_is_blank and not prev_is_bq:
            ctx = line[:35].strip()
            linter.add(fp, i+1, "MD032", "blanks-around-lists",
                       f'Lists should be surrounded by blank lines '
                       f'[Context: "{ctx}..."]')
        if i < len(lines)-1:
            nxt = lines[i+1]
            nxt_is_list = re.match(r'^(\s*[-*+]|\s*\d+\.)\s', nxt)
            nxt_is_blank = nxt.strip() == ''
            nxt_is_cont = nxt.startswith('  ')
            if not nxt_is_list and not nxt_is_blank and not nxt_is_cont:
                ctx = line[:35].strip()
                linter.add(fp, i+1, "MD032", "blanks-around-lists",
                           f'Lists should be surrounded by blank lines '
                           f'[Context: "{ctx}..."]')


def md034(linter, fp, lines):
    """MD034: No bare URLs."""
    url_re = re.compile(r'(?<!\(|<|\[)https?://[^\s)>\]]+')
    for i, line in enumerate(lines):
        if in_fenced_block(lines, i):
            continue
        if re.match(r'^\[.*\]:\s', line):
            continue
        if line.strip().startswith('>'):
            continue
        for m in url_re.finditer(line):
            start = m.start()
            if start > 0 and line[start-1] in '(<':
                continue
            linter.add(fp, i+1, "MD034", "no-bare-urls", "Bare URL used")


def md040(linter, fp, lines):
    """MD040: Fenced code blocks should have a language specified."""
    in_fence = False
    for i, line in enumerate(lines):
        if re.match(r'^(`{3,}|~{3,})', line):
            if not in_fence:
                stripped = re.sub(r'^(`{3,}|~{3,})', '', line).strip()
                if not stripped:
                    linter.add(fp, i+1, "MD040", "fenced-code-language",
                               "Fenced code blocks should have a language "
                               "specified")
                in_fence = True
            else:
                in_fence = False


def md047(linter, fp, content):
    """MD047: Files should end with a single newline."""
    if content and not content.endswith('\n'):
        linter.add(fp, len(content.split('\n')), "MD047",
                   "single-trailing-newline",
                   "Files should end with a single newline character")


def md053(linter, fp, lines):
    """MD053: Link/image reference definitions should be needed."""
    refs = {}
    for i, line in enumerate(lines):
        m = re.match(r'^\[([^\]]+)\]:\s', line)
        if m:
            ref = m.group(1).lower()
            if ref in refs:
                linter.add(fp, i+1, "MD053",
                           "link-image-reference-definitions",
                           f'Duplicate link or image reference definition: '
                           f'"{m.group(1)}"')
            else:
                refs[ref] = i+1
