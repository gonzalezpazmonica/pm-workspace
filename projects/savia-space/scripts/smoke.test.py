"""End-to-end smoke test against a running savia-space (Python stdlib only).

Usage: SAVIA_SPACE_HOME=<state dir> python3 scripts/smoke.test.py <profile> <preset> "<query>" ["<query2>"]
The binary is taken from target/release next to this script.
"""
import hashlib
import json
import os
import subprocess
import sys
import time
import urllib.request

BASE = "http://127.0.0.1:8737"
BIN = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "target", "release", "savia-space")
cookie = None


def call(method, path, body=None):
    global cookie
    headers = {"Host": "127.0.0.1:8737"}
    if method != "GET":
        headers.update({"Origin": BASE, "X-Space-Request": "1", "Content-Type": "application/json"})
    if cookie:
        headers["Cookie"] = cookie
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(BASE + path, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=300) as r:
            set_cookie = r.headers.get("Set-Cookie")
            if set_cookie:
                cookie = set_cookie.split(";")[0]
            raw = r.read()
            ctype = r.headers.get("Content-Type", "")
            return r.status, (json.loads(raw) if "json" in ctype and raw else raw.decode())
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read() or b"null")


profile, preset = sys.argv[1], sys.argv[2]
queries = sys.argv[3:]
code = subprocess.run([BIN, "pair"], capture_output=True, text=True).stdout.strip().splitlines()[-1]
print("pair:", call("POST", "/api/v1/auth/session", {"pairingCode": code})[0])
_, projects = call("GET", "/api/v1/projects")
pid = projects["items"][0]["id"]
_, cat = call("GET", f"/api/v1/projects/{pid}/catalog")
_, s = call("POST", f"/api/v1/projects/{pid}/sessions", {"title": "Smoke", "idempotencyKey": f"s{time.time_ns()}"})
sid = s["session"]["id"]
capture_ids = []
for q in queries:
    _, res = call("POST", f"/api/v1/projects/{pid}/sources/search", {"queries": [q]})
    cand = res["candidates"][0]
    _, cap = call("POST", f"/api/v1/projects/{pid}/sources/capture", {"candidateId": cand["id"]})
    print("captured:", cap["ref"]["resourceId"], cap["coverage"])
    capture_ids.append(cap["captureId"])
_, sel = call("PUT", f"/api/v1/sessions/{sid}/selection",
              {"captureIds": capture_ids, "expectedRevision": 0, "idempotencyKey": "sel"})
pv = next(p for p in cat["presets"] if p["id"] == preset)
req = {"presetId": preset, "presetVersion": pv["version"], "prompt": "Hazlo con las fuentes seleccionadas.",
       "selectionId": sel["id"], "selectionRevision": sel["revision"], "agentRef": cat["agents"][0]["ref"],
       "skillRefs": [], "historyMessageIds": [], "providerProfileId": profile,
       "expectedSessionRevision": 1, "idempotencyKey": "turn1"}
st, prev = call("POST", f"/api/v1/sessions/{sid}/prepare", req)
print("prepare:", st, prev.get("code") if st != 201 else prev["manifest"]["tokenCount"])
assert hashlib.sha256(prev["bodyText"].encode()).hexdigest() == prev["payloadHash"], "client-side hash check"
creation = dict(req, approvedPreviewId=prev["id"], approvedManifestHash=prev["manifestHash"],
                approvedPayloadHash=prev["payloadHash"])
st, run = call("POST", f"/api/v1/sessions/{sid}/runs", creation)
print("run:", st, run)
t0 = time.time()
while True:
    _, snap = call("GET", f"/api/v1/sessions/{sid}/snapshot")
    r = snap["runs"][0]
    if r["state"] in ("COMPLETED", "FAILED", "CANCELLED", "INTERRUPTED"):
        break
    time.sleep(0.5)
print("final:", r["state"], r["terminalReason"], f"{time.time() - t0:.1f}s")
a = [m for m in snap["messages"] if m["role"] == "assistant"][0]
print("status:", a["status"])
print("text:", a["text"][:600])
for c in a["citations"]:
    print("cite:", c["sourceIndex"], c["verified"], c["match"], repr(c["quote"][:80]))
if r["state"] == "COMPLETED":
    st, md = call("GET", f"/api/v1/runs/{run['runId']}/export?format=markdown")
    print("export:", st, md.splitlines()[0])
