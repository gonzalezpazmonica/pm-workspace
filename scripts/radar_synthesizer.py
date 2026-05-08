"""SPEC-P04: Radar synthesizer — consolidate agent-*.md + radar-report.json into final report.

Invoked by pm-radar SKILL after agents produce their outputs and pm-radar.py has run.
Reads all agent-*.md + radar-report.json, emits a consolidated markdown report.
"""
import argparse
import json
import re
import sys
from datetime import datetime
from pathlib import Path


def load_agents(tmp_dir):
    """Return list of {name, content, size}."""
    agents = []
    for f in sorted(tmp_dir.glob("agent-*.md")):
        try:
            content = f.read_text(encoding="utf-8")
            agents.append({"name": f.stem.replace("agent-", ""), "content": content, "size": len(content)})
        except Exception as err:
            print("[synth] skip " + f.name + ": " + str(err)[:80], file=sys.stderr)
    return agents


def extract_sections(content):
    """Split markdown content by ## headers and return list of {header, body}."""
    sections = []
    current_header = None
    current_body = []
    for line in content.split("\n"):
        if line.startswith("## "):
            if current_header is not None:
                sections.append({"header": current_header, "body": "\n".join(current_body).strip()})
            current_header = line[3:].strip()
            current_body = []
        else:
            current_body.append(line)
    if current_header is not None:
        sections.append({"header": current_header, "body": "\n".join(current_body).strip()})
    return sections


def pick_priority(radar_items, band, limit=10):
    """Return top items in given band from radar-report."""
    out = [i for i in radar_items if i.get("band", "").lower() == band.lower()]
    out.sort(key=lambda x: -(x.get("score") or 0))
    return out[:limit]


def main():
    ap = argparse.ArgumentParser(description="Radar synthesizer (SPEC-P04)")
    ap.add_argument("--tmp-dir", default=str(Path.home() / ".savia" / "radar-tmp"))
    ap.add_argument("--report-json", default=str(Path.home() / ".savia" / "pm-radar" / "radar-report.json"))
    ap.add_argument("--output", required=True, help="Output markdown path (.md)")
    ap.add_argument("--summary-words", type=int, default=500)
    args = ap.parse_args()

    tmp_dir = Path(args.tmp_dir)
    report_json_path = Path(args.report_json)
    out_path = Path(args.output)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    tmp = out_path.with_suffix(".tmp")

    agents = load_agents(tmp_dir)
    print("[synth] loaded " + str(len(agents)) + " agent outputs", file=sys.stderr)

    radar = {}
    if report_json_path.exists():
        try:
            radar = json.loads(report_json_path.read_text(encoding="utf-8"))
        except Exception as err:
            print("[synth] radar-report.json parse fail: " + str(err)[:80], file=sys.stderr)

    items = radar.get("items", [])
    stats = radar.get("stats", {})
    delta = radar.get("delta", {})
    incs = radar.get("inconsistencies", [])
    ts = datetime.now().strftime("%Y-%m-%d %H:%M")

    lines = []
    lines.append("# PM Radar — Synthesizer output · " + ts)
    lines.append("")
    lines.append("**Última actualización**: " + ts)
    lines.append("")
    lines.append("## Resumen")
    lines.append("")
    lines.append("- Agent outputs consumidos: " + str(len(agents)))
    lines.append("- Items activos (radar): " + str(len(items)))
    if stats:
        for k in ("critico", "urgente", "importante", "seguimiento", "inconsistencies"):
            if k in stats:
                lines.append("- " + k.upper() + ": " + str(stats[k]))
    if delta:
        lines.append("- Delta vs run anterior: +" + str(len(delta.get("new", []))) + " nuevos · " + str(len(delta.get("closed", []))) + " cerrados · " + str(len(delta.get("reprio", []))) + " reprio")
    lines.append("")

    # Critical items
    crit = pick_priority(items, "CRITICO", limit=15)
    lines.append("## CRITICO · " + str(len(crit)))
    lines.append("")
    for c in crit:
        score = c.get("score", "?")
        src = c.get("source", "?")
        desc = (c.get("description") or c.get("title") or "")[:130]
        lines.append("- [" + str(score) + "] [" + src + "] " + desc)
    lines.append("")

    # Urgent items
    urg = pick_priority(items, "URGENTE", limit=15)
    lines.append("## URGENTE · " + str(len(urg)))
    lines.append("")
    for c in urg:
        score = c.get("score", "?")
        src = c.get("source", "?")
        desc = (c.get("description") or c.get("title") or "")[:130]
        lines.append("- [" + str(score) + "] [" + src + "] " + desc)
    lines.append("")

    # Inconsistencies
    if incs:
        lines.append("## Inconsistencias auto-detectadas · " + str(len(incs)))
        lines.append("")
        for inc in incs[:20]:
            lines.append("- [" + inc.get("severity", "?") + "] " + inc.get("type", "?") + ": " + (inc.get("description") or "")[:140])
        lines.append("")

    # Per-agent sections (compact)
    lines.append("## Detalle por agente")
    lines.append("")
    for ag in agents:
        lines.append("### " + ag["name"])
        lines.append("")
        sections = extract_sections(ag["content"])
        # Include up to 3 top-level sections per agent, truncated
        for sec in sections[:3]:
            body = sec["body"]
            if len(body) > 1200:
                body = body[:1200] + " ... [truncated]"
            lines.append("**" + sec["header"] + "**")
            lines.append("")
            lines.append(body)
            lines.append("")

    tmp.write_text("\n".join(lines), encoding="utf-8")
    tmp.replace(out_path)
    # Build short summary for caller
    summary = {
        "report_path": str(out_path),
        "agents_consumed": len(agents),
        "items_active": len(items),
        "critico": len(crit),
        "urgente": len(urg),
        "inconsistencies": len(incs),
        "timestamp": ts,
    }
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
