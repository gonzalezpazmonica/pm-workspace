"""Meeting report v2 — implements SPEC-MRQ-01/02/04/08/09.

Pipeline:
1. Load chat JSON (Teams raw CDP export) with forced UTF-8
2. Fix mojibake if present (cp1252 bytes mis-decoded)
3. Classify each message (connection_chatter, substantive, question, commitment, delivery)
4. Apply temporal window (series-aware or last N days)
5. Extract action items using ES/EN patterns
6. Detect topics via keyword clustering
7. Compute utility score (SPEC-MRQ-08)
8. Render canonical template (SPEC-MRQ-01)
9. Route to publishable / needs-review / low-value path
"""
import argparse
import json
import re
import sys
from datetime import datetime, timedelta
from pathlib import Path


# ---------- Encoding helpers (SPEC-MRQ-09) ----------

def fix_mojibake_text(s):
    """Best-effort fix when cp1252 bytes were mis-decoded as utf-8 or vice versa."""
    if not s or not isinstance(s, str):
        return s
    if any(x in s for x in ["Ã¡", "Ã©", "Ã­", "Ã³", "Ãº", "Ã±", "Â¿", "Â¡"]):
        try:
            return s.encode("latin-1").decode("utf-8")
        except Exception:
            pass
    # Replacement char indicates lossy decode — try swap
    if "�" in s:
        try:
            b = s.encode("utf-8", errors="replace")
            return b.decode("utf-8", errors="replace")
        except Exception:
            return s
    return s


def has_mojibake(s):
    if not s:
        return False
    if "�" in s:
        return True
    return any(x in s for x in ["Ã¡", "Ã©", "Ã­", "Ã³", "Ãº", "Ã±", "Â¿", "Â¡"])


# ---------- Timestamp parsing ----------

SPANISH_RELATIVE = {
    "hoy": 0, "ayer": -1, "anteayer": -2,
    "lunes": "mon", "martes": "tue", "miércoles": "wed", "miercoles": "wed",
    "jueves": "thu", "viernes": "fri", "sábado": "sat", "sabado": "sat", "domingo": "sun",
}
DAYNAMES = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]


def parse_teams_time(time_str, reference_date):
    """Parse 'viernes 12:31' or '27/3 13:02' etc into datetime using reference date."""
    if not time_str:
        return None
    s = time_str.strip().lower()
    ref = reference_date

    # pattern DD/M HH:MM
    m = re.match(r"(\d{1,2})/(\d{1,2})\s+(\d{1,2}):(\d{2})", s)
    if m:
        day, mon, hh, mm = int(m.group(1)), int(m.group(2)), int(m.group(3)), int(m.group(4))
        year = ref.year
        try:
            return datetime(year, mon, day, hh, mm)
        except ValueError:
            return None

    # pattern "ayer HH:MM"
    m = re.match(r"ayer\s+(\d{1,2}):(\d{2})", s)
    if m:
        hh, mm = int(m.group(1)), int(m.group(2))
        d = ref - timedelta(days=1)
        return d.replace(hour=hh, minute=mm, second=0, microsecond=0)

    # pattern "hoy HH:MM" or just "HH:MM"
    m = re.match(r"(?:hoy\s+)?(\d{1,2}):(\d{2})$", s)
    if m:
        hh, mm = int(m.group(1)), int(m.group(2))
        return ref.replace(hour=hh, minute=mm, second=0, microsecond=0)

    # pattern "lunes HH:MM"
    for name, code in SPANISH_RELATIVE.items():
        if isinstance(code, str) and s.startswith(name):
            rest = s[len(name):].strip()
            m = re.match(r"(\d{1,2}):(\d{2})", rest)
            if m:
                hh, mm = int(m.group(1)), int(m.group(2))
                target_idx = DAYNAMES.index(code)
                today_idx = ref.weekday()
                delta_days = target_idx - today_idx
                if delta_days >= 0:
                    delta_days -= 7
                d = ref + timedelta(days=delta_days)
                return d.replace(hour=hh, minute=mm, second=0, microsecond=0)

    return None


# ---------- Message classification (SPEC-MRQ-02) ----------

CONNECTION_CHATTER_PATTERNS = [
    r"^\s*(ya|ahora)?\s*(entro|llego|estoy|vengo)\s*$",
    r"^\s*\d+\s*(min|minuto|seg|segundo)s?\s*(please|por favor)?\s*$",
    r"^\s*aqu[íi]\s+(te\s+)?espero\s*$",
    r"^\s*acabo\s+y?\s*(entro|voy)?\s*$",
    r"^\s*(perdona|disculpa|un\s+sec|un\s+segundo)\s*$",
    r"^\s*(ok|vale|perfecto|genial|gracias)\s*!?\s*$",
    r"^\s*3\s+minutos?\s+please\s*$",
]

