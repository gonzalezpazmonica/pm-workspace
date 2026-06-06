#!/usr/bin/env python3
"""
code-twin-extract.py — SPEC-190 Slice 7

AST-light extractor: reads source files and generates Code Twin Files (CTFs).
Supports TypeScript, C#, and Python.

Usage:
  python3 scripts/code-twin-extract.py --lang <typescript|csharp|python>
                                        --src <source_dir>
                                        --out <output_dir>
                                        [--arch <architecture_md>]

Exit codes:
  0 — extraction successful (≥1 CTF generated)
  1 — no extractable classes found
  2 — argument / IO error
"""

import sys
import os
import re
import ast
import json
import argparse
import pathlib
from datetime import date
from typing import Optional

TODAY = date.today().isoformat()

# ---------------------------------------------------------------------------
# Layer inference
# ---------------------------------------------------------------------------

# TypeScript: decorator → layer
TS_DECORATOR_LAYER = {
    "injectable": "application",
    "controller": "api",
    "component":  "frontend",
    "pipe":       "application",
    "guard":      "application",
    "interceptor": "application",
    "resolver":   "api",
    "module":     "application",
}

# C# default namespace-segment → layer
CS_NS_LAYER_DEFAULTS = {
    "domain":         "domain",
    "application":    "application",
    "infrastructure": "infrastructure",
    "api":            "api",
    "controllers":    "api",
    "web":            "api",
    "frontend":       "frontend",
    "core":           "domain",
    "services":       "application",
    "entities":       "domain",
    "repositories":   "infrastructure",
}

VALID_LAYERS = {"domain", "application", "infrastructure", "api", "frontend", "cross-cutting"}


def infer_layer_from_path(path: str) -> str:
    """Fallback: infer layer from directory path segments."""
    parts = pathlib.Path(path).parts
    for part in reversed(parts):
        lower = part.lower()
        for key, layer in CS_NS_LAYER_DEFAULTS.items():
            if key in lower:
                return layer
    return "application"


# ---------------------------------------------------------------------------
# Slug helpers
# ---------------------------------------------------------------------------

def to_slug(name: str) -> str:
    """CamelCase / PascalCase → kebab-case slug."""
    s = re.sub(r'([A-Z]+)([A-Z][a-z])', r'\1-\2', name)
    s = re.sub(r'([a-z\d])([A-Z])', r'\1-\2', s)
    return s.lower().replace('_', '-').replace(' ', '-')


# ---------------------------------------------------------------------------
# CTF rendering
# ---------------------------------------------------------------------------

def render_ctf(module_id: str, layer: str, rel_path: str, methods: list,
               depends_on: list, provides: list) -> str:
    """Render a CTF markdown string."""
    token_estimate = 80 + len(methods) * 90
    token_budget = min(token_estimate, 780)

    frontmatter = f"""---
module_id: {module_id}
layer: {layer}
version: 1.0.0
last_sync: {TODAY}
token_budget: {token_budget}
depends_on:
{chr(10).join('  - ' + d for d in depends_on) if depends_on else '  []'}
provides:
{chr(10).join('  - ' + p for p in provides)}
stale_after_days: 7
status: DRAFT
---"""

    body_lines = [f"# {module_id}\n", f"**Layer**: {layer}  \n**Source**: `{rel_path}`\n"]
    for m in methods[:8]:  # cap at 8 to stay within token_budget
        body_lines.append(f"\n#### {m['signature']}\n")
        body_lines.append("**Logic**:\n")
        for i, step in enumerate(m.get("steps", ["1. — extracted from source"]), 1):
            body_lines.append(f"{i}. {step}\n")
        if m.get("returns"):
            body_lines.append(f"\n**Returns**: `{m['returns']}`\n")

    return frontmatter + "\n\n" + "".join(body_lines)


def write_ctf(out_dir: str, layer: str, slug: str, content: str) -> str:
    layer_dir = os.path.join(out_dir, layer)
    os.makedirs(layer_dir, exist_ok=True)
    path = os.path.join(layer_dir, f"{slug}.md")
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)
    return path


# ---------------------------------------------------------------------------
# TypeScript extractor
# ---------------------------------------------------------------------------

