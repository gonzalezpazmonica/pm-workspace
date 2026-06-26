#!/usr/bin/env python3
"""scripts/query-keyword-expand.py — SPEC-073: Query Keyword Expansion

Expands a search query into related keywords using:
- CamelCase splitting
- snake_case splitting
- Simple stemming (ES/EN)
- Acronym expansion
- Domain synonym lookup

No external dependencies (stdlib only).

CLI:
    python3 scripts/query-keyword-expand.py --query "buscar auth service"

Output JSON:
    {
        "original": "buscar auth service",
        "expanded": ["buscar", "auth", ...],
        "synonyms": {"auth": ["authentication", "login", "jwt"], ...},
        "search_terms": ["buscar", "auth", "authentication", ...]
    }
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from typing import Any


# ── Acronym map ───────────────────────────────────────────────────────────────

ACRONYMS: dict[str, list[str]] = {
    "ADO":  ["Azure DevOps"],
    "KG":   ["Knowledge Graph"],
    "SDD":  ["Spec-Driven Development", "specification driven development"],
    "CI":   ["Continuous Integration"],
    "CD":   ["Continuous Delivery", "Continuous Deployment"],
    "JWT":  ["JSON Web Token"],
    "DI":   ["Dependency Injection"],
    "ORM":  ["Object Relational Mapper"],
    "CRUD": ["Create Read Update Delete"],
    "API":  ["Application Programming Interface"],
    "HTTP": ["HyperText Transfer Protocol"],
    "SQL":  ["Structured Query Language"],
    "PBI":  ["Product Backlog Item"],
    "AC":   ["Acceptance Criteria"],
    "PR":   ["Pull Request"],
    "MCP":  ["Model Context Protocol"],
    "LLM":  ["Large Language Model"],
    "RAG":  ["Retrieval Augmented Generation"],
    "TDD":  ["Test Driven Development"],
    "BDD":  ["Behavior Driven Development"],
}


# ── Domain synonym map ────────────────────────────────────────────────────────

SYNONYMS: dict[str, list[str]] = {
    # Auth / Identity
    "auth":           ["authentication", "login", "jwt", "oauth", "credentials", "session", "token"],
    "authentication": ["auth", "login", "jwt", "oauth", "credentials"],
    "login":          ["auth", "authentication", "signin", "credentials"],
    "jwt":            ["token", "auth", "authentication", "bearer"],
    "token":          ["jwt", "bearer", "auth", "credential"],

    # Spec / Requirements
    "spec":           ["specification", "requirement", "criteria", "definition"],
    "specification":  ["spec", "requirement", "definition", "criteria"],
    "requirement":    ["spec", "specification", "acceptance criteria", "ac"],
    "criteria":       ["requirement", "spec", "acceptance criteria"],

    # Search / Find
    "buscar":         ["busca", "búsqueda", "find", "search", "query", "lookup"],
    "búsqueda":       ["buscar", "busca", "find", "search", "query"],
    "busca":          ["buscar", "búsqueda", "find", "search"],
    "find":           ["search", "query", "lookup", "buscar", "busca"],
    "search":         ["find", "query", "lookup", "buscar", "búsqueda"],

    # Error / Fault
    "error":          ["fault", "failure", "exception", "bug", "issue"],
    "fault":          ["error", "failure", "exception", "fallo"],
    "failure":        ["error", "fault", "exception", "fallo", "falla"],

    # Agent / Orchestrator
    "agent":          ["orchestrator", "worker", "agente", "subagent"],
    "agente":         ["agent", "orchestrator", "worker"],
    "orchestrator":   ["agent", "coordinator", "orquestador"],

    # Memory / Context
    "memory":         ["context", "knowledge", "recall", "memoria"],
    "memoria":        ["memory", "context", "recall"],
    "context":        ["memory", "knowledge", "contexto", "prompt"],
    "contexto":       ["context", "memory", "knowledge"],

    # Service / Servicio
    "service":        ["servicio", "microservice", "api", "endpoint"],
    "servicio":       ["service", "microservice", "api"],

    # Test / Testing
    "test":           ["tests", "testing", "spec", "assertion", "prueba"],
    "tests":          ["test", "testing", "specs", "assertions"],
    "prueba":         ["test", "tests", "testing"],

    # Deploy / Infrastructure
    "deploy":         ["deployment", "release", "despliegue", "publish"],
    "despliegue":     ["deploy", "deployment", "release"],

    # Config / Configuration
    "config":         ["configuration", "settings", "configuracion", "setup"],
    "configuration":  ["config", "settings", "setup"],
    "configuracion":  ["config", "configuration", "settings"],
}


# ── Simple stemming map (ES/EN, no external deps) ─────────────────────────────

_STEM_RULES_ES: list[tuple[re.Pattern, str]] = [
    (re.compile(r"aciones$", re.I), ""),       # autenticaciones → autentic
    (re.compile(r"ación$", re.I), ""),          # autenticación → autentic
    (re.compile(r"ando$", re.I), ""),           # buscando → busc
    (re.compile(r"ando$", re.I), "ar"),         # buscando → buscar
    (re.compile(r"iendo$", re.I), "er"),        # haciendo → hacer
    (re.compile(r"mente$", re.I), ""),          # rápidamente → rápida
    (re.compile(r"ados?$", re.I), ""),          # configurados → configur
    (re.compile(r"idos?$", re.I), ""),          # fallidos → fall
    (re.compile(r"ción$", re.I), "r"),          # configuración → configurar
    (re.compile(r"es$", re.I), ""),             # services → servic (only when > 4 chars)
    (re.compile(r"s$", re.I), ""),              # tests → test
]

_STEM_RULES_EN: list[tuple[re.Pattern, str]] = [
    (re.compile(r"ations?$", re.I), "ate"),    # authentication → authenticate
    (re.compile(r"ing$", re.I), ""),            # searching → search
    (re.compile(r"tion$", re.I), "te"),         # generation → generate
    (re.compile(r"ment$", re.I), ""),           # deployment → deploy
    (re.compile(r"ness$", re.I), ""),           # correctness → correct
    (re.compile(r"er$", re.I), ""),             # searcher → search
    (re.compile(r"ed$", re.I), ""),             # failed → fail
    (re.compile(r"s$", re.I), ""),              # errors → error
]


def stem(word: str) -> list[str]:
    """Return possible stems of a word (may be empty if no rule applies)."""
    stems: list[str] = []
    w = word.lower()
    if len(w) < 4:
        return stems
    for pattern, replacement in _STEM_RULES_EN + _STEM_RULES_ES:
        stem_candidate = pattern.sub(replacement, w)
        if stem_candidate != w and len(stem_candidate) >= 3:
            stems.append(stem_candidate)
    return list(dict.fromkeys(stems))  # deduplicate, preserve order


# ── CamelCase split ───────────────────────────────────────────────────────────

def split_camel(word: str) -> list[str]:
    """Split CamelCase into parts: 'authService' → ['auth', 'service', 'authService']"""
    if not word:
        return []
    # Insert space before sequences: uppercase followed by lowercase, or lowercase followed by uppercase
    spaced = re.sub(r"([a-z])([A-Z])", r"\1 \2", word)
    spaced = re.sub(r"([A-Z]+)([A-Z][a-z])", r"\1 \2", spaced)
    parts = [p.lower() for p in spaced.split() if p]
    if len(parts) > 1:
        parts.append(word.lower())  # include the original (lowercased) as a term too
    return list(dict.fromkeys(parts))


# ── snake_case split ──────────────────────────────────────────────────────────

def split_snake(word: str) -> list[str]:
    """Split snake_case into parts: 'auth_service' → ['auth', 'service']"""
    if "_" not in word:
        return []
    parts = [p.lower() for p in word.split("_") if p]
    return parts


# ── Tokenizer ─────────────────────────────────────────────────────────────────

def tokenize(query: str) -> list[str]:
    """Split query into tokens (words), normalized to lowercase."""
    tokens = re.findall(r"[A-Za-záéíóúüñÁÉÍÓÚÜÑ_]+", query)
    return [t.lower() for t in tokens if t]


# ── Main expansion logic ──────────────────────────────────────────────────────

def expand_query(query: str) -> dict[str, Any]:
    """
    Expand a query string into keywords, synonyms, and search_terms.
    Returns a dict with keys: original, expanded, synonyms, search_terms.
    """
    if not query or not query.strip():
        return {
            "original": query,
            "expanded": [],
            "synonyms": {},
            "search_terms": [],
        }

    # 1. Tokenize original query
    tokens = tokenize(query)

    expanded: list[str] = list(tokens)  # start with originals
    synonyms_found: dict[str, list[str]] = {}

    for token in tokens:
        token_upper = token.upper()

        # 2. CamelCase split
        camel_parts = split_camel(token)
        for p in camel_parts:
            if p not in expanded:
                expanded.append(p)

        # 3. snake_case split
        snake_parts = split_snake(token)
        for p in snake_parts:
            if p not in expanded:
                expanded.append(p)

        # 4. Acronym expansion
        if token_upper in ACRONYMS:
            for expansion in ACRONYMS[token_upper]:
                exp_tokens = tokenize(expansion)
                for et in exp_tokens:
                    if et not in expanded:
                        expanded.append(et)
                # Also add full expansion phrase
                if expansion not in expanded:
                    expanded.append(expansion)

        # 5. Domain synonyms (lookup by lowercase)
        if token in SYNONYMS:
            syns = SYNONYMS[token]
            synonyms_found[token] = syns
            for syn in syns:
                syn_lower = syn.lower()
                if syn_lower not in expanded:
                    expanded.append(syn_lower)

        # 6. Stemming — add stems of original token
        token_stems = stem(token)
        for s in token_stems:
            if s not in expanded:
                expanded.append(s)

    # search_terms: unique, non-empty strings
    search_terms = [t for t in dict.fromkeys(expanded) if t and len(t) >= 2]

    return {
        "original": query,
        "expanded": search_terms,
        "synonyms": synonyms_found,
        "search_terms": search_terms,
    }


# ── CLI ───────────────────────────────────────────────────────────────────────

def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="query-keyword-expand.py",
        description="SPEC-073: Query Keyword Expansion — expand search queries into related terms",
    )
    p.add_argument(
        "--query",
        required=True,
        metavar="TEXT",
        help="Query to expand",
    )
    return p


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    if not args.query or not args.query.strip():
        result = expand_query(args.query)
        print(json.dumps(result, indent=2, ensure_ascii=False))
        return 0

    result = expand_query(args.query)
    print(json.dumps(result, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
