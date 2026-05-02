#!/usr/bin/env python3
"""SaviaClaw via ACP — usa OpenCode Agent Client Protocol como backend.

Inicia 'opencode acp' como subproceso y se comunica via JSON-RPC stdio.
OpenCode maneja: contexto del workspace, herramientas (Read/Write/Edit/Bash),
hooks, skills, reglas. SaviaClaw solo enruta Talk → ACP → Talk.
"""
import os, sys, time, json, subprocess, signal, threading, logging
from logging.handlers import RotatingFileHandler

LOG_DIR = os.path.expanduser("~/.savia/zeroclaw")
LOG_FILE = os.path.join(LOG_DIR, "acp.log")
WORKSPACE = os.path.expanduser("~/claude")
MEMORY_FILE = os.path.expanduser("~/.savia-memory/auto/MEMORY.md")

_shutdown = False
_acp_proc = None
_msg_id = 0

def _log():
    os.makedirs(LOG_DIR, exist_ok=True)
    h = RotatingFileHandler(LOG_FILE, maxBytes=500_000, backupCount=2)
    h.setFormatter(logging.Formatter("%(asctime)s %(levelname)s %(message)s"))
    L = logging.getLogger("saviaclaw.acp")
    L.setLevel(logging.INFO); L.addHandler(h); L.addHandler(logging.StreamHandler())
    return L

def _start_opencode(log):
    """Inicia opencode acp como subproceso JSON-RPC."""
    global _acp_proc
    try:
        _acp_proc = subprocess.Popen(
            ["opencode", "acp"],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            text=True, cwd=WORKSPACE,
            env={**os.environ, "PATH": os.path.expanduser("~/.opencode/bin") + ":" + os.environ.get("PATH", "")}
        )
        log.info("OpenCode ACP started (pid=%d)", _acp_proc.pid)
        return True
    except Exception as e:
        log.error("Failed to start opencode ACP: %s", e)
        return False

def _acp_call(method, params=None, timeout=30):
    """Envía mensaje JSON-RPC a OpenCode ACP y espera respuesta."""
    global _msg_id, _acp_proc
    if _acp_proc is None or _acp_proc.poll() is not None:
        return None
    _msg_id += 1
    req = json.dumps({"jsonrpc": "2.0", "id": _msg_id, "method": method, "params": params or {}}) + "\n"
    try:
        _acp_proc.stdin.write(req)
        _acp_proc.stdin.flush()
        line = _acp_proc.stdout.readline()
        if line:
            return json.loads(line)
    except Exception:
        pass
    return None

def _talk_poll(log):
    """Polla Talk y responde via OpenCode ACP."""
    try:
        from zeroclaw.host.nctalk import poll_and_respond
        def acp_reply(prompt):
            resp = _acp_call("chat/send", {"message": prompt}, timeout=60)
            if resp and "result" in resp:
                return resp["result"].get("text", "")[:200]
            return None
        poll_and_respond(llm_fn=acp_reply, logger=log)
    except Exception as e:
        log.warning("Talk poll: %s", e)

def _write_memory(tag, message):
    os.makedirs(os.path.dirname(MEMORY_FILE), exist_ok=True)
    stamp = time.strftime("%Y-%m-%d %H:%M")
    entry = f"- [{stamp}] {tag}: {message[:200]}\n"
    try:
        with open(MEMORY_FILE, "a") as f:
            f.write(entry)
    except Exception:
        pass

def _cron_tasks(log):
    """Tareas programadas sin LLM."""
    log.info("[cron] git-status")
    try:
        r = subprocess.run("cd ~/claude && git log --oneline -1 && git status --short | head -5",
                           shell=True, capture_output=True, text=True, timeout=15)
        if r.stdout.strip():
            log.info("[cron] %s", r.stdout.strip()[:200])
    except Exception:
        pass

def run(log, once=False):
    global _shutdown, _acp_proc
    if not _start_opencode(log):
        log.error("Cannot start OpenCode ACP. Exiting.")
        return
    last_cron = 0
    while not _shutdown:
        try:
            _talk_poll(log)
            now = time.time()
            if now - last_cron > 600:  # cada 10 min
                _cron_tasks(log)
                last_cron = now
            if once:
                break
            time.sleep(30)
        except Exception as e:
            log.error("Loop error: %s", e)
            time.sleep(10)
    if _acp_proc:
        _acp_proc.terminate()
        log.info("OpenCode ACP stopped")

def main():
    global _shutdown
    signal.signal(signal.SIGINT, lambda *_: setattr(sys.modules[__name__], '_shutdown', True))
    signal.signal(signal.SIGTERM, lambda *_: setattr(sys.modules[__name__], '_shutdown', True))
    log = _log()
    log.info("SaviaClaw ACP starting")
    run(log, once="--once" in sys.argv)

if __name__ == "__main__":
    main()