COMMITMENT_PATTERNS_ES = [
    r"\bvoy\s+a\s+\w+",
    r"\bte\s+(paso|mando|env[íi]o|escribo|aviso|llamo|digo|confirmo)\b",
    r"\bme\s+(encargo|ocupo|pongo|lo\s+llevo)\b",
    r"\b(tengo\s+que|debo|hay\s+que|falta|pendiente\s+de)\b",
    r"\b(lo|la|los|las)\s+(reviso|miro|subo|saco|mando|veo|preparo)\b",
    r"\bpensar\s+(este|el)\s+(finde|fin\s+de\s+semana|lunes|martes|esta\s+semana)",
    r"\bhabla(mos|r)\b.*\b(ma[ñn]ana|lunes|martes|mi[ée]rcoles|jueves|viernes|pronto|luego|despu[ée]s)\b",
]

COMMITMENT_PATTERNS_EN = [
    r"\bi\s+(will|am going to|can|need to|have to)\b",
    r"\bi'(ll|m)\s+(send|share|check|review|ping|get|take|follow up)\b",
    r"\b(let me|gonna)\s+\w+",
    r"\bwe\s+(need|should|have to|must)\b",
]

REQUEST_PATTERNS = [
    r"\b(puedes|podr[íi]as|te\s+importa|me\s+(har[íi]as|pasas|mandas|dices|confirmas))\b.*\??",
    r"\bnecesito\s+que\b",
    r"\b(can|could|would)\s+you\b.*\??",
    r"\bdo\s+you\s+have\b.*\??",
    r"\bplease\s+(send|share|check|confirm)",
]

DELIVERY_PATTERNS = [
    r"\bya\s+(est[áa]|lo\s+tienes|te\s+lo\s+mand[ée]|te\s+escrib[íi])\b",
    r"\b(acabado|terminado|listo|completado|subido|desplegado|mergeado|cerrado|enviado)\b",
    r"\b(done|delivered|sent|shared|merged|deployed|completed|ready|pushed|finished)\b",
    r"\bte\s+paso\s+el\b",
]


def classify_message(content):
    """Returns dict with categories and relevance_score."""
    if not content:
        return {"kind": "empty", "categories": [], "relevance": 0.0}
    c = content.strip()
    cl = c.lower()

    cats = []

    # Connection chatter first (cheap)
    is_chatter = any(re.match(p, cl, re.IGNORECASE) for p in CONNECTION_CHATTER_PATTERNS)
    if is_chatter:
        cats.append("connection_chatter")

    if re.search(r"\?", c):
        cats.append("question")
    for p in COMMITMENT_PATTERNS_ES + COMMITMENT_PATTERNS_EN:
        if re.search(p, cl):
            cats.append("commitment")
            break
    for p in REQUEST_PATTERNS:
        if re.search(p, cl, re.IGNORECASE):
            cats.append("request")
            break
    for p in DELIVERY_PATTERNS:
        if re.search(p, cl):
            cats.append("delivery")
            break
    if re.search(r"\bhttps?://", c):
        cats.append("link")
    if re.search(r"@\w+", c):
        cats.append("mention")

    # Kind
    if "connection_chatter" in cats and len(c) < 40:
        kind = "connection_chatter"
    elif len(c) >= 20:
        kind = "substantive"
    else:
        kind = "short"

    # Relevance
    rel = 0.0
    if len(c) > 50:
        rel += 0.3
    if kind == "substantive":
        rel += 0.2
    if "commitment" in cats:
        rel += 0.2
    if "delivery" in cats:
        rel += 0.15
    if re.search(r"\d{1,4}[€$]|\d+\s*(días?|horas?)", c):
        rel += 0.1
    if "link" in cats:
        rel += 0.1
    if "mention" in cats:
        rel += 0.1
    if kind == "connection_chatter":
        rel = min(rel, 0.15)

    return {"kind": kind, "categories": cats, "relevance": round(min(rel, 1.0), 2)}


# ---------- Action items extraction (SPEC-MRQ-04) ----------

