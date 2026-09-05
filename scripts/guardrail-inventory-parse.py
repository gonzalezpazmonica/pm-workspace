#!/usr/bin/env python3
"""
guardrail-inventory-parse.py — SE-374 FASES A+B (inventory + classification).

Inventaria y clasifica los guardrails del workspace:
  hooks (.claude/hooks, .opencode/hooks, registro en .claude/settings.json),
  agentes (.opencode/agents), normas (docs/rules/domain, .claude/rules/domain),
  CONSTITUCION, principios eticos (lineas rojas L1-L5) y skills.

Salidas:
  --out     inventory.json   (schema SPEC-SE-374 §2.2 + audit_facts)
  --rn-out  rn-facts.json    (hallazgos RN-01..RN-12 para FASE C/D)

Constraints: python3 stdlib, sin red, sin secrets (solo presencia de claves),
determinista (content_fingerprint estable para el mismo commit).
Ref: docs/specs/SPEC-SE-374-GUARDRAIL-PRINCIPLE-AUDIT.spec.md
"""
from __future__ import annotations

import argparse
import datetime
import hashlib
import json
import os
import re
import sys

# ── helpers ───────────────────────────────────────────────────────────────

def sha256(s: str) -> str:
    return hashlib.sha256(s.encode("utf-8")).hexdigest()


def read(path: str) -> str:
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            return f.read()
    except OSError:
        return ""


def strip_comments(code: str) -> str:
    return "\n".join(l for l in code.splitlines() if not l.lstrip().startswith("#"))


def frontmatter(text: str) -> dict:
    m = re.match(r"^---\s*\n(.*?)\n---\s*\n", text, re.DOTALL)
    if not m:
        return {}
    fm = {}
    for line in m.group(1).splitlines():
        mm = re.match(r"^([A-Za-z_][\w-]*):\s*(.*)$", line)
        if mm:
            fm[mm.group(1)] = mm.group(2).strip().strip('"')
    return fm


STOPWORDS = set("""
de la el los las un una unos unas y o u e a al del en con por que se su sus sin son fue era les le te os mi mis tu tus
para como desde sobre entre hasta segun cual cuyo esta este esto estos estas ser es está hay ante bajo donde cada mas
muy mucho nada nadie nos ni no si también tambien pero tanto cuando aunque debe deben deberia hacer hace usar usa
aplicar aplica permite permitir the and for with not are all any can will must into from that this those these have
hook hooks tools tool level action modo modoes rule rules docs file files campo valor valores siempre solo asi así
además ademas luego tras tras solamente deben debe tener tiene hacia menos
""".split())

SYNONYMS = {
    "pat": "credential", "token": "credential", "hardcodear": "credential",
    "hardcode": "credential", "hardcodear+pat": "credential", "secreto": "credential",
    "password": "credential", "apikey": "credential", "contrasena": "credential",
    "fuerza": "force", "forzar": "force",
    "repositorio": "repo",
    "aprobacion": "approve", "aprobar": "approve", "apruebe": "approve",
    "autoasignar": "reviewer", "mergeador": "merge",
    "secret": "credential", "secrets": "credential",
}


def tokens(text: str) -> set:
    out = set()
    for t in re.findall(r"[a-z0-9áéíóúñ_\-]{3,}", text.lower()):
        t = t.strip("-_")
        if len(t) >= 4 and t not in STOPWORDS:
            out.add(t)
    return out


REF_PATTERNS = [
    (re.compile(r"Rule\s*#?\s*(\d+[b]?)", re.I), "Rule#{0}"),
    (re.compile(r"\bART-(\d+)\b"), "ART-{0}"),
    (re.compile(r"\bSE-(\d{3})\b"), "SE-{0}"),
    (re.compile(r"\bSPEC-(\d+)\b"), "SPEC-{0}"),
    (re.compile(r"\bV-(\d{2})\b"), "V-{0}"),
    (re.compile(r"\bLEC-([1-4])\b"), "LEC-{0}"),
    (re.compile(r"[\s(]L([1-5])[\s),.:;]"), "L{0}"),
]

