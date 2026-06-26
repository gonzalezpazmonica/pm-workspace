#!/usr/bin/env python3
"""
code-twin-generate.py — SPEC-190 MVP (AC-7, AC-8)

Generates Code Twin Files (CTFs) from a single source file.
Thin wrapper around code-twin-extract.py for single-file use.

Usage:
  python3 scripts/code-twin-generate.py --file <path> --output <dir>
                                          [--lang <python|typescript|csharp>]
                                          [--module <module_name>]

Exit codes:
  0 — CTF generated successfully
  1 — no extractable content found
  2 — argument / IO error
"""

import sys
import os
import re
import ast
import argparse
import pathlib
from datetime import date
from typing import Optional

TODAY = date.today().isoformat()

VALID_LAYERS = {"domain", "application", "infrastructure", "api", "frontend", "cross-cutting", "meta"}

# ---------------------------------------------------------------------------
# Language detection
# ---------------------------------------------------------------------------

def detect_language(filepath: str) -> Optional[str]:
    ext = pathlib.Path(filepath).suffix.lower()
    if ext in (".py",):
        return "python"
    if ext in (".ts", ".tsx", ".js", ".jsx"):
        return "typescript"
    if ext in (".cs",):
        return "csharp"
    return None

# ---------------------------------------------------------------------------
# Layer inference helpers
# ---------------------------------------------------------------------------

TS_DECORATOR_LAYER = {
    "injectable": "application",
    "controller": "api",
    "component": "frontend",
    "pipe": "application",
    "guard": "application",
    "interceptor": "application",
    "resolver": "api",
    "module": "application",
    "service": "application",
}

CS_NS_LAYER_DEFAULTS = {
    "domain": "domain",
    "application": "application",
    "infrastructure": "infrastructure",
    "api": "api",
    "web": "api",
    "controllers": "api",
    "frontend": "frontend",
    "services": "application",
    "repositories": "infrastructure",
}


def _infer_layer_from_path(filepath: str) -> str:
    parts = pathlib.Path(filepath).parts
    for part in parts:
        low = part.lower()
        if low in VALID_LAYERS:
            return low
        for key, layer in CS_NS_LAYER_DEFAULTS.items():
            if key in low:
                return layer
    return "application"

# ---------------------------------------------------------------------------
# Python extractor
# ---------------------------------------------------------------------------

def _extract_python(source: str, filepath: str):
    try:
        tree = ast.parse(source)
    except SyntaxError:
        return None, [], []

    classes = []
    imports = []

    for node in ast.walk(tree):
        if isinstance(node, (ast.Import, ast.ImportFrom)):
            if isinstance(node, ast.Import):
                for alias in node.names:
                    imports.append(alias.name.split(".")[0])
            else:
                if node.module:
                    imports.append(node.module.split(".")[0])

        if isinstance(node, ast.ClassDef):
            methods = []
            for item in node.body:
                if isinstance(item, ast.FunctionDef) and not item.name.startswith("_"):
                    args = [a.arg for a in item.args.args if a.arg != "self"]
                    # Collect return annotation
                    ret = ""
                    if item.returns:
                        ret = f" -> {ast.unparse(item.returns)}"
                    sig = f"{item.name}({', '.join(args)}){ret}"
                    methods.append(sig)
            classes.append((node.name, methods))

    return _infer_layer_from_path(filepath), classes, list(set(imports))

# ---------------------------------------------------------------------------
# TypeScript/JavaScript extractor
# ---------------------------------------------------------------------------