_TS_CLASS_RE = re.compile(
    r'@(\w+)(?:\([^)]*\))?\s*(?:@\w+(?:\([^)]*\))?\s*)*export\s+(?:abstract\s+)?class\s+(\w+)',
    re.MULTILINE,
)
_TS_METHOD_RE = re.compile(
    r'(?:async\s+)?(\w+)\s*\(([^)]*)\)\s*(?::\s*([^\{;]+?))?\s*\{',
    re.MULTILINE,
)
_TS_DECORATOR_SKIP = {"get", "post", "put", "delete", "patch", "input", "output",
                      "inject", "useguards", "apibody", "param", "query", "body",
                      "authorize", "httpget", "httppost", "httpdelete", "httpput",
                      "fromquery", "frombody", "fromroute"}
_TS_METHOD_SKIP = {"constructor", "ngOnInit", "ngOnDestroy", "ngAfterViewInit",
                   "setup", "teardown", "describe", "it", "test", "beforeEach",
                   "afterEach", "beforeAll", "afterAll"}


def extract_typescript(src_dir: str, out_dir: str, rel_base: str = "") -> list:
    """Extract CTFs from TypeScript source files."""
    generated = []
    src_path = pathlib.Path(src_dir)

    for ts_file in sorted(src_path.rglob("*.ts")):
        if any(p in ts_file.parts for p in ("node_modules", "__tests__", "dist", ".git")):
            continue
        if ts_file.name.endswith((".spec.ts", ".test.ts", ".d.ts")):
            continue

        content = ts_file.read_text(encoding="utf-8", errors="ignore")
        rel = str(ts_file.relative_to(src_path)) if not rel_base else \
              os.path.join(rel_base, str(ts_file.relative_to(src_path)))

        # Find all decorated classes
        classes = list(_TS_CLASS_RE.finditer(content))
        if not classes:
            continue

        for m in classes:
            decorator_raw = m.group(1).lower()
            class_name = m.group(2)
            layer = TS_DECORATOR_LAYER.get(decorator_raw)
            if not layer:
                continue

            # Extract methods from the class body (simple heuristic)
            class_start = m.start()
            # Find class body: everything after the opening brace
            brace_pos = content.find("{", class_start)
            if brace_pos < 0:
                continue
            # Find matching closing brace
            depth = 0
            class_end = len(content)
            for i, ch in enumerate(content[brace_pos:], brace_pos):
                if ch == "{":
                    depth += 1
                elif ch == "}":
                    depth -= 1
                    if depth == 0:
                        class_end = i
                        break
            class_body = content[brace_pos:class_end]

            methods = []
            for mm in _TS_METHOD_RE.finditer(class_body):
                mname = mm.group(1)
                if mname in _TS_METHOD_SKIP or mname[0].isupper():
                    continue
                params = mm.group(2).strip()
                ret = (mm.group(3) or "").strip().rstrip("{").strip()
                sig = f"{mname}({_clean_params(params)}){': ' + ret if ret else ''}"
                methods.append({
                    "signature": sig,
                    "returns": ret or "void",
                    "steps": [f"— implementation extracted from `{ts_file.name}`"],
                })

            if not methods:
                # Add a placeholder so the CTF is still valid (≥1 entry)
                methods.append({
                    "signature": f"{class_name.lower()}()",
                    "returns": "void",
                    "steps": ["— no public methods detected; review source"],
                })

            provides = [m2["signature"].split("(")[0] for m2 in methods[:8]]
            content_md = render_ctf(
                module_id=class_name,
                layer=layer,
                rel_path=rel,
                methods=methods,
                depends_on=[],
                provides=provides,
            )
            slug = to_slug(class_name)
            path = write_ctf(out_dir, layer, slug, content_md)
            generated.append({"module_id": class_name, "layer": layer, "path": path})

    return generated


def _clean_params(params: str) -> str:
    """Collapse decorator annotations like @Param('id') id: string → id: string."""
    params = re.sub(r'@\w+\([^)]*\)\s*', '', params)
    return params.strip()


# ---------------------------------------------------------------------------
# C# extractor
# ---------------------------------------------------------------------------

_CS_NS_RE = re.compile(r'^(?:namespace\s+)([\w.]+)', re.MULTILINE)
_CS_CLASS_RE = re.compile(
    r'public\s+(?:abstract\s+|sealed\s+|static\s+)?class\s+(\w+)',
    re.MULTILINE,
)
_CS_METHOD_RE = re.compile(
    r'public\s+(?:async\s+)?(?:static\s+)?(?:override\s+)?([\w<>\[\]?,\s]+?)\s+(\w+)\s*\(([^)]*)\)',
    re.MULTILINE,
)
_CS_SKIP_METHODS = {"ToString", "GetHashCode", "Equals", "GetType", "MemberwiseClone"}


