"""Markdownlint rules — based on DavidAnson/markdownlint specs."""
import re
from .config import in_fenced_block
from . import rules_ext


class Linter:
    def __init__(self, cfg):
        self.cfg = cfg
        self.errors = []

    def add(self, filepath, line, rule, alias, msg):
        self.errors.append((filepath, line, rule, alias, msg))

    def lint(self, filepath, content):
        from .config import is_enabled
        lines = content.split('\n')
        rule_map = {
            "MD003": self._md003, "MD009": self._md009,
            "MD010": self._md010, "MD012": self._md012,
            "MD018": self._md018, "MD019": self._md019,
            "MD022": self._md022, "MD023": self._md023,
            "MD024": lambda fp, l: rules_ext.md024(self, fp, l),
            "MD025": self._md025,
            "MD026": self._md026,
            "MD031": lambda fp, l: rules_ext.md031(self, fp, l),
            "MD032": lambda fp, l: rules_ext.md032(self, fp, l),
            "MD034": lambda fp, l: rules_ext.md034(self, fp, l),
            "MD040": lambda fp, l: rules_ext.md040(self, fp, l),
            "MD053": lambda fp, l: rules_ext.md053(self, fp, l),
        }
        for rule_id, fn in rule_map.items():
            if is_enabled(self.cfg, rule_id):
                fn(filepath, lines)
        if is_enabled(self.cfg, "MD047"):
            rules_ext.md047(self, filepath, content)

    def _md003(self, fp, lines):
        for i, line in enumerate(lines):
            if in_fenced_block(lines, i):
                continue
            if i > 0 and re.match(r'^[=-]+\s*$', line) and lines[i-1].strip():
                self.add(fp, i+1, "MD003", "heading-style",
                         "Heading style [Expected: atx; Actual: setext]")

    def _md009(self, fp, lines):
        for i, line in enumerate(lines):
            if in_fenced_block(lines, i):
                continue
            if line.endswith(' ') or line.endswith('\t'):
                self.add(fp, i+1, "MD009", "no-trailing-spaces",
                         "Trailing spaces")

    def _md010(self, fp, lines):
        for i, line in enumerate(lines):
            if in_fenced_block(lines, i):
                continue
            if '\t' in line:
                self.add(fp, i+1, "MD010", "no-hard-tabs", "Hard tabs")

    def _md012(self, fp, lines):
        blank_count = 0
        for i, line in enumerate(lines):
            if in_fenced_block(lines, i):
                blank_count = 0
                continue
            if line.strip() == '':
                blank_count += 1
                if blank_count > 1:
                    self.add(fp, i+1, "MD012", "no-multiple-blanks",
                             "Multiple consecutive blank lines")
            else:
                blank_count = 0

    def _md018(self, fp, lines):
        for i, line in enumerate(lines):
            if in_fenced_block(lines, i):
                continue
            if re.match(r'^(#{1,6})([^#\s])', line):
                self.add(fp, i+1, "MD018", "no-missing-space-atx",
                         "No space after hash on atx style heading")

    def _md019(self, fp, lines):
        for i, line in enumerate(lines):
            if in_fenced_block(lines, i):
                continue
            if re.match(r'^#{1,6}\s{2,}', line):
                self.add(fp, i+1, "MD019", "no-multiple-space-atx",
                         "Multiple spaces after hash on atx style heading")

    def _md022(self, fp, lines):
        for i, line in enumerate(lines):
            if in_fenced_block(lines, i):
                continue
            if not re.match(r'^#{1,6}\s', line):
                continue
            if i > 0 and lines[i-1].strip() != '':
                self.add(fp, i+1, "MD022", "blanks-around-headings",
                         "Headings should be surrounded by blank lines "
                         "[Expected: 1; Actual: 0; Above]")
            if i < len(lines)-1 and lines[i+1].strip() != '':
                self.add(fp, i+1, "MD022", "blanks-around-headings",
                         "Headings should be surrounded by blank lines "
                         "[Expected: 1; Actual: 0; Below]")

    def _md023(self, fp, lines):
        for i, line in enumerate(lines):
            if in_fenced_block(lines, i):
                continue
            if re.match(r'^\s+#{1,6}\s', line):
                self.add(fp, i+1, "MD023", "heading-start-left",
                         "Headings must start at the beginning of the line")

    def _md025(self, fp, lines):
        h1_count = 0
        for i, line in enumerate(lines):
            if in_fenced_block(lines, i):
                continue
            if re.match(r'^#\s', line):
                h1_count += 1
                if h1_count > 1:
                    self.add(fp, i+1, "MD025", "single-title/single-h1",
                             "Multiple top-level headings in the same document")

    def _md026(self, fp, lines):
        for i, line in enumerate(lines):
            if in_fenced_block(lines, i):
                continue
            m = re.match(r'^#{1,6}\s+(.*?)\s*$', line)
            if m and m.group(1) and m.group(1)[-1] in '.,:;!':
                self.add(fp, i+1, "MD026", "no-trailing-punctuation",
                         f"Trailing punctuation in heading "
                         f"[Punctuation: '{m.group(1)[-1]}']")