NAME_PROTECTS = [
    (r"force.?push", "git: push --force prohibido", "autonomous-safety"),
    (r"commit", "git: commit prohibido en main/ramas humanas", "Rule#13"),
    (r"branch", "git: ramas humanas intocables", "autonomous-safety"),
    (r"credential|secret|pat\b|ghp", "secrets jamás en repo ni comandos", "Rule#9"),
    (r"pii|confidential|privacy", "PII jamás en repo público", "Rule#20"),
    (r"sycophancy|adulation", "cero adulación", "Rule#24"),
    (r"push-pr|pr-summary|pr-plan", "gates de PR", "Rule#27"),
    (r"merge", "merge requiere permiso expreso", "autonomous-safety"),
    (r"recursion|loop-guard", "bucles de agentes acotados", "SE-146"),
    (r"overnight|autonomous|double.?optin", "modo autónomo con doble opt-in", "SPEC-186"),
    (r"cache|compact|context-rot", "higiene de contexto", "SE-371"),
    (r"agents-md|skills-md", "índices auto-regenerados", "SE-047"),
    (r"memory", "memoria persistente", "memory-system"),
    (r"emergency", "failover emergency-mode", "SPEC-122"),
    (r"permission|rbac", "permisos L0-L4", "agents-catalog"),
    (r"token.?budget|budget", "presupuesto de contexto", "context-placement"),
]

# Variables de entorno tratadas como interruptores (bypass u opt-in)
VAR_INTEREST = re.compile(
    r"^(SAVIA_|OVERNIGHT_|CODE_IMPROVEMENT|ADVERSARIAL_|TECH_RESEARCH)|"
    r"(_BYPASS|_SKIP|_OFF|_DISABLED|_ENABLED|_TESTING|ANTIADULATION|_MODE)$"
)


def detect_bypass_vars(code: str) -> list:
    """Solo interruptores que esquivan el guard (early-return en la ventana del if)."""
    lines = code.splitlines()
    found = set()
    guard_rx = re.compile(
        r'\[\s*"\$\{?([A-Z][A-Z0-9_]{3,})\}?"?\s*[!=]=\s*["\']?(off|0|false|skip|disabled?|1|true|yes)\b')
    for i, ln in enumerate(lines):
        m = guard_rx.search(ln)
        if not m:
            continue
        window = "\n".join(lines[i:i + 5])
        if re.search(r"\bexit 0\b|\breturn 0\b|SKIP_GUARD|bypass", window):
            v = m.group(1)
            if v in ("SAVIA_SUBAGENT", "CLAUDE_PROJECT_DIR"):
                continue
            if VAR_INTEREST.match(v) or re.search(r"BYPASS|SKIP|TESTING|ANTIADULATION|_ENABLED|EMERGENCY", v):
                found.add(v)
    return sorted(found)


# ── settings.json (solo clave hooks; jamas valores de permissions/env) ────

def load_registered(root: str) -> tuple:
    settings_path = os.path.join(root, ".claude", "settings.json")
    registered = {}  # resolved path -> {"events": set, "lines": [int]}
    try:
        with open(settings_path, "r", encoding="utf-8", errors="replace") as f:
            data = json.load(f)
    except (OSError, json.JSONDecodeError):
        return registered, []
    lines = read(settings_path).splitlines()
    for event, matchers in (data.get("hooks") or {}).items():
        if not isinstance(matchers, list):
            continue
        for matcher in matchers:
            for hk in (matcher or {}).get("hooks", []):
                cmd = hk.get("command", "")
                m = re.search(r"([~.$\w{}/\-]+\.sh)", cmd)
                if not m:
                    continue
                p = m.group(1).replace("${CLAUDE_PROJECT_DIR}", ".").replace("$CLAUDE_PROJECT_DIR", ".")
                while p.startswith("../"):
                    p = p[3:]
                if p.startswith("./"):
                    p = p[2:]
                if not p.startswith((".claude/", ".opencode/", "scripts/")):
                    mm = re.search(r"(?:^|/)((?:\.claude|\.opencode|scripts)/[\w./\-]+)$", p)
                    if mm:
                        p = mm.group(1)
                    else:
                        idx = p.find(".claude/")
                        idx2 = p.find(".opencode/")
                        if idx < 0 or (0 <= idx2 < idx):
                            idx = idx2
                        if idx >= 0:
                            p = p[idx:]
                p = os.path.normpath(os.path.join(root, p.replace("~", os.path.expanduser("~"))))
                entry = registered.setdefault(p, {"events": set(), "lines": []})
                entry["events"].add(event)
                for i, ln in enumerate(lines, 1):
                    if os.path.basename(p) in ln:
                        entry["lines"].append(i)
                        break
    return registered, lines


# ── hooks ─────────────────────────────────────────────────────────────────