def _load_arch_ns_map(arch_md: Optional[str]) -> dict:
    """Parse namespace_to_layer table from meta/architecture.md if present."""
    if not arch_md or not os.path.isfile(arch_md):
        return {}
    content = pathlib.Path(arch_md).read_text(encoding="utf-8", errors="ignore")
    result = {}
    in_table = False
    for line in content.splitlines():
        if "namespace_to_layer" in line.lower():
            in_table = True
        if in_table and "|" in line:
            parts = [p.strip() for p in line.split("|") if p.strip()]
            if len(parts) >= 2 and not parts[0].startswith("-"):
                result[parts[0].lower()] = parts[1].lower()
    return result


def _infer_cs_layer(namespace: str, ns_map: dict) -> str:
    ns_lower = namespace.lower()
    # Check custom map first (longest match wins)
    for key in sorted(ns_map.keys(), key=len, reverse=True):
        if key in ns_lower:
            layer = ns_map[key]
            if layer in VALID_LAYERS:
                return layer
    # Default segment matching
    for seg in reversed(namespace.split(".")):
        layer = CS_NS_LAYER_DEFAULTS.get(seg.lower())
        if layer:
            return layer
    return "application"


def extract_csharp(src_dir: str, out_dir: str, arch_md: Optional[str] = None,
                   rel_base: str = "") -> list:
    """Extract CTFs from C# source files."""
    generated = []
    src_path = pathlib.Path(src_dir)
    ns_map = _load_arch_ns_map(arch_md)

    for cs_file in sorted(src_path.rglob("*.cs")):
        if any(p in cs_file.parts for p in ("obj", "bin", ".git")):
            continue

        content = cs_file.read_text(encoding="utf-8", errors="ignore")
        rel = str(cs_file.relative_to(src_path)) if not rel_base else \
              os.path.join(rel_base, str(cs_file.relative_to(src_path)))

        # Find namespace
        ns_match = _CS_NS_RE.search(content)
        namespace = ns_match.group(1) if ns_match else ""
        layer = _infer_cs_layer(namespace, ns_map) if namespace else \
                infer_layer_from_path(str(cs_file))

        # Find classes
        for class_match in _CS_CLASS_RE.finditer(content):
            class_name = class_match.group(1)
            if class_name in ("Program", "Startup", "DbContext", "Migrations"):
                continue

            methods = []
            for mm in _CS_METHOD_RE.finditer(content):
                mname = mm.group(2)
                if mname in _CS_SKIP_METHODS or mname == class_name:
                    continue
                ret_type = mm.group(1).strip()
                params = mm.group(3).strip()
                sig = f"{mname}({_clean_cs_params(params)}): {ret_type}"
                methods.append({
                    "signature": sig,
                    "returns": ret_type,
                    "steps": [f"— implementation extracted from `{cs_file.name}`"],
                })

            if not methods:
                methods.append({
                    "signature": f"{class_name}()",
                    "returns": "void",
                    "steps": ["— no public methods detected; review source"],
                })

            provides = [m["signature"].split("(")[0] for m in methods[:8]]
            content_md = render_ctf(
                module_id=class_name,
                layer=layer,
                rel_path=rel,
                methods=methods,
                depends_on=[],
                provides=provides,
            )
            slug = to_slug(class_name)
            path = write_ctf(out_dir, layer, slug, content_md)
            generated.append({"module_id": class_name, "layer": layer, "path": path})

    return generated


def _clean_cs_params(params: str) -> str:
    """Strip C# attributes like [FromBody] from params."""
    params = re.sub(r'\[[\w\(\)]+\]\s*', '', params)
    return params.strip()


# ---------------------------------------------------------------------------
# Python extractor
# ---------------------------------------------------------------------------

_PY_LAYER_BY_NAME = {
    "service": "application",
    "usecase": "application",
    "handler": "application",
    "command": "application",
    "query": "application",
    "repository": "infrastructure",
    "repo": "infrastructure",
    "model": "domain",
    "entity": "domain",
    "controller": "api",
    "router": "api",
    "view": "frontend",
    "schema": "infrastructure",
}


def _infer_py_layer(class_name: str, file_path: str) -> str:
    name_lower = class_name.lower()
    for key, layer in _PY_LAYER_BY_NAME.items():
        if name_lower.endswith(key):
            return layer
    # Fallback: path segments
    return infer_layer_from_path(file_path)