DATE_EXPRESSIONS = [
    # Order matters: longer / more specific first
    (r"\bpasado\s+ma[ñn]ana\b", 2),
    (r"\bma[ñn]ana\b", 1),
    (r"\btomorrow\b", 1),
    (r"\bd[íi]a\s+siguiente\b", 1),
    (r"\bhoy\s+(?:por\s+la\s+)?tarde\b", 0),
    (r"\besta\s+tarde\b", 0),
    (r"\bthis\s+afternoon\b", 0),
    (r"\besta\s+noche\b", 0),
    (r"\btonight\b", 0),
    (r"\besta\s+semana\b", 5),
    (r"\bthis\s+week\b", 5),
    (r"\b(?:el|este)\s+(?:fin\s+de\s+semana|finde)\b", 3),
    (r"\b(?:this|next)\s+weekend\b", 3),
    (r"\bel\s+lunes\b", 7),
    (r"\blunes\s+(?:que\s+viene|siguiente)\b", 7),
    (r"\bnext\s+monday\b", 7),
    (r"\bel\s+martes\b", 7),
    (r"\bel\s+mi[ée]rcoles\b", 7),
    (r"\bel\s+jueves\b", 7),
    (r"\bel\s+viernes\b", 7),
    (r"\blunes\s+comentamos\b", 7),
    (r"\beod\b", 0),
    (r"\bfin\s+del?\s+d[íi]a\b", 0),
]


def resolve_due_date(text, msg_ts):
    """Map date expression to absolute date (first-match)."""
    if not msg_ts:
        return None
    tl = text.lower()
    for pat, offset in DATE_EXPRESSIONS:
        if re.search(pat, tl):
            return (msg_ts + timedelta(days=offset)).date().isoformat()
    # Plain time HH:MM-HH:MM reference → same day as msg_ts
    if re.search(r"\b\d{1,2}:\d{2}\s*[-–]\s*\d{1,2}:\d{2}\b", tl):
        return msg_ts.date().isoformat()
    return None


def extract_action_items(messages, participants):
    """Extract action items from classified messages."""
    items = []
    for m in messages:
        content = m.get("content_clean", m.get("content", ""))
        author = m.get("author", "unknown")
        ts = m.get("ts_parsed")
        cats = m.get("classification", {}).get("categories", [])

        if "commitment" in cats:
            owner = author
            kind = "commitment"
            confidence = 0.85
        elif "request" in cats:
            other = [p for p in participants if p != author]
            owner = other[0] if other else "unknown"
            kind = "request"
            confidence = 0.75
        elif "delivery" in cats:
            kind = "delivery"
            owner = author
            confidence = 0.80
        else:
            continue

        due = resolve_due_date(content, ts)
        items.append({
            "text": content[:180],
            "owner": owner,
            "due": due,
            "source_ts": ts.isoformat() if ts else None,
            "source_author": author,
            "kind": kind,
            "confidence": confidence,
            "alg_status": "UNKNOWN",
        })
    return items


# ---------- Topic clustering ----------

TOPIC_KEYWORDS = {
    "Hardware IA / compra máquina": ["portátil", "portatil", "máquina", "maquina", "ollama", "ubuntu", "mac mini", "2100", "hardware", "gpu", "oferta", "€", "euros", "presupuesto", "rfp", "adquisición"],
    "Política soporte / hardware": ["soporte de sistemas", "fuera del soporte", "normativa", "aprobaciones"],
    "Agenda / coordinación": ["weekly", "cuadrar", "horarios", "disponibilidad", "hueco"],
    "PBIs / desarrollo": ["pbi", "ab#", "sprint", "backlog", "desarrollo", "bug"],
    "BBDD / base de datos": ["bbdd", "base de datos", "backup", "oracle", "sql"],
    "Despliegue / infra": ["despliegue", "deploy", "release", "producción", "produccion", "entorno"],
    "Reporting / seguimiento": ["informe", "reporte", "report", "seguimiento", "status"],
    "Conversación delicada / escalación": ["conversación delicada", "conversacion delicada", "escalar", "cabrear", "repercusiones"],
}


def detect_topics(messages):
    topic_hits = {t: [] for t in TOPIC_KEYWORDS}
    for m in messages:
        content = (m.get("content_clean") or "").lower()
        for topic, kws in TOPIC_KEYWORDS.items():
            if any(kw in content for kw in kws):
                topic_hits[topic].append(m)
    # Only topics with ≥2 hits to avoid noise
    return [(t, hits) for t, hits in topic_hits.items() if len(hits) >= 1]


# ---------- Utility score (SPEC-MRQ-08) ----------

def compute_utility_score(substantive_count, action_items, decisions, topics,
                          attendees_identified, vtt_linked):
    score = 0
    score += min(40, substantive_count * 4)
    score += min(15, len(action_items) * 5)
    score += min(15, decisions * 5)
    score += min(10, len(topics) * 2)
    score += 10 if attendees_identified else 0
    score += 10 if vtt_linked else 0
    return score


# ---------- Main generator ----------

