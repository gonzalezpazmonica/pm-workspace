"""Conversation Model — Human turn-taking behavior as code.

Based on Sacks-Schegloff-Jefferson turn-taking model (1974),
Jefferson's overlap taxonomy, Truong's overlap classification (2013),
Krisp turn-taking model (2025), and CHI 2025 research on
LLM agents with interruption + backchannel support.

KEY INSIGHT (from user feedback): Savia should almost NEVER stop
talking when the user overlaps. Humans talk over each other
constantly — to agree, emphasize, react, joke. Only EXPLICIT
stop commands ("para", "cállate") should interrupt Savia.

Everything else: Savia keeps talking AND records what the user
said for context. After finishing her turn, she processes
the overlap as a follow-up message.
"""

# ── Explicit stop commands — ONLY these interrupt Savia ─────────────────
# These are deliberate, unambiguous commands to stop.
STOP_COMMANDS = {
    "para", "para para", "párate", "cállate", "callate",
    "stop", "basta", "silencio", "espera espera",
    "déjalo", "dejalo", "olvídalo", "olvidalo",
}

# ── Backchannel words — user is just agreeing/reacting ──────────────────
BACKCHANNEL_ES = {
    "sí", "si", "claro", "vale", "ya", "ok", "okay", "bien",
    "exacto", "exactamente", "correcto", "eso", "ajá", "aja",
    "mm", "mhm", "hmm", "ah", "oh", "uhm",
    "venga", "genial", "perfecto", "entiendo", "entendido",
    "de acuerdo", "por supuesto", "efectivamente",
    "no me digas", "madre mía", "vaya", "jolín",
    "verdad", "cierto", "interesante", "oye qué bien",
}


class OverlapType:
    BACKCHANNEL = "backchannel"
    COLLABORATIVE = "collaborative"
    STOP = "stop"
    FOLLOWUP = "followup"


def classify_overlap(transcribed_text, duration_seconds, savia_was_speaking):
    """Classify overlap. Returns (OverlapType, action).

    Actions:
      "ignore"   — discard, Savia keeps talking
      "listen"   — Savia keeps talking, but queue text as follow-up
      "stop"     — Savia stops immediately
      "process"  — normal turn (Savia was not speaking)
    """
    if not savia_was_speaking:
        return OverlapType.FOLLOWUP, "process"

    text = transcribed_text.lower().strip()
    words = text.split()

    # Rule 1: Explicit stop command → always stop
    if text in STOP_COMMANDS:
        return OverlapType.STOP, "stop"
    # Also check first 2 words for "para para" patterns
    if len(words) >= 2 and " ".join(words[:2]) in STOP_COMMANDS:
        return OverlapType.STOP, "stop"
    if words and words[0] in {"para", "cállate", "callate", "stop", "basta"}:
        return OverlapType.STOP, "stop"

    # Rule 2: Short backchannel → ignore completely
    if duration_seconds < 2.0 and len(words) <= 3:
        if any(w in BACKCHANNEL_ES for w in words):
            return OverlapType.BACKCHANNEL, "ignore"

    # Rule 3: Everything else → Savia keeps talking, but LISTENS
    # After Savia finishes her turn, she processes this as a follow-up.
    # This covers: emphasis, jokes, comments, elaborations, corrections.
    return OverlapType.COLLABORATIVE, "listen"