def classify_hook(path: str, root: str, registered: dict) -> dict:
    rel = os.path.relpath(path, root)
    name = os.path.basename(path)
    code = read(path)
    live = strip_comments(code)
    reg = registered.get(path)
    mirrored = os.path.exists(os.path.join(root, ".opencode", "hooks", name))

    enforcement = bool(re.search(
        r"\bexit\s+[1-9]\b|\"decision\"\s*:\s*\"(?:block|deny)\"|"
        r"permissionDecision[\"']?\s*:\s*[\"']?deny|\"is_error\"\s*:\s*true", live))
    emits = bool(re.search(r">&2|additionalContext|\"decision\"\s*:\s*\"ask\"|echo\s+-?e?\s+\"", live))
    if enforcement:
        layer, mode = "ENFORCEMENT", "block"
    elif emits:
        layer, mode = "DISPARADOR", "warn"
    elif re.search(r"echo|printf|jsonl|tee -a|>>", live):
        layer, mode = "DISPARADOR", "log"
    else:
        layer, mode = "INFORMATIVO", "log"

    principles = []
    protects = []
    for pat, phrase, ref in NAME_PROTECTS:
        if re.search(pat, name, re.I):
            if ref not in principles:
                principles.append(ref)
            if phrase not in protects:
                protects.append(phrase)
    for rx, tpl in REF_PATTERNS:
        for m in rx.finditer(code):
            v = tpl.format(m.group(1))
            if v not in principles:
                principles.append(v)
    if not principles:
        principles = ["unmapped"]
    if not protects:
        protects = ["sin mapping nominal explícito"]

    bypass = [v for v in detect_bypass_vars(code) if v not in ("SAVIA_SUBAGENT", "CLAUDE_PROJECT_DIR")]

    return {
        "id": f"hook:{name}",
        "type": "hook",
        "path": rel,
        "mirrored_in": [".opencode/hooks/" + name] if mirrored else [],
        "registered_in_settings": reg is not None,
        "events": sorted(reg["events"]) if reg else [],
        "mode": mode,
        "layer": layer,
        "protects": protects,
        "principles": sorted(principles),
        "bypass_switch": bypass[0] if bypass else None,
        "bypass_switch_all": bypass,
        "bypass_documented": None,  # fill in main()
        "parse_ok": bool(code.strip()),
    }


# Paredes estructurales de script (no son hooks pero bloquean deterministamente)
ENFORCEMENT_SCRIPTS = [
    ("scripts/push-pr.sh", "gate de PR: falla sin .pr-plan-ok, árbol sucio o CI local fallido", "Rule#27"),
    ("scripts/operator-grant.sh", "merge requiere grant vigente de la operadora (SE-343)", "autonomous-safety"),
    ("scripts/savia-double-optin-check.sh", "doble opt-in para skills autónomas (SPEC-186)", "SPEC-186"),
    ("scripts/handback-resolve.sh", "handback obligatorio de instancias autónomas (SE-332)", "SE-332"),
    ("scripts/validate-ci-local.sh", "CI local obligatorio antes de push", "ci"),
    ("scripts/confidentiality-sign.sh", "firma de confidencialidad antes de PR", "Rule#20"),
]


def scan_gates(root: str) -> list:
    out = []
    for rel, protects, ref in ENFORCEMENT_SCRIPTS:
        path = os.path.join(root, rel)
        code = read(path)
        if not code:
            continue
        live = strip_comments(code)
        enforcement = bool(re.search(r"\bexit 1\b|\bexit 2\b|ERROR:", live))
        out.append({
            "id": f"gate:{os.path.basename(rel)}",
            "type": "gate",
            "path": rel,
            "mirrored_in": [],
            "registered_in_settings": None,
            "events": [],
            "mode": "block" if enforcement else "warn",
            "layer": "ENFORCEMENT" if enforcement else "DISPARADOR",
            "protects": [protects],
            "principles": sorted({ref}),
            "bypass_switch": None,
            "bypass_switch_all": [],
            "bypass_documented": None,
            "parse_ok": True,
        })
    return out



# ── agentes ───────────────────────────────────────────────────────────────

def model_family(model: str) -> str:
    m = model.split("/")[-1]
    for fam in ("deepseek", "glm", "qwen", "claude", "gpt", "llama", "gemini"):
        if m.startswith(fam):
            return fam
    return m.split("-")[0]


PANELS = {
    "code-review-court": "Code Review Court judge",
    "truth-tribunal": "Truth Tribunal judge",
    "recommendation-tribunal": "Recommendation Tribunal judge",
    "coherence-court": "Coherence Court judge",
}