def _extract_typescript(source: str, filepath: str):
    classes = []
    imports = []

    # Extract imports
    for m in re.finditer(r"import\s+.*?from\s+['\"]([^'\"]+)['\"]", source):
        mod = m.group(1).split("/")[0].lstrip("@")
        if not mod.startswith("."):
            imports.append(mod)

    # Detect decorators on classes
    class_pattern = re.compile(
        r"(@(?P<dec>\w+)[^)]*\)\s*\n)?(?:export\s+)?(?:abstract\s+)?class\s+(?P<name>\w+)",
        re.MULTILINE,
    )

    method_pattern = re.compile(
        r"(?:async\s+)?(?P<name>\w+)\s*\((?P<args>[^)]*)\)\s*(?::\s*(?P<ret>[^{;]+))?\s*[{;]",
        re.MULTILINE,
    )

    for cm in class_pattern.finditer(source):
        class_name = cm.group("name")
        dec_raw = cm.group("dec") or ""
        dec = dec_raw.lower()

        layer = TS_DECORATOR_LAYER.get(dec, "application")
        if not dec:
            layer = _infer_layer_from_path(filepath)

        # Find methods in class body (heuristic: find block after class declaration)
        start = cm.end()
        # Gather up to 3000 chars of class body
        block = source[start : start + 3000]
        methods = []
        seen = set()
        for mm in method_pattern.finditer(block):
            mname = mm.group("name")
            if mname in ("if", "for", "while", "return", "const", "let", "var", "new"):
                continue
            if mname in seen:
                continue
            seen.add(mname)
            args_raw = mm.group("args") or ""
            args_clean = re.sub(r":[^,)]+", "", args_raw).strip()
            ret_raw = (mm.group("ret") or "").strip().rstrip("{").strip()
            sig = f"{mname}({args_clean})"
            if ret_raw and len(ret_raw) < 40:
                sig += f": {ret_raw}"
            methods.append(sig)
            if len(methods) >= 8:
                break

        classes.append((class_name, methods, layer))

    return classes, list(set(imports))

# ---------------------------------------------------------------------------
# C# extractor
# ---------------------------------------------------------------------------

def _extract_csharp(source: str, filepath: str):
    classes = []
    imports = []

    # Extract using directives
    for m in re.finditer(r"^using\s+([\w.]+);", source, re.MULTILINE):
        ns = m.group(1).split(".")[0]
        imports.append(ns)

    # Detect namespace → layer
    ns_layer = _infer_layer_from_path(filepath)
    for m in re.finditer(r"^namespace\s+([\w.]+)", source, re.MULTILINE):
        parts = m.group(1).lower().split(".")
        for part in parts:
            if part in CS_NS_LAYER_DEFAULTS:
                ns_layer = CS_NS_LAYER_DEFAULTS[part]
                break

    # Find classes
    class_pattern = re.compile(
        r"(?:public|internal|protected|private)?\s+(?:(?:abstract|sealed|static|partial)\s+)*class\s+(\w+)",
        re.MULTILINE,
    )

    method_pattern = re.compile(
        r"(?:public|protected|internal|private|static|virtual|override|async)\s+"
        r"(?:(?:static|virtual|override|async)\s+)*"
        r"[\w<>\[\]?]+\s+(\w+)\s*\(([^)]*)\)",
        re.MULTILINE,
    )

    for cm in class_pattern.finditer(source):
        class_name = cm.group(1)
        start = cm.end()
        block = source[start : start + 3000]
        methods = []
        seen = set()
        for mm in method_pattern.finditer(block):
            mname = mm.group(1)
            if mname in seen or mname in ("if", "for", "while", "new", "class"):
                continue
            seen.add(mname)
            args_raw = mm.group(2) or ""
            # Simplify args: keep only names (no types for brevity)
            args_simplified = ", ".join(
                p.split()[-1] if len(p.split()) > 1 else p
                for p in (a.strip() for a in args_raw.split(","))
                if p.strip()
            )
            methods.append(f"{mname}({args_simplified})")
            if len(methods) >= 8:
                break

        classes.append((class_name, methods, ns_layer))

    return classes, list(set(imports))

# ---------------------------------------------------------------------------
# CTF renderer
# ---------------------------------------------------------------------------

