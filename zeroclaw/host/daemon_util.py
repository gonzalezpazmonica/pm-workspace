"""SaviaClaw daemon utilities — shared between daemon and status CLI."""
import subprocess
import json
import time
import os

LOG_DIR = os.path.expanduser("~/.savia/zeroclaw")
LOG_FILE = os.path.join(LOG_DIR, "daemon.log")
STATUS_FILE = os.path.join(LOG_DIR, "status.json")
PORTS = ["/dev/ttyUSB0", "/dev/ttyUSB1", "/dev/ttyACM0"]
BAUD = 115200
RECONNECT_DELAY = 5
HEARTBEAT_INTERVAL = 30
STUCK_TIMEOUT = 120


def find_port():
    for p in PORTS:
        if os.path.exists(p):
            return p
    return None


def send_cmd(ser, text, wait=2):
    ser.write((text + "\r\n").encode())
    ser.flush()
    time.sleep(wait)
    return ser.read(ser.in_waiting).decode("utf-8", errors="ignore").strip()


def call_llm(question):
    """Provider-agnostic LLM call using OpenCode + DeepSeek v4-pro.
    Maintains same interface as the old call_claude() for backward compat."""
    from .llm_backend import talk_reply
    return talk_reply(question)


def truncate_lcd(text):
    clean = text.replace("\n", " ").strip()
    l1 = clean[:16]
    l2 = clean[16:32] if len(clean) > 16 else ""
    return l1, l2


def lcd_task_status(name, result):
    """Meaningful 16-char/line LCD message for a completed task."""
    import json as _j
    t = time.strftime("%H:%M")
    if name == "check-talk":
        return "Talk: escucho", f"OK {t}"
    if name == "check-gmail":
        return "Gmail: leido", f"OK {t}"
    if name == "sensor-check" and result:
        try:
            for part in str(result).split("\r\n"):
                if not part.strip():
                    continue
                d = _j.loads(part)
                if d.get("cmd") == "sensors":
                    sd = d.get("data", {})
                    temp = sd.get("internal_temp_f", "?")
                    ram = sd.get("free_ram", 0) // 1024
                    return f"Temp:{temp}F", f"RAM:{ram}K {t}"
        except Exception:
            pass
        return "Sensores OK", t
    if name == "git-status":
        lines = [l for l in (result or "").split("\n") if l.strip()]
        l1 = "Git: limpio" if not lines else f"Git:{len(lines)} cambios"
        return l1, t
    if name == "memory-consolidate":
        return "Memoria sync", t
    if name == "gdrive-sync":
        return "Drive sync OK", t
    if not result:
        return f"{name[:10]}: FALLO", t
    return f"{name[:10]}: OK", t


def write_status(state, port=None, extra=None):
    data = {
        "state": state, "port": port, "pid": os.getpid(),
        "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }
    if extra:
        data.update(extra)
    try:
        os.makedirs(LOG_DIR, exist_ok=True)
        with open(STATUS_FILE, "w") as f:
            json.dump(data, f)
    except OSError:
        pass


def show_status():
    if not os.path.isfile(STATUS_FILE):
        print("No status file — daemon may not have run yet.")
        return
    with open(STATUS_FILE) as f:
        data = json.load(f)
    pid = data.get("pid")
    alive = False
    if pid:
        try:
            os.kill(pid, 0)
            alive = True
        except OSError:
            pass
    print(f"State:   {data.get('state', '?')}")
    print(f"Port:    {data.get('port', 'none')}")
    print(f"PID:     {pid} ({'running' if alive else 'dead'})")
    print(f"Updated: {data.get('ts', '?')}")
    if "queries" in data:
        print(f"Queries: {data['queries']}")