def scan_agents(root: str) -> list:
    agents = []
    adir = os.path.join(root, ".opencode", "agents")
    if not os.path.isdir(adir):
        return agents
    for fn in sorted(os.listdir(adir)):
        if not fn.endswith(".md"):
            continue
        path = os.path.join(adir, fn)
        text = read(path)
        fm = frontmatter(text)
        name = fm.get("name") or fn[:-3]
        perm = fm.get("permission", "")
        just = any("justif" in k.lower() for k in fm)
        panel = None
        desc = fm.get("description", "")
        for pid, marker in PANELS.items():
            if marker in desc:
                panel = pid
                break
        agents.append({
            "id": f"agent:{name}",
            "type": "agent",
            "path": os.path.relpath(path, root),
            "layer": "NORMA",
            "mode": None,
            "permission": perm,
            "model": fm.get("model", ""),
            "model_family": model_family(fm.get("model", "")),
            "panel": panel,
            "has_justification": just,
            "parse_ok": bool(fm),
            "principles": [],
            "protects": ["gobierno de agentes (permission L0-L4)"],
        })
    return agents


# ── normas / constitución / principios ────────────────────────────────────

NUNCA_RX = re.compile(r"\bNUNCA\b|\bjam[aá]s\b|\bJAM[AÁ]S\b", re.I)


def scan_norms(root: str) -> tuple:
    guardrails, prohibitions = [], []
    norm_files = {}
    for base in ("docs/rules/domain", ".claude/rules/domain"):
        d = os.path.join(root, base)
        if not os.path.isdir(d):
            continue
        for dirpath, _dirs, files in os.walk(d):
            for fn in sorted(files):
                if fn.endswith(".md"):
                    norm_files.setdefault(fn, os.path.join(dirpath, fn))
    constitution_path = os.path.join(root, ".claude", "CONSTITUCION.md")
    norm_files["CONSTITUCION.md"] = constitution_path

    for name in sorted(norm_files):
        path = norm_files[name]
        text = read(path)
        rel = os.path.relpath(path, root)
        lows = []
        lines = text.splitlines()
        if name == "CONSTITUCION.md":
            cur_art = None
            for i, ln in enumerate(lines, 1):
                am = re.search(r"\*\*ART-(\d+)\.", ln)
                if am:
                    cur_art = am.group(1)
                vm = re.search(r"\bV-(\d{2}):", ln)
                if vm and cur_art:
                    lows.append({"id": f"ART-{cur_art}/V-{vm.group(1)}", "line": i,
                                 "text": ln.strip()[:110], "file": rel})
        else:
            for i, ln in enumerate(lines, 1):
                if NUNCA_RX.search(ln):
                    rid = f"{name}:L{i}"
                    if name == "critical-rules-extended.md":
                        rm = re.match(r"^(\d+[b]?)\.\s", ln.strip())
                        if rm:
                            rid = f"Rule#{rm.group(1)}"
                    lows.append({"id": rid, "line": i, "text": ln.strip()[:110], "file": rel})
        gtype = "constitution" if name == "CONSTITUCION.md" else "rule"
        guardrails.append({
            "id": f"{gtype}:{name[:-3] if name.endswith('.md') else name}",
            "type": gtype,
            "path": rel,
            "layer": "NORMA",
            "mode": None,
            "prohibitions_count": len(lows),
            "parse_ok": bool(text.strip()),
            "principles": [],
            "protects": [],
        })
        prohibitions.extend(lows)

    red_lines = []
    principles_path = os.path.join(root, "docs", "rules", "domain", "savia-ethical-principles.md")
    ptext = read(principles_path)
    for i, ln in enumerate(ptext.splitlines(), 1):
        m = re.match(r"\|\s*\*\*(L[1-5])\*\*\s*\|\s*(.+?)\s*\|", ln)
        if m:
            red_lines.append({"id": m.group(1), "line": i,
                              "text": m.group(2)[:110],
                              "file": os.path.relpath(principles_path, root)})
    guardrails.append({
        "id": "principle:savia-ethical-principles",
        "type": "principle",
        "path": os.path.relpath(principles_path, root),
        "layer": "NORMA",
        "mode": None,
        "red_lines": len(red_lines),
        "parse_ok": bool(ptext.strip()),
        "principles": ["L1", "L2", "L3", "L4", "L5"],
        "protects": ["líneas rojas L1-L5"],
    })
    return guardrails, prohibitions, red_lines


# ── skills ────────────────────────────────────────────────────────────────