def render_ctf(class_name: str, methods: list, layer: str, filepath: str,
               imports: list, module: Optional[str] = None) -> str:
    module_id = module or class_name
    rel_path = filepath
    token_estimate = min(600, 100 + len(methods) * 40 + len(imports) * 5)

    provides_lines = "\n".join(f"  - {m.split('(')[0]}" for m in methods) or "  - (none)"
    deps_lines = "\n".join(f"  - {i}" for i in imports[:6]) if imports else "  []"
    if not imports:
        deps_block = "depends_on: []"
    else:
        deps_block = f"depends_on:\n{deps_lines}"

    method_table = ""
    if methods:
        method_table = "\n## Functions / Methods\n\n"
        method_table += "| Signature | Notes |\n|-----------|-------|\n"
        for m in methods:
            method_table += f"| `{m}` | |\n"

    return f"""---
module_id: {module_id}
layer: {layer}
version: "1.0.0"
last_sync: "{TODAY}"
token_budget: {token_estimate}
{deps_block}
provides:
{provides_lines}
stale_after_days: 7
status: STABLE
---
# {module_id}

**Source**: `{rel_path}`
**Language**: {_lang_label(filepath)}
{method_table}
"""


def _lang_label(filepath: str) -> str:
    ext = pathlib.Path(filepath).suffix.lower()
    return {"py": "Python", "ts": "TypeScript", "tsx": "TypeScript", "js": "JavaScript",
            "jsx": "JavaScript", "cs": "C#"}.get(ext.lstrip("."), "unknown")

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def parse_args():
    p = argparse.ArgumentParser(description="Generate Code Twin File from a source file")
    p.add_argument("--file", required=True, help="Source file to process")
    p.add_argument("--output", required=True, help="Output directory for CTF(s)")
    p.add_argument("--lang", choices=["python", "typescript", "csharp"],
                   help="Language override (auto-detected if omitted)")
    p.add_argument("--module", help="Module name override")
    return p.parse_args()


def main():
    args = parse_args()

    if not os.path.isfile(args.file):
        print(f"ERROR: source file not found: {args.file}", file=sys.stderr)
        sys.exit(2)

    lang = args.lang or detect_language(args.file)
    if not lang:
        print(f"ERROR: cannot detect language for: {args.file}", file=sys.stderr)
        sys.exit(2)

    source = pathlib.Path(args.file).read_text(encoding="utf-8", errors="replace")

    generated = []

    if lang == "python":
        layer, classes, imports = _extract_python(source, args.file)
        if layer is None or not classes:
            print("WARN: no extractable classes found in Python file", file=sys.stderr)
            sys.exit(1)
        for class_name, methods in classes:
            ctf = render_ctf(class_name, methods, layer, args.file, imports, args.module)
            out_path = os.path.join(args.output, f"{class_name}.md")
            os.makedirs(args.output, exist_ok=True)
            pathlib.Path(out_path).write_text(ctf, encoding="utf-8")
            generated.append(out_path)
            print(f"OK: generated {out_path}")

    elif lang == "typescript":
        classes, imports = _extract_typescript(source, args.file)
        if not classes:
            print("WARN: no extractable classes found in TypeScript file", file=sys.stderr)
            sys.exit(1)
        for class_name, methods, layer in classes:
            ctf = render_ctf(class_name, methods, layer, args.file, imports, args.module)
            out_path = os.path.join(args.output, f"{class_name}.md")
            os.makedirs(args.output, exist_ok=True)
            pathlib.Path(out_path).write_text(ctf, encoding="utf-8")
            generated.append(out_path)
            print(f"OK: generated {out_path}")

    elif lang == "csharp":
        classes, imports = _extract_csharp(source, args.file)
        if not classes:
            print("WARN: no extractable classes found in C# file", file=sys.stderr)
            sys.exit(1)
        for class_name, methods, layer in classes:
            ctf = render_ctf(class_name, methods, layer, args.file, imports, args.module)
            out_path = os.path.join(args.output, f"{class_name}.md")
            os.makedirs(args.output, exist_ok=True)
            pathlib.Path(out_path).write_text(ctf, encoding="utf-8")
            generated.append(out_path)
            print(f"OK: generated {out_path}")

    if not generated:
        sys.exit(1)
    sys.exit(0)


if __name__ == "__main__":
    main()
