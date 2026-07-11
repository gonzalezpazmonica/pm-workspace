#!/usr/bin/env python3
"""docs-tone-rewrite.py — SE-259 Slice 5. Remove emojis and informal vocab."""
import re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DOCS = ROOT / 'docs'

# ── Emoji → ASCII replacements ──
EMOJI_MAP = {
    '✅': 'OK',
    '❌': 'FAIL',
    '⚠️': 'WARN',
    '🚀': '',
    '🔥': '',
    '💡': '',
    '📌': '',
    '📋': '',
    '📊': '',
    '📁': '',
    '📄': '',
    '📝': '',
    '🔍': '',
    '🔒': '',
    '🔑': '',
    '🗂️': '',
    '📎': '',
    '🔗': '',
    '⭐': '',
    '🎯': '',
    '💪': '',
    '👀': '',
    '✨': '',
    '🎉': '',
    '🏆': '',
    '📈': '',
    '📉': '',
    '⚡': '',
    '🛡️': '',
    '🧠': '',
    '🤖': '',
    '🗣️': '',
    '👥': '',
    '📢': '',
    '📭': '',
    '📬': '',
    '🟢': 'OK',
    '🔴': 'FAIL',
    '🟡': 'WARN',
    '🔵': '',
    '🟠': '',
    '⏱️': '',
    '⏰': '',
    '⌛': '',
    '💾': '',
    '🔄': '',
    '♻️': '',
    '➕': '+',
    '➖': '-',
    '✏️': '',
    '🧹': '',
    '🧪': '',
    '🔧': '',
    '🛠️': '',
    '📦': '',
    '🎨': '',
    '🧩': '',
    '🔌': '',
    '💻': '',
    '🖥️': '',
    '⌨️': '',
    '🖱️': '',
    '📱': '',
    '📶': '',
    '🌐': '',
    '🏗️': '',
    '🧱': '',
    '📐': '',
    '📏': '',
    '✂️': '',
    '🧵': '',
    '🧷': '',
    '📌': '',
    '📍': '',
    '🏷️': '',
    '📛': '',
    '🔖': '',
    '📑': '',
    '🗒️': '',
    '📒': '',
    '📓': '',
    '📔': '',
    '📕': '',
    '📗': '',
    '📘': '',
    '📙': '',
    '📚': '',
    '🔬': '',
    '🔭': '',
    '📡': '',
    '💉': '',
    '💊': '',
    '🩺': '',
    '🩹': '',
    '🧬': '',
    '🧫': '',
    '🧪': '',
    '🌡️': '',
    '🧯': '',
    '🧰': '',
    '🧲': '',
    '🔨': '',
    '⚒️': '',
    '🪓': '',
    '⛏️': '',
    '⚙️': '',
    '🗜️': '',
    '🔩': '',
    '⛓️': '',
    '🧿': '',
    '📿': '',
    '🏁': '',
    '🚩': '',
    '🎌': '',
    '🏴': '',
    '🏳️': '',
    '🏳️‍🌈': '',
    '🏳️‍⚧️': '',
    '🔰': '',
    '💠': '',
    '♨️': '',
    '💮': '',
    '💯': '',
    '💥': '',
    '💫': '',
    '💦': '',
    '💨': '',
    '🕳️': '',
    '💢': '',
    '💤': '',
    '🌀': '',
    '🌿': '',
    '🍃': '',
    '🌱': '',
    '🌳': '',
    '🌲': '',
    '🎄': '',
    '🌻': '',
    '🌸': '',
    '💐': '',
    '🌹': '',
    '🥀': '',
    '🌺': '',
    '🌷': '',
    '⚜️': '',
    '🔱': '',
    '📯': '',
    '🎺': '',
    '🎷': '',
    '🥁': '',
    '🎸': '',
    '🎻': '',
    '🎹': '',
    '🎼': '',
    '🎵': '',
    '🎶': '',
    '〽️': '',
    '➕': '+',
    '➖': '-',
    '➗': '/',
    '✖️': 'x',
    '✔️': 'OK',
    '☑️': 'OK',
    '✅': 'OK',
    '❎': 'FAIL',
    '⭕': '',
    '❓': '',
    '❔': '',
    '❗': '',
    '❕': '',
    '‼️': '',
    '⁉️': '',
    '〰️': '',
    '©️': '(c)',
    '®️': '(R)',
    '™️': '(TM)',
    '🔟': '10',
    '💯': '100',
}

# ── Informal → formal replacements ──
INFORMAL_MAP_ES = {
    'mola': 'destaca',
    'flipa': 'sorprende',
    'chulo': 'util',
    'guay': 'recomendable',
    'tocho': 'extenso',
    'currar': 'trabajar',
    'pringar': 'implicarse',
    'flipante': 'notable',
    'mogollón': 'gran cantidad',
    'chungo': 'complejo',
    'petar': 'fallar',
    'mazo': 'muy',
}
INFORMAL_MAP_EN = {
    'awesome': 'excellent',
    'cool': 'useful',
    'neat': 'clean',
    'sweet': 'convenient',
}

def remove_emojis(text):
    result = text
    for emoji, replacement in sorted(EMOJI_MAP.items(), key=lambda x: -len(x[0])):
        result = result.replace(emoji, replacement)
    # Also match any remaining emoji via regex
    emoji_pattern = re.compile(
        r'[\U0001F300-\U0001F9FF]|[\u2600-\u27BF]|[\U0001FA00-\U0001FAFF]|'
        r'\ufe0f|\u200d|[\U0001F600-\U0001F64F]'
    )
    # Don't remove inside code blocks
    lines = result.split('\n')
    in_code = False
    out = []
    for line in lines:
        if line.strip().startswith('```'):
            in_code = not in_code
            out.append(line)
            continue
        if not in_code:
            line = emoji_pattern.sub('', line)
        out.append(line)
    return '\n'.join(out)

def fix_informal(text):
    result = text
    for informal, formal in {**INFORMAL_MAP_ES, **INFORMAL_MAP_EN}.items():
        result = re.sub(rf'\b{informal}\b', formal, result, flags=re.IGNORECASE)
    return result

def process_file(filepath):
    try:
        original = filepath.read_text(encoding='utf-8')
    except Exception:
        return False

    modified = original
    modified = remove_emojis(modified)
    modified = fix_informal(modified)

    if modified != original:
        filepath.write_text(modified, encoding='utf-8')
        return True
    return False

def main():
    target = sys.argv[1] if len(sys.argv) > 1 else 'docs/'
    path = ROOT / target
    changed = 0
    files = 0

    if path.is_file():
        if process_file(path):
            changed += 1
        files = 1
    else:
        for f in sorted(path.rglob('*.md')):
            files += 1
            if process_file(f):
                changed += 1

    print(f'Files scanned: {files}')
    print(f'Files changed: {changed}')
    return 0

if __name__ == '__main__':
    sys.exit(main())