def extract_python(src_dir: str, out_dir: str, rel_base: str = "") -> list:
    """Extract CTFs from Python source files using the ast module."""
    generated = []
    src_path = pathlib.Path(src_dir)

    for py_file in sorted(src_path.rglob("*.py")):
        if any(p in py_file.parts for p in ("__pycache__", ".git", "venv", "migrations")):
            continue
        if py_file.name.startswith("test_") or py_file.name.endswith("_test.py"):
            continue

        content = py_file.read_text(encoding="utf-8", errors="ignore")
        rel = str(py_file.relative_to(src_path)) if not rel_base else \
              os.path.join(rel_base, str(py_file.relative_to(src_path)))

        try:
            tree = ast.parse(content, filename=str(py_file))
        except SyntaxError:
            continue

        for node in ast.walk(tree):
            if not isinstance(node, ast.ClassDef):
                continue
            class_name = node.name
            if class_name.startswith("_"):
                continue

            layer = _infer_py_layer(class_name, str(py_file))

            methods = []
            for item in node.body:
                if not isinstance(item, (ast.FunctionDef, ast.AsyncFunctionDef)):
                    continue
                if item.name.startswith("_"):
                    continue
                args = [a.arg for a in item.args.args if a.arg != "self"]
                ret = ""
                if item.returns:
                    ret = ast.unparse(item.returns) if hasattr(ast, "unparse") else "Any"
                sig = f"{item.name}({', '.join(args)}){': ' + ret if ret else ''}"
                methods.append({
                    "signature": sig,
                    "returns": ret or "None",
                    "steps": [f"— implementation extracted from `{py_file.name}`"],
                })

            if not methods:
                methods.append({
                    "signature": f"{class_name.lower()}()",
                    "returns": "None",
                    "steps": ["— no public methods detected; review source"],
                })

            provides = [m["signature"].split("(")[0] for m in methods[:8]]
            content_md = render_ctf(
                module_id=class_name,
                layer=layer,
                rel_path=rel,
                methods=methods,
                depends_on=[],
                provides=provides,
            )
            slug = to_slug(class_name)
            path = write_ctf(out_dir, layer, slug, content_md)
            generated.append({"module_id": class_name, "layer": layer, "path": path})

    return generated


# ---------------------------------------------------------------------------
# Index generation
# ---------------------------------------------------------------------------

def write_index(out_dir: str, ctfs: list, project: str = "extracted") -> None:
    total_tokens = sum(90 + 90 * 3 for _ in ctfs)  # rough estimate
    lines = [
        f"---\nproject: {project}\ntwin_version: 1.0.0\nlast_sync: {TODAY}\n"
        f"total_modules: {len(ctfs)}\ntotal_token_cost: {total_tokens}\n---\n\n",
        "# Code Twin Index\n\n",
        "| module_id | layer | path | provides | tokens |\n",
        "|---|---|---|---|---|\n",
    ]
    for ctf in ctfs:
        rel_out = os.path.relpath(ctf["path"], out_dir)
        lines.append(
            f"| {ctf['module_id']} | {ctf['layer']} | {rel_out} | — | 360 |\n"
        )
    os.makedirs(out_dir, exist_ok=True)
    with open(os.path.join(out_dir, "index.md"), "w", encoding="utf-8") as f:
        f.writelines(lines)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(description="code-twin-extract — AST-light extractor")
    parser.add_argument("--lang", required=True, choices=["typescript", "csharp", "python"])
    parser.add_argument("--src", required=True, help="Source directory to scan")
    parser.add_argument("--out", required=True, help="Output directory for CTFs")
    parser.add_argument("--arch", default=None, help="Path to meta/architecture.md for ns mapping")
    parser.add_argument("--project", default="extracted", help="Project slug for index.md")
    args = parser.parse_args()

    if not os.path.isdir(args.src):
        print(f"ERROR: --src directory not found: {args.src}", file=sys.stderr)
        sys.exit(2)

    os.makedirs(args.out, exist_ok=True)

    if args.lang == "typescript":
        ctfs = extract_typescript(args.src, args.out)
    elif args.lang == "csharp":
        ctfs = extract_csharp(args.src, args.out, arch_md=args.arch)
    elif args.lang == "python":
        ctfs = extract_python(args.src, args.out)
    else:
        print(f"ERROR: unsupported lang: {args.lang}", file=sys.stderr)
        sys.exit(2)

    if not ctfs:
        print("WARNING: no extractable classes found", file=sys.stderr)
        sys.exit(1)

    write_index(args.out, ctfs, project=args.project)

    summary = {"extracted": len(ctfs), "output_dir": args.out, "ctfs": ctfs}
    print(json.dumps(summary, indent=2))
    sys.exit(0)


if __name__ == "__main__":
    main()
