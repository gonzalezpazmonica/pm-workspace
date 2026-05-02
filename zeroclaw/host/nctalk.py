"""Nextcloud Talk integration for SaviaClaw — send messages autonomously.
Reads credentials from ~/.savia/nextcloud-config (never in repo).
"""
import os
import urllib.request
import urllib.parse
import json
import base64

CONFIG_FILE = os.path.expanduser("~/.savia/nextcloud-config")


def _load_config():
    """Load NC config from local file."""
    if not os.path.isfile(CONFIG_FILE):
        return None
    cfg = {}
    with open(CONFIG_FILE) as f:
        for line in f:
            line = line.strip()
            if "=" in line and not line.startswith("#"):
                k, v = line.split("=", 1)
                cfg[k.strip()] = v.strip()
    return cfg


def send_message(text, room_token=None):
    """Send a message to Nextcloud Talk. Splits long messages into chunks."""
    cfg = _load_config()
    if not cfg: return False
    url = cfg.get("NC_URL", "http://localhost")
    user = cfg.get("NC_USER", "savia")
    passwd = cfg.get("NC_PASS", "")
    token = room_token or cfg.get("NC_TALK_TOKEN_MONICA", "")
    if not token or not passwd: return False
    # Split into chunks of 4000 chars (Talk safe limit)
    chunks = [text[i:i+4000] for i in range(0, len(text), 4000)] if text else [""]
    ok = True
    for chunk in chunks:
        ok = ok and _send_chunk(chunk, url, user, passwd, token)
    return ok

def _send_chunk(text, url, user, passwd, token):
    endpoint = f"{url}/ocs/v2.php/apps/spreed/api/v1/chat/{token}?format=json"
    data = urllib.parse.urlencode({"message": text}).encode()
    auth = base64.b64encode(f"{user}:{passwd}".encode()).decode()

    req = urllib.request.Request(endpoint, data=data, method="POST",
        headers={"OCS-APIRequest": "true", "Authorization": f"Basic {auth}"})
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            body = json.loads(resp.read())
            return body.get("ocs", {}).get("meta", {}).get("status") == "ok"
    except Exception:
        return False


def read_messages(room_token=None, limit=5):
    """Read recent messages from a Talk room."""
    cfg = _load_config()
    if not cfg: return []
    url, user, passwd = cfg.get("NC_URL","http://localhost"), cfg.get("NC_USER","savia"), cfg.get("NC_PASS","")
    token = room_token or cfg.get("NC_TALK_TOKEN_MONICA", "")
    if not token or not passwd: return []
    endpoint = f"{url}/ocs/v2.php/apps/spreed/api/v1/chat/{token}?format=json&limit={limit}&lookIntoFuture=0"
    auth = base64.b64encode(f"{user}:{passwd}".encode()).decode()
    req = urllib.request.Request(endpoint, headers={"OCS-APIRequest": "true", "Authorization": f"Basic {auth}"})
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            return [{"actor": m.get("actorDisplayName",""), "message": m.get("message",""),
                     "ts": m.get("timestamp",0), "id": m.get("id",0)}
                    for m in json.loads(resp.read()).get("ocs",{}).get("data",[])]
    except Exception: return []

def wait_for_message(room_token=None, timeout=30, last_id=0):
    """Long poll: block until new message arrives (like official Talk client).
    Returns new messages or [] after timeout. Server holds connection open."""
    cfg = _load_config()
    if not cfg: return [], last_id
    url, user, passwd = cfg.get("NC_URL","http://localhost"), cfg.get("NC_USER","savia"), cfg.get("NC_PASS","")
    token = room_token or cfg.get("NC_TALK_TOKEN_MONICA","")
    if not token or not passwd: return [], last_id
    endpoint = (f"{url}/ocs/v2.php/apps/spreed/api/v1/chat/{token}?format=json"
                f"&limit=5&lookIntoFuture=1&timeout={timeout}&lastKnownMessageId={last_id}")
    auth = base64.b64encode(f"{user}:{passwd}".encode()).decode()
    req = urllib.request.Request(endpoint, headers={"OCS-APIRequest": "true", "Authorization": f"Basic {auth}"})
    try:
        with urllib.request.urlopen(req, timeout=timeout+5) as resp:
            msgs = json.loads(resp.read()).get("ocs",{}).get("data",[])
            parsed = [{"actor": m.get("actorDisplayName",""), "message": m.get("message",""),
                       "ts": m.get("timestamp",0), "id": m.get("id",0)} for m in msgs]
            new_last = max((m["id"] for m in parsed), default=last_id)
            return parsed, new_last
    except Exception: return [], last_id


_last_msg_id = 0

def poll_and_respond(llm_fn=None, logger=None):
    """Long poll Talk (30s timeout, like official client). Respond via LLM."""
    global _last_msg_id
    if _last_msg_id == 0:
        msgs = read_messages(limit=10)
        if msgs:
            _last_msg_id = max(m.get("id", 0) for m in msgs)
            if logger: logger.info("Talk: starting from msg id %d", _last_msg_id)
    msgs, _last_msg_id = wait_for_message(timeout=30, last_id=_last_msg_id)
    for m in msgs:
        if m["actor"].lower() == "savia": continue
        if m.get("message","").startswith("{"): continue
        q = m["message"].strip()
        if not q or len(q) < 3: continue
        if logger: logger.info("Talk from %s: %s", m["actor"], q[:60])
        prompt = (
            'Eres Savia, la asistente de pm-workspace. Responde en español, '
            'de forma natural y útil, en pocas líneas. '
            f'Pregunta: {q}'
        )
        if llm_fn:
            ans = llm_fn(prompt)
        else:
            from .llm_backend import talk_reply
            ans = talk_reply(prompt)
        if not ans:
            ans = "Ahora mismo no puedo responder, pero lo intentaré pronto. ¿Me lo repites más tarde?"
        send_message(ans)
        if logger: logger.info("Talk reply: %s", ans[:60])

_escalations = {}  # {id: (text, timestamp)}

def notify_with_escalation(text, logger=None):
    """Send Talk + arm email escalation if no response in configured timeout."""
    import time
    ok = send_message(text)
    if ok: _escalations[len(_escalations)] = (text, time.time())
    if logger: logger.info("Notify via Talk (escalation armed)")
    return ok

def check_escalations(logger=None):
    """Email if Talk not answered in time. Reads timeout + email from config."""
    import time
    cfg = _load_config()
    if not cfg: return
    timeout = int(cfg.get("ESCALATION_TIMEOUT_MIN", 60)) * 60
    email = cfg.get("ESCALATION_EMAIL", "")
    if not email: return
    resolved = []
    for mid, (text, ts) in _escalations.items():
        if time.time() - ts < timeout: continue
        if logger: logger.info("Escalating to email (no Talk response)")
        subj = "SaviaClaw: mensaje sin respuesta en Talk"
        body = f"Envie esto por Talk hace {timeout//60}min sin respuesta:\n\n{text[:400]}"
        try:
            from .llm_backend import execute
            execute(f"Send email to {email} subject '{subj}' body: {body}")
        except Exception as e:
            if logger: logger.error("Email escalation failed: %s", e)
        resolved.append(mid)
    for mid in resolved: _escalations.pop(mid, None)

if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1:
        print(f"Sent: {send_message(' '.join(sys.argv[1:]))}")
    else:
        for m in read_messages(): print(f"[{m['actor']}] {m['message']}")