AUTONOMOUS_KNOWN = {
    "overnight-sprint", "code-improvement-loop", "tech-research-agent",
    "adversarial-security", "consensus-validation", "dag-scheduling",
    "spec-driven-development", "tdd-vertical-slices", "verification-lattice",
    "savia-dual",
}
# SPEC-186: skills que exigen doble opt-in (variable de entorno + --confirm-autonomous)
DOUBLE_OPTIN_REQUIRED = {
    "overnight-sprint", "code-improvement-loop", "tech-research-agent",
    "adversarial-security", "savia-dual",
}
# SE-146: skills con guard de contexto subagente obligatorio
SUBAGENT_GUARD_LIST = {
    "adversarial-security", "code-improvement-loop", "consensus-validation",
    "dag-scheduling", "overnight-sprint", "spec-driven-development",
    "tdd-vertical-slices", "verification-lattice",
}


def scan_skills(root: str) -> list:
    out = []
    sdir = os.path.join(root, ".claude", "skills")
    if not os.path.isdir(sdir):
        return out
    for name in sorted(os.listdir(sdir)):
        path = os.path.join(sdir, name, "SKILL.md")
        if not os.path.isfile(path):
            continue
        text = read(path)
        fm = frontmatter(text)
        desc = fm.get("description", "") or ""
        self_autonomous = "savia-double-optin-check.sh" in text or "confirm-autonomous" in text
        desc_autonomous = bool(re.search(r"autónom|autonom[oa]s?\b", desc + " " + name, re.I))
        autonomous = name in AUTONOMOUS_KNOWN or (self_autonomous and desc_autonomous) or name in SUBAGENT_GUARD_LIST
        out.append({
            "id": f"skill:{name}",
            "type": "skill",
            "path": os.path.relpath(path, root),
            "layer": "NORMA",
            "mode": None,
            "autonomous": autonomous,
            "double_optin": "savia-double-optin-check.sh" in text or "double opt-in" in text or "doble opt-in" in text,
            "scope_guard": "SAVIA_SUBAGENT" in text or "Subagent Scope Guard" in text,
            "parse_ok": bool(fm),
            "principles": [],
            "protects": [],
        })
    return out


# ── documentación de bypass vars ──────────────────────────────────────────

def doc_index(root: str) -> dict:
    idx = {}
    for base in ("docs/rules/domain", "docs"):
        d = os.path.join(root, base)
        if not os.path.isdir(d):
            continue
        for dirpath, _dirs, files in os.walk(d):
            if "/output/" in dirpath or "/node_modules/" in dirpath:
                continue
            for fn in files:
                if fn.endswith(".md"):
                    idx[os.path.join(dirpath, fn)] = read(os.path.join(dirpath, fn))
    readme = os.path.join(root, "README.md")
    if os.path.exists(readme):
        idx[readme] = read(readme)
    return idx


# ── RN: hallazgos ─────────────────────────────────────────────────────────

def esc(s) -> str:
    s = str(s if s is not None else "")
    return s.replace("|", "\\|").replace("\n", " ")


