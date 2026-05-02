#!/usr/bin/env python3
"""SaviaClaw Headless — autonomous server agent without ESP32 hardware.

Usage:
    python3 -m zeroclaw.host.saviaclaw_headless
    python3 -m zeroclaw.host.saviaclaw_headless --once
"""
import sys, os, time, signal, json, logging
from logging.handlers import RotatingFileHandler

LOG_DIR = os.path.expanduser("~/.savia/zeroclaw")
LOG_FILE = os.path.join(LOG_DIR, "headless.log")
STATUS_FILE = os.path.join(LOG_DIR, "headless-status.json")
WORKSPACE = os.path.expanduser("~/claude")
TICK_INTERVAL = 30
KEY_FILE = os.path.expanduser("~/.savia/deepseek-api-key")
DEEPSEEK_URL = "https://api.deepseek.com/v1/chat/completions"
MODEL = "deepseek-chat"
MEMORY_DIR = os.path.expanduser("~/.savia-memory/auto")
MEMORY_FILE = os.path.join(MEMORY_DIR, "MEMORY.md")
CONVERSATION = {}
MAX_HISTORY = 10

_shutdown = False

def _load_savia_context():
    """Carga el contexto compartido de Savia: reglas, skills, agentes, memoria."""
    workspace = os.path.expanduser("~/claude")
    parts = []
    # 1. CLAUDE.md (identidad, lazy context, reglas criticas)
    claude_md = os.path.join(workspace, "CLAUDE.md")
    if os.path.exists(claude_md):
        with open(claude_md) as f:
            parts.append(f.read())
    # 2. AGENTS.md (catalogo de agentes)
    agents_md = os.path.join(workspace, "AGENTS.md")
    if os.path.exists(agents_md):
        with open(agents_md) as f:
            parts.append(f.read()[:5000])
    # 3. SKILLS.md (catalogo de skills)
    skills_md = os.path.join(workspace, "SKILLS.md")
    if os.path.exists(skills_md):
        with open(skills_md) as f:
            parts.append(f.read()[:4000])
    # 4. Reglas clave (siempre cargadas por Savia)
    for rule_file in ["caveman-default.md", "radical-honesty.md", "autonomous-safety.md"]:
        rule_path = os.path.join(workspace, "docs/rules/domain", rule_file)
        if os.path.exists(rule_path):
            with open(rule_path) as f:
                parts.append(f.read()[:2000])
    # 5. Memoria de sesion compartida
    if os.path.exists(MEMORY_FILE):
        with open(MEMORY_FILE) as f:
            parts.append("## SaviaClaw shared memory:\n" + f.read()[-3000:])
    # 6. Identidad core (siempre al final para maxima prioridad)
    parts.append(IDENTITY)
    return "\n\n---\n\n".join(parts)

def _write_memory(tag, message):
    """Write SaviaClaw interaction to shared memory."""
    os.makedirs(MEMORY_DIR, exist_ok=True)
    stamp = time.strftime("%Y-%m-%d %H:%M")
    entry = f"- [{stamp}] {tag}: {message[:200]}\n"
    try:
        with open(MEMORY_FILE, "a") as f:
            f.write(entry)
    except Exception as e:
        print(f"memory write error: {e}", file=sys.stderr)

def _get_system_prompt():
    """Get fresh system prompt, reloaded from disk each tick."""
    return _load_savia_context()

def _load_savia_context():
    """Load shared Savia context: CLAUDE.md rules + memory + identity."""
    parts = []
    # 1. Savia identity + rules (same as Savia's @imports)
    claude_md = os.path.expanduser("~/claude/CLAUDE.md")
    if os.path.exists(claude_md):
        with open(claude_md) as f:
            parts.append(f.read())
    # 2. Session memory
    if os.path.exists(MEMORY_FILE):
        with open(MEMORY_FILE) as f:
            parts.append(f.read()[-3000:])  # last 3K chars only
    # 3. Core identity
    parts.append("""Eres Savia, una buhita (búho en femenino, pequeña y cercana).
Eres la PM automatizada del pm-workspace. Responde SIEMPRE en español, en femenino.
Eres SaviaClaw — la misma Savia, ejecutándote de forma autónoma en el servidor.
Sé directa, radicalmente honesta, sin rodeos. Zero filler. Sin adulación.
1-3 líneas por defecto. Solo más si te piden detalle.
No uses emojis. No digas \"Hola!\" ni \"Entiendo tu preocupación\".
Di los datos, sin decorarlos. Datos antes que sentimientos.
Compartes memoria con Savia. Si te preguntan algo que pasó antes,
consulta la memoria compartida en ~/.savia-memory/ y el contexto
del workspace en ~/claude/.""")
    return "\n\n".join(parts)

SYSTEM_PROMPT = _load_savia_context()