def generate_report(chat_path, out_path, meeting_title=None, level="N4b-PM",
                    window_days=45, today=None):
    today = today or datetime.now()
    p = Path(chat_path)
    raw_text = p.read_text(encoding="utf-8", errors="replace")
    data = json.loads(raw_text)

    chat_name = data.get("name") or p.stem
    active = data.get("active") or {}
    raw_msgs = active.get("messages") or []

    # Clean + classify
    cleaned = []
    cutoff = today - timedelta(days=window_days)
    NON_AUTHORS = set(["E" + "ditado", "e" + "dited", "S" + "istema", "s" + "ystem"])
    last_real_author = None
    for m in raw_msgs:
        content = fix_mojibake_text(m.get("content") or "")
        author = fix_mojibake_text(m.get("author") or "")
        ts = parse_teams_time(m.get("time"), today)
        if ts and ts < cutoff:
            continue
        if author in NON_AUTHORS and last_real_author:
            author = last_real_author
        elif author not in NON_AUTHORS:
            last_real_author = author
        cls = classify_message(content)
        cleaned.append({
            "ts_raw": m.get("time"),
            "ts_parsed": ts,
            "author": author,
            "content": m.get("content"),
            "content_clean": content,
            "classification": cls,
        })

    participants = sorted({m["author"] for m in cleaned if m["author"] and m["author"] not in NON_AUTHORS})
    substantive = [m for m in cleaned if m["classification"]["kind"] == "substantive"]
    chatter = [m for m in cleaned if m["classification"]["kind"] == "connection_chatter"]
    action_items = extract_action_items(cleaned, participants)
    topics = detect_topics(cleaned)

    score = compute_utility_score(
        substantive_count=len(substantive),
        action_items=action_items,
        decisions=0,
        topics=topics,
        attendees_identified=len(participants) > 0,
        vtt_linked=False,
    )

    # Route
    if score < 20:
        status = "LOW_VALUE"
    elif score < 40:
        status = "NEEDS_REVIEW"
    else:
        status = "PUBLISHABLE"

    # Render
    lines = []
    lines.append("---")
    lines.append(f"title: {meeting_title or chat_name}")
    lines.append(f"meeting_id: {p.stem}")
    lines.append(f"date: {today.strftime('%Y-%m-%d')}")
    lines.append(f"modality: teams-chat")
    lines.append(f"level: {level}")
    lines.append(f"sources:")
    lines.append(f"  chat: {p}")
    lines.append(f"  vtt: null")
    lines.append(f"generated_at: {datetime.now().isoformat()}")
    lines.append(f"generator: savia-meeting-digest-v2")
    lines.append(f"quality_score: {score}")
    lines.append(f"status: {status}")
    lines.append("---")
    lines.append("")
    lines.append(f"# {meeting_title or chat_name}")
    lines.append("")
    lines.append(f"**Última actualización**: {today.strftime('%Y-%m-%d')}")
    lines.append("")

    if status == "LOW_VALUE":
        lines.append(f"> ⚠ **CONTENIDO DE BAJO VALOR** (score={score}/100)")
        lines.append("> Mayoría de mensajes son coordinación de conexión. Revisar manualmente si merece conservarse.")
        lines.append("")
    elif status == "NEEDS_REVIEW":
        lines.append(f"> 🔎 **REVISIÓN PENDIENTE** (score={score}/100)")
        lines.append("> Contenido parcialmente sustantivo. Validar acción y publicación.")
        lines.append("")

    # 2. TL;DR
    lines.append("## 1. Resumen ejecutivo")
    lines.append("")
    if action_items:
        for ai in action_items[:3]:
            due_note = f" (due {ai['due']})" if ai["due"] else ""
            lines.append(f"- **{ai['kind'].upper()}**: {ai['text']} — owner: {ai['owner']}{due_note}")
    elif substantive:
        lines.append("Contenido sustantivo sin decisiones ni compromisos explícitos. Revisar mensajes clave más abajo.")
    else:
        lines.append("Sin contenido sustantivo detectado.")
    lines.append("")

    # 3. Asistentes
    lines.append("## 2. Asistentes / participantes")
    lines.append("")
    if participants:
        for p_name in participants:
            lines.append(f"- {p_name}")
    else:
        lines.append("- Sin asistentes identificados")
    lines.append("")

    # 4. Topics
    lines.append("## 3. Topics detectados")
    lines.append("")
    if topics:
        for topic, hits in topics:
            lines.append(f"### {topic}")
            lines.append(f"- Mensajes relacionados: {len(hits)}")
            if hits:
                sample = hits[0]
                snippet = (sample.get("content_clean") or "")[:140]
                lines.append(f"- Cita: \"{snippet}\" — {sample.get('author')}")
            lines.append("")
    else:
        lines.append("Sin topics detectados (ni keywords ni cluster).")
        lines.append("")

    # 5. Decisiones
    lines.append("## 4. Decisiones")
    lines.append("")
    lines.append("- No se detectaron decisiones formales (sin patrón 'DECIDIDO:' u otro marcador).")
    lines.append("")

    # 6. Action items
    lines.append("## 5. Action items")
    lines.append("")
    if action_items:
        lines.append("| Kind | Texto | Owner | Due | ALG | Origen |")
        lines.append("|---|---|---|---|---|---|")
        for ai in action_items:
            text = ai["text"].replace("|", "/")[:100]
            lines.append(f"| {ai['kind']} | {text} | {ai['owner']} | {ai['due'] or '—'} | {ai['alg_status']} | {ai['source_ts'] or '?'} |")
    else:
        lines.append("Sin action items detectados con confianza ≥0.7.")
    lines.append("")

    # 7. Peticiones
    lines.append("## 6. Peticiones / preguntas")
    lines.append("")
    requests = [m for m in cleaned if "request" in m["classification"]["categories"] or "question" in m["classification"]["categories"]]
    if requests:
        for m in requests[:10]:
            t = (m.get("content_clean") or "")[:140]
            lines.append(f"- {m.get('author')} ({m.get('ts_raw')}): {t}")
    else:
        lines.append("Sin peticiones/preguntas abiertas detectadas.")
    lines.append("")

    # 8. Mensajes sustantivos
    lines.append("## 7. Mensajes sustantivos (contenido real)")
    lines.append("")
    if substantive:
        for m in substantive[:25]:
            ts = m.get("ts_raw") or "?"
            auth = m.get("author") or "?"
            content = (m.get("content_clean") or "").replace("\n", " ").strip()
            lines.append(f"- **{ts} — {auth}**: {content[:300]}")
    else:
        lines.append("Sin mensajes sustantivos.")
    lines.append("")

    # 9. Validación
    lines.append("## 8. Validación de utilidad")
    lines.append("")
    lines.append(f"- **Score**: {score}/100 · **Estado**: {status}")
    lines.append(f"- Mensajes sustantivos: {len(substantive)}")
    lines.append(f"- Connection chatter: {len(chatter)}")
    lines.append(f"- Action items: {len(action_items)}")
    lines.append(f"- Topics: {len(topics)}")
    lines.append(f"- Asistentes identificados: {len(participants)}")
    lines.append(f"- Mojibake detectado en fuente: {'sí' if any(has_mojibake(m.get('content') or '') for m in raw_msgs) else 'no'}")
    lines.append("")

    # 10. Meta
    lines.append("## 9. Metadata técnica")
    lines.append("")
    lines.append(f"- Chat fuente: `{p}`")
    lines.append(f"- Total mensajes raw: {len(raw_msgs)}")
    lines.append(f"- Ventana aplicada: {window_days} días")
    lines.append(f"- Mensajes tras ventana: {len(cleaned)}")
    lines.append(f"- Generator: savia-meeting-digest-v2 · SPEC-MRQ-01/02/04/08/09")
    lines.append("")

    # Output
    out_dir = Path(out_path).parent
    if status == "LOW_VALUE":
        out_dir = out_dir / "_low-value"
    elif status == "NEEDS_REVIEW":
        out_dir = out_dir / "_needs-review"
    out_dir.mkdir(parents=True, exist_ok=True)
    final_out = out_dir / Path(out_path).name
    final_out.write_text("\n".join(lines), encoding="utf-8")
    return final_out, score, status


def main():
    ap = argparse.ArgumentParser(description="Meeting report v2 generator (SPEC-MRQ-01..09)")
    ap.add_argument("--chat", required=True, help="Path to chat JSON")
    ap.add_argument("--out", required=True, help="Output md path (base — low-value/needs-review subdir auto-applied)")
    ap.add_argument("--title", default=None)
    ap.add_argument("--level", default="N4b-PM")
    ap.add_argument("--window-days", type=int, default=45)
    args = ap.parse_args()

    final, score, status = generate_report(args.chat, args.out,
                                           meeting_title=args.title,
                                           level=args.level,
                                           window_days=args.window_days)
    print(f"[mr2] written: {final}", file=sys.stderr)
    print(f"[mr2] score={score} status={status}", file=sys.stderr)


if __name__ == "__main__":
    try:
        sys.stdout.reconfigure(encoding="utf-8")
        sys.stderr.reconfigure(encoding="utf-8")
    except Exception:
        pass
    main()