def compute_rn(inv: dict, prohibitions: list, red_lines: list, docidx: dict) -> list:
    hooks = [g for g in inv["guardrails"] if g["type"] in ("hook", "gate")]
    agents = [g for g in inv["guardrails"] if g["type"] == "agent"]
    skills = [g for g in inv["guardrails"] if g["type"] == "skill"]
    enforcement = [h for h in hooks if h["layer"] == "ENFORCEMENT"]
    rn = []

    def add(num, status, summary, findings):
        rn.append({"rn": f"RN-{num:02d}", "status": status, "summary": summary,
                   "findings": findings})

    # RN-01: layer clasificada + parse_ok
    f = []
    for g in inv["guardrails"]:
        if not g.get("layer"):
            f.append({"severity": "P1", "guardrail": g["id"], "principle": "RN-01",
                      "evidence": g["path"], "propuesta": "Clasificar capa según §2.3"})
        if g.get("parse_ok") is False:
            f.append({"severity": "P1", "guardrail": g["id"], "principle": "RN-01",
                      "evidence": g["path"], "propuesta": "Reparar parseo; nunca omitir silenciosamente (edge §6)"})
    add(1, "GAP" if f else "PASS",
        f"{len(inv['guardrails'])} entradas, todas con capa" if not f else f"{len(f)} entradas sin clasificar",
        f)

    # RN-02: toda prohibición NUNCA/jamás mapea a ≥1 hook block
    hook_tokens = {}
    for h in hooks:
        t = tokens(os.path.basename(h["path"]))
        t |= tokens(" ".join(h["principles"])) | tokens(" ".join(h["protects"]))
        hook_tokens[h["id"]] = t
    f, matched = [], 0
    for p in prohibitions:
        hit = None
        for h in enforcement:
            if p["id"] in h["principles"] or p["id"].split("/")[0] in h["principles"]:
                hit = h
                break
        if not hit:
            pt = tokens(p["text"]) | tokens(p["id"])
            for t in list(pt):
                if t in SYNONYMS:
                    pt.add(SYNONYMS[t])
            best = None
            for h in enforcement:
                if pt & hook_tokens[h["id"]]:
                    best = h
                    break
            hit = best
        if hit:
            matched += 1
        else:
            if re.match(r"^ART-\d+", p["id"]):
                prop = ("Sin pared técnica alcanzable (prohibición semántica): documentar gate humano explícito "
                        "+ capa DISPARADOR que obligue a evaluar la norma (LEC-1)")
            else:
                prop = f"Hook PreToolUse con exit≠0 que bloquee: {p['text'][:70]}"
            f.append({"severity": "P0", "guardrail": p["id"], "principle": "norma sin pared determinista (LEC-2)",
                      "evidence": f"{p['file']}:{p['line']}", "propuesta": prop})
    add(2, "GAP" if f else "PASS",
        f"{len(prohibitions)} prohibiciones; {matched} con enforcement, {len(f)} sin pared",
        f)

    # RN-03: líneas rojas L1-L5 con enforcement o gate documentado
    f = []
    principle_lines = read(os.path.join(inv["_root"], "docs", "rules", "domain", "savia-ethical-principles.md")).splitlines()
    for rl in red_lines:
        fam = rl["id"]
        hook_hit = [h for h in hooks if fam in h["principles"] and h["layer"] == "ENFORCEMENT"]
        gate_doc = False
        for ln in principle_lines:
            if not re.search(r"\b" + fam + r"\b", ln):
                continue
            if re.search(r"Abort inmediato|confirmaci[oó]n humana|gate humano|Sin ranking|sin marca visible|Escalado a humano", ln):
                gate_doc = True
                break
        if hook_hit or gate_doc:
            continue
        f.append({"severity": "P0", "guardrail": fam, "principle": "línea roja sin pared ni gate",
                  "evidence": f"{rl['file']}:{rl['line']}",
                  "propuesta": "Hook determinista si es técnicamente alcanzable; si no, gate humano documentado y enlazado a la línea roja"})
    add(3, "GAP" if f else "PASS",
        f"{len(red_lines)} líneas rojas; {len(red_lines) - len(f)} con enforcement o gate documentado",
        f)

    # RN-04: hook registrado sin fichero
    f = []
    for r in inv["audit_facts"]["missing_registered"]:
        f.append({"severity": "P0", "guardrail": r["path"], "principle": "registro sin implementación",
                  "evidence": f".claude/settings.json:{r['line']}",
                  "propuesta": "Eliminar registro o restaurar fichero"})
    add(4, "GAP" if f else "PASS",
        f"{len(inv['audit_facts']['registered_hooks'])} registros verificados" if not f else f"{len(f)} registros fantasma",
        f)

    # RN-05: hooks huérfanos en disco
    f = [{"severity": "P2", "guardrail": p, "principle": "hook sin registro",
          "evidence": p, "propuesta": "Registrar en settings.json o archivar"}
         for p in inv["audit_facts"]["orphan_hooks"]]
    add(5, "GAP" if f else "PASS", f"{len(f)} hooks huérfanos", f)

    # RN-06: warn/log protegiendo prohibición jamás (P1; P0 si L1-L5 o T3)
    f = []
    nunca_rule_ids = {p["id"] for p in prohibitions}
    for h in hooks:
        if h["layer"] == "ENFORCEMENT":
            continue
        hot = [p for p in h["principles"]
               if p in nunca_rule_ids or p.split("/")[0] in nunca_rule_ids
               or re.match(r"^(L[1-5]|V-\d{2}|ART-(?:0[89]|1[0-5]))$", p)]
        if hot:
            sev = "P0" if any(re.match(r"^(L[1-5]|V-\d{2}|ART-(?:0[89]|1[0-5]))$", p) for p in hot) else "P1"
            f.append({"severity": sev, "guardrail": h["id"], "principle": f"prohibición jamás con modo {h['mode']}",
                      "evidence": f"{h['path']}", "propuesta": f"Escalar a mode:block (exit≠0); afecta: {','.join(hot[:4])}"})
    add(6, "GAP" if f else "PASS", f"{len(f)} hooks no-bloqueantes sobre prohibiciones jamás", f)

    # RN-07: paneles mono-familia sin diversidad (LEC-3)
    ORCHESTRATOR = {
        "code-review-court": "court-orchestrator.md",
        "truth-tribunal": "truth-tribunal-orchestrator.md",
        "recommendation-tribunal": "recommendation-tribunal-orchestrator.md",
        "coherence-court": "coherence-court-orchestrator.md",
    }
    f = []
    panels = inv["audit_facts"]["panels"]
    for pid, panel in panels.items():
        fams = sorted({j["family"] for j in panel["judges"]})
        orch = read(os.path.join(inv["_root"], ".opencode", "agents", ORCHESTRATOR.get(pid, f"{pid}-orchestrator.md")))
        diversity = re.search(r"diversidad|diversity|qodo|pr-agent|familia[s]? de modelo", orch, re.I)
        if len(panel["judges"]) >= 2 and len(fams) == 1 and not diversity:
            evs = ", ".join(j["path"] for j in panel["judges"][:3])
            f.append({"severity": "P1", "guardrail": f"panel:{pid}",
                      "principle": "LEC-3 evaluadores correlacionados",
                      "evidence": evs,
                      "propuesta": f"Diversificar familia de modelos o documentar medida (hoy: {','.join(fams)})"})
    add(7, "GAP" if f else "PASS",
        f"{len(panels)} paneles evaluados contra LEC-3", f)

    # RN-08: bypass switches documentados
    f = []
    for b in inv["audit_facts"]["bypass_vars"]:
        if not b["documented"]:
            f.append({"severity": "P1", "guardrail": b["var"], "principle": "override sin uso legítimo documentado",
                      "evidence": ", ".join(b["hooks"][:3]),
                      "propuesta": "Documentar uso legítimo + rastro de auditoría, o eliminar el interruptor"})
    add(8, "GAP" if f else "PASS",
        f"{len(inv['audit_facts']['bypass_vars'])} interruptores, {len(f)} sin documentar", f)

    # RN-09: drift de espejos
    f = [{"severity": "P2", "guardrail": p, "principle": "espejo sin drift tolerado",
          "evidence": p, "propuesta": "Sincronizar espejo en .opencode/hooks/"}
         for p in inv["audit_facts"]["mirror_missing_in_opencode"]]
    f += [{"severity": "P2", "guardrail": p, "principle": "espejo sin drift tolerado",
           "evidence": p, "propuesta": "Sincronizar espejo en .claude/hooks/"}
          for p in inv["audit_facts"]["mirror_missing_in_claude"]]
    add(9, "GAP" if f else "PASS", f"{len(f)} ficheros con drift de espejo", f)

    # RN-10: skills autónomas con double opt-in (SPEC-186) y/o scope guard (SE-146)
    f = []
    for s in skills:
        if not s["autonomous"]:
            continue
        sname = s["id"].split(":")[1]
        if sname in DOUBLE_OPTIN_REQUIRED and not s["double_optin"]:
            f.append({"severity": "P0", "guardrail": s["id"], "principle": "SPEC-186 doble opt-in",
                      "evidence": s["path"], "propuesta": "Integrar savia-double-optin-check.sh + --confirm-autonomous"})
        if sname in SUBAGENT_GUARD_LIST and not s["scope_guard"]:
            f.append({"severity": "P0", "guardrail": s["id"], "principle": "SE-146 Subagent Scope Guard",
                      "evidence": s["path"], "propuesta": "Documentar guard SAVIA_SUBAGENT en SKILL.md"})
    add(10, "GAP" if f else "PASS",
        f"{sum(1 for s in skills if s['autonomous'])} skills autónomas verificadas", f)

    # RN-11: L4 sin justificación en frontmatter
    f = [{"severity": "P2", "guardrail": a["id"], "principle": "L4 sin justificación declarada",
          "evidence": a["path"], "propuesta": "Añadir campo permission_justification al frontmatter"}
         for a in agents if a.get("permission") == "L4" and not a.get("has_justification")]
    add(11, "GAP" if f else "PASS", f"{len(f)} agentes L4 sin justificación", f)

    # RN-12: invariante read-only — lo verifica el orquestador (bash) por git status.
    add(12, "DELEGATED", "invariante verificada por guardrail-audit.sh (git status antes/después)", [])
    return rn