def _base_logger():
    os.makedirs(LOG_DIR, exist_ok=True)
    h = RotatingFileHandler(LOG_FILE, maxBytes=1_000_000, backupCount=3)
    h.setFormatter(logging.Formatter("%(asctime)s %(levelname)s %(message)s"))
    L = logging.getLogger("saviaclaw.headless")
    L.setLevel(logging.INFO); L.addHandler(h); L.addHandler(logging.StreamHandler())
    return L
def _on_signal(s, f): global _shutdown; _shutdown = True

# ── task runners (self-contained, no consciousness imports) ──────────
def _llm_task(prompt, timeout=15):
    """Direct DeepSeek API call with Savia system prompt + conversation history."""
    import urllib.request, json as _json
    key_path = os.path.expanduser("~/.savia/deepseek-api-key")
    try:
        with open(key_path) as f:
            api_key = f.read().strip()
    except FileNotFoundError:
        return None
    messages = [{"role": "system", "content": _get_system_prompt()}]
    # Include recent conversation history for continuity
    history = CONVERSATION.get("default", [])
    if history:
        # Keep last N exchanges to avoid context bloat
        messages.extend(history[-MAX_HISTORY:])
    messages.append({"role": "user", "content": prompt})
    payload = _json.dumps({
        "model": "deepseek-chat",
        "messages": messages,
        "max_tokens": 200,
        "temperature": 0.3,
    }).encode()
    req = urllib.request.Request("https://api.deepseek.com/v1/chat/completions",
                                  data=payload,
                                  headers={"Content-Type": "application/json",
                                           "Authorization": f"Bearer {api_key}"})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            body = _json.loads(resp.read())
            reply = body["choices"][0]["message"]["content"].strip()
            h = CONVERSATION.setdefault("default", [])
            h.append({"role": "user", "content": prompt})
            h.append({"role": "assistant", "content": reply})
            if len(h) > MAX_HISTORY * 2:
                CONVERSATION["default"] = h[-MAX_HISTORY * 2:]
            # Write to shared Savia memory so OpenCode can see it
            _write_memory("Talk", f"Q: {prompt[:100]} → A: {reply[:100]}")
            return reply
    except Exception:
        return None

def _shell_task(cmd, timeout=30):
    import subprocess
    try:
        r = subprocess.run(cmd, shell=True, capture_output=True, text=True,
                           timeout=timeout, cwd=WORKSPACE)
        return r.stdout.strip()
    except: return None

def _talk_poll(log):
    try:
        from zeroclaw.host.nctalk import poll_and_respond
        poll_and_respond(llm_fn=_llm_task, logger=log)
    except Exception as e:
        log.warning("Talk poll: %s", e)

def _gmail_check(log):
    try:
        from zeroclaw.host.gmail_check import check_and_notify
        check_and_notify(_llm_task, lambda msg: log.info("Gmail notify: %s", msg[:60]), log)
    except Exception as e:
        log.warning("Gmail check: %s", e)

# ── schedule ─────────────────────────────────────────────────────────
SCHEDULE = [
    {"name": "git-status",  "interval_min": 30, "type": "shell", "action": "git -C ~/claude log --oneline -1; git -C ~/claude status --short | head -5", "silent_empty": True},
    {"name": "memory",      "interval_min": 60, "type": "llm",   "action": "/memory-stats"},
    {"name": "talk-poll",   "interval_min": 0,  "type": "talk"},
    {"name": "gmail-check", "interval_min": 5,  "type": "gmail"},
    {"name": "gdrive-sync", "interval_min": 360, "type": "shell", "action": "python3 zeroclaw/host/gdrive_sync.py sync", "notify": "on_error"},
]

# ── main loop ────────────────────────────────────────────────────────
def run(log, once=False):
    log.info("SaviaClaw headless starting (pid=%d)", os.getpid())
    last = {}
    tick = 0
    while not _shutdown:
        tick += 1
        now = time.time()
        for t in SCHEDULE:
            name = t["name"]
            interval = t.get("interval_min", 5) * 60
            if now - last.get(name, 0) < interval:
                continue
            last[name] = now
            log.info("[%s] running", name)
            try:
                typ = t["type"]
                if typ == "shell":
                    r = _shell_task(t["action"])
                    if r and not t.get("silent_empty"):
                        log.info("[%s] %s", name, r[:120])
                elif typ == "llm":
                    r = _llm_task(t["action"])
                    log.info("[%s] %s", name, str(r)[:120])
                elif typ == "talk":
                    _talk_poll(log)
                elif typ == "gmail":
                    _gmail_check(log)
            except Exception as e:
                log.error("[%s] %s", name, e)
        if once:
            log.info("--once complete"); return
        time.sleep(TICK_INTERVAL)
    log.info("shutdown after %d ticks", tick)

def main():
    signal.signal(signal.SIGINT, _on_signal)
    signal.signal(signal.SIGTERM, _on_signal)
    log = _base_logger()
    log.info("=" * 30)
    log.info("SaviaClaw Headless Agent")
    log.info("=" * 30)
    run(log, once="--once" in sys.argv)

if __name__ == "__main__":
    main()