# ── main ──────────────────────────────────────────────────────────────────

def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--project-dir", default=os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    ap.add_argument("--out", required=True)
    ap.add_argument("--rn-out", default=None)
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args()
    root = os.path.abspath(args.project_dir)

    registered, _lines = load_registered(root)

    guardrails = []
    hook_paths = []
    claude_hooks = sorted(
        os.path.join(root, ".claude", "hooks", f) for f in os.listdir(os.path.join(root, ".claude", "hooks"))
        if f.endswith(".sh")) if os.path.isdir(os.path.join(root, ".claude", "hooks")) else []
    op_hooks_dir = os.path.join(root, ".opencode", "hooks")
    op_hooks = sorted(os.path.join(op_hooks_dir, f) for f in os.listdir(op_hooks_dir)
                      if f.endswith(".sh")) if os.path.isdir(op_hooks_dir) else []
    hook_paths = claude_hooks + [p for p in op_hooks if os.path.basename(p) not in
                                 {os.path.basename(c) for c in claude_hooks}]
    for p in hook_paths:
        guardrails.append(classify_hook(p, root, registered))

    guardrails += scan_agents(root)
    guardrails += scan_gates(root)
    norm_g, prohibitions, red_lines = scan_norms(root)
    guardrails += norm_g
    guardrails += scan_skills(root)

    # RN-08 facts: bypass vars documentadas
    docidx = doc_index(root)
    bypass_vars = {}
    for g in guardrails:
        if g["type"] != "hook":
            continue
        for v in g.get("bypass_switch_all", []):
            entry = bypass_vars.setdefault(v, {"var": v, "hooks": [], "documented": False, "doc_ref": None})
            entry["hooks"].append(g["path"])
    for v, entry in bypass_vars.items():
        for dpath, dtext in sorted(docidx.items()):
            if v in dtext:
                entry["documented"] = True
                entry["doc_ref"] = os.path.relpath(dpath, root)
                break

    missing_registered = []
    for p, reg in sorted(registered.items()):
        if not os.path.exists(p):
            missing_registered.append({
                "path": os.path.relpath(p, root),
                "line": reg["lines"][0] if reg["lines"] else 0,
                "events": sorted(reg["events"]),
            })
    registered_basenames = {os.path.basename(p) for p in registered}
    orphan = [os.path.relpath(p, root) for p in claude_hooks
              if os.path.basename(p) not in registered_basenames
              and "/lib/" not in p and not os.path.basename(p).startswith("_")]
    orphan += [os.path.relpath(p, root) for p in op_hooks
               if os.path.basename(p) not in registered_basenames
               and "/lib/" not in p and not os.path.basename(p).startswith("_")]
    mirror_missing_opencode = [os.path.relpath(p, root) for p in claude_hooks
                               if not os.path.exists(os.path.join(root, ".opencode", "hooks", os.path.basename(p)))]
    mirror_missing_claude = [os.path.relpath(p, root) for p in op_hooks
                             if not os.path.exists(os.path.join(root, ".claude", "hooks", os.path.basename(p)))]

    panels = {}
    for a in guardrails:
        if a["type"] == "agent" and a.get("panel"):
            panels.setdefault(a["panel"], {"judges": []})["judges"].append(
                {"agent": a["id"], "model": a["model"], "family": a["model_family"], "path": a["path"]})
    for pid in panels:
        panels[pid]["judges"].sort(key=lambda j: j["agent"])

    facts = {
        "registered_hooks": [{"path": os.path.relpath(p, root), "events": sorted(r["events"]),
                              "line": r["lines"][0] if r["lines"] else 0}
                             for p, r in sorted(registered.items()) if os.path.exists(p)],
        "missing_registered": missing_registered,
        "orphan_hooks": sorted(orphan),
        "mirror_missing_in_opencode": sorted(mirror_missing_opencode),
        "mirror_missing_in_claude": sorted(mirror_missing_claude),
        "panels": panels,
        "bypass_vars": [bypass_vars[k] for k in sorted(bypass_vars)],
        "red_lines": red_lines,
    }

    try:
        commit = "sha256:" + os.popen("git rev-parse HEAD").read().strip()
    except OSError:
        commit = "sha256:unknown"

    inv = {
        "audit_id": "guardrail-audit",
        "generated_at": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "workspace_commit": commit,
        "guardrails": guardrails,
        "audit_facts": facts,
    }
    stable = json.dumps({"guardrails": guardrails, "audit_facts": facts},
                        sort_keys=True, ensure_ascii=False)
    inv["content_fingerprint"] = "sha256:" + sha256(stable)

    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(inv, f, indent=2, sort_keys=True, ensure_ascii=False)

    if args.rn_out:
        inv["_root"] = root
        rns = compute_rn(inv, prohibitions, red_lines, docidx)
        counts = {"P0": 0, "P1": 0, "P2": 0}
        for r in rns:
            for fd in r["findings"]:
                counts[fd["severity"]] = counts.get(fd["severity"], 0) + 1
        with open(args.rn_out, "w", encoding="utf-8") as f:
            json.dump({"rn": rns, "prohibitions_total": len(prohibitions),
                       "severities": counts}, f, indent=2, sort_keys=True, ensure_ascii=False)
    if not args.quiet:
        print(f"inventario: {len(guardrails)} guardrails → {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
