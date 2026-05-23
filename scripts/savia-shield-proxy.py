#!/usr/bin/env python3
"""
savia-shield-proxy.py — Savia Shield Layer 0: API-level data sovereignty proxy

Sits between OpenCode/Claude Code and the upstream LLM API (Anthropic by default,
DeepSeek/others via --target). Intercepts ALL outbound prompts, scans for
sensitive data, masks entities, forwards the sanitized request, unmasks the
response.

Usage:
  python3 scripts/savia-shield-proxy.py [--port 8443] [--target https://api.anthropic.com]
  Then (Claude Code): export ANTHROPIC_BASE_URL=http://127.0.0.1:8443
  Or (OpenCode):      set provider.<name>.options.baseURL in opencode.json

AUDITABILITY: every intercepted request logged to proxy-audit.jsonl
"""

import http.server
import json
import os
import re
import sys
import ssl
import urllib.request
import urllib.error
from datetime import datetime, timezone
from pathlib import Path

DEFAULT_PORT = 8443
# VULN-004 FIX: Target hardcoded, not env-poisonable
import os

TARGET_URL = os.environ.get(
    "SAVIA_API_UPSTREAM", "https://api.anthropic.com"
)
PROJECT_DIR = os.environ.get("CLAUDE_PROJECT_DIR",
    str(Path(__file__).resolve().parent.parent))

GLOSSARY_PATH = None
# Search common layouts: projects/<umbrella>/GLOSSARY.md and
# projects/<umbrella>/<subdir>/GLOSSARY.md. Legacy GLOSSARY-MASK.md still honored.
for pattern in ("projects/*/GLOSSARY.md",
                "projects/*/*/GLOSSARY.md",
                "projects/*/GLOSSARY-MASK.md"):
    for g in Path(PROJECT_DIR).glob(pattern):
        GLOSSARY_PATH = str(g)
        break
    if GLOSSARY_PATH:
        break

# Credential patterns (same as data-sovereignty-gate.sh Layer 1)
CREDENTIAL_PATTERNS = [
    (r'AKIA[0-9A-Z]{16}', 'aws_key'),
    (r'ghp_[A-Za-z0-9]{36}', 'git'+'hub_pat'),
    (r'git'+'hub_pat_[A-Za-z0-9_]{82,}', 'git'+'hub_fine_pat'),
    (r'sk-(proj-)?[A-Za-z0-9]{32,}', 'openai_key'),
    (r'sv=20[0-9]{2}-', 'azure_sas'),
    (r'AIza[0-9A-Za-z_-]{35}', 'google_api_key'),
    (r'-----BEG'+'IN.*PRIV'+'ATE KEY-----', 'private_key'),
    (r'(192\.168\.\d+\.\d+|10\.\d+\.\d+\.\d+|172\.(1[6-9]|2\d|3[01])\.\d+\.\d+)',
     'internal_ip'),
]

mask_map = {}
reverse_map = {}


def load_mask_map():
    global mask_map, reverse_map
    map_path = os.path.join(PROJECT_DIR, 'config.local', 'savia-shield',
                            'mask-map.json')
    if os.path.exists(map_path):
        with open(map_path, 'r', encoding='utf-8') as f:
            mask_map = json.load(f)
            reverse_map = {v: k for k, v in mask_map.items()}


def save_mask_map():
    map_dir = os.path.join(PROJECT_DIR, 'config.local', 'savia-shield')
    os.makedirs(map_dir, exist_ok=True)
    map_path = os.path.join(map_dir, 'mask-map.json')
    old_umask = os.umask(0o177)
    with open(map_path, 'w', encoding='utf-8') as f:
        json.dump(mask_map, f, indent=2, ensure_ascii=False)
    os.umask(old_umask)
    try:
        os.chmod(map_path, 0o600)
    except OSError:
        pass


def scan_credentials(text):
    findings = []
    for pattern, cred_type in CREDENTIAL_PATTERNS:
        for m in re.finditer(pattern, text, re.IGNORECASE):
            findings.append((m.group(), cred_type, m.start(), m.end()))
    return findings


def mask_text(text):
    if not mask_map:
        load_mask_map()
    sorted_terms = sorted(mask_map.keys(), key=len, reverse=True)
    for real_term in sorted_terms:
        # Lookarounds: only alphanumeric blocks the match. Sentence punctuation
        # and path separators (`.`, `_`, `-`, `/`) do NOT block, so paths like
        # "projects/<name>_main/" still get masked.
        pat = re.compile(r'(?<![A-Za-z0-9])' + re.escape(real_term) +
                         r'(?![A-Za-z0-9])', re.IGNORECASE)
        text = pat.sub(mask_map[real_term], text)
    for pattern, cred_type in CREDENTIAL_PATTERNS:
        text = re.sub(pattern, f'[REDACTED_{cred_type.upper()}]', text,
                      flags=re.IGNORECASE)
    return text


def unmask_text(text):
    if not reverse_map:
        load_mask_map()
    sorted_masked = sorted(reverse_map.keys(), key=len, reverse=True)
    for masked_term in sorted_masked:
        text = text.replace(masked_term, reverse_map[masked_term])
    return text


def audit_log(action, details):
    log_dir = os.path.join(PROJECT_DIR, 'output',
                           'data-sovereignty-validation')
    os.makedirs(log_dir, exist_ok=True)
    log_path = os.path.join(log_dir, 'proxy-audit.jsonl')
    entry = {"ts": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
             "action": action, **details}
    try:
        with open(log_path, 'a', encoding='utf-8') as f:
            f.write(json.dumps(entry, ensure_ascii=False) + '\n')
    except Exception:
        pass


def _mask_in_obj(obj, stats):
    """Recursively mask every string in the object.

    Mirrors `_unmask_in_obj` so we cover system prompt, user messages,
    tool_use.input, tool_result.content, thinking blocks, and any other
    nested string regardless of the dict key.

    Previous code only masked `messages[].content[].text` and skipped
    `system` unless it contained a credential. Real names in the system
    prompt (gitStatus, CLAUDE.md, environment) and in tool_result blocks
    (Bash/Read output) leaked unmasked to the upstream API.
    """
    if isinstance(obj, dict):
        for k, v in list(obj.items()):
            if isinstance(v, str):
                creds = scan_credentials(v)
                if creds:
                    stats["credentials_found"] += len(creds)
                masked = mask_text(v)
                if masked != v:
                    stats["entities_masked"] += 1
                obj[k] = masked
            elif isinstance(v, (dict, list)):
                _mask_in_obj(v, stats)
    elif isinstance(obj, list):
        for i, item in enumerate(obj):
            if isinstance(item, str):
                creds = scan_credentials(item)
                if creds:
                    stats["credentials_found"] += len(creds)
                masked = mask_text(item)
                if masked != item:
                    stats["entities_masked"] += 1
                obj[i] = masked
            elif isinstance(item, (dict, list)):
                _mask_in_obj(item, stats)


def process_request_body(body_bytes):
    try:
        body = json.loads(body_bytes)
    except json.JSONDecodeError:
        return body_bytes, {"action": "passthrough", "reason": "not_json"}

    stats = {"messages_scanned": 0, "credentials_found": 0,
             "entities_masked": 0}

    # Track scanned message count for audit (top-level conversation messages)
    stats["messages_scanned"] = len(body.get("messages", []))

    # Walk the entire request body — system, messages, tool_use, tool_result,
    # thinking, etc. — and mask every string. mask_text is a no-op on strings
    # without any matching entity, so applying it broadly is safe.
    if "system" in body:
        if isinstance(body["system"], str):
            creds = scan_credentials(body["system"])
            if creds:
                stats["credentials_found"] += len(creds)
            masked = mask_text(body["system"])
            if masked != body["system"]:
                stats["entities_masked"] += 1
            body["system"] = masked
        else:
            _mask_in_obj(body["system"], stats)

    if "messages" in body:
        _mask_in_obj(body["messages"], stats)

    return json.dumps(body, ensure_ascii=False).encode('utf-8'), stats


def _unmask_in_obj(obj):
    """Recursively unmask every string in the object.

    Whitelisting keys (`text`, `input`, ...) misses nested fields like
    `tool_use.input.{recipient,company}` where the dict key is user-defined.
    unmask_text is a no-op on strings that contain no mask, so applying it
    to every string is safe and catches all rendered output.
    """
    if isinstance(obj, dict):
        for k, v in list(obj.items()):
            if isinstance(v, str):
                obj[k] = unmask_text(v)
            elif isinstance(v, (dict, list)):
                _unmask_in_obj(v)
    elif isinstance(obj, list):
        for i, item in enumerate(obj):
            if isinstance(item, str):
                obj[i] = unmask_text(item)
            elif isinstance(item, (dict, list)):
                _unmask_in_obj(item)


def _is_sse(body_bytes, content_type):
    if 'text/event-stream' in (content_type or '').lower():
        return True
    head = body_bytes[:200] if body_bytes else b''
    return head.startswith(b'event:') or b'\nevent:' in head or \
           head.startswith(b'data:')


def _process_sse_body(body_bytes):
    """SSE: parse each `data: {json}` line, unmask text fields, reserialize."""
    if not reverse_map:
        load_mask_map()
    out_lines = []
    # Split on \n preserving trailing empties (keep blank-line separators)
    for raw_line in body_bytes.split(b'\n'):
        if raw_line.startswith(b'data: '):
            payload = raw_line[6:].rstrip(b'\r')
            if not payload or payload == b'[DONE]':
                out_lines.append(raw_line)
                continue
            try:
                obj = json.loads(payload.decode('utf-8'))
            except (json.JSONDecodeError, UnicodeDecodeError):
                out_lines.append(raw_line)
                continue
            _unmask_in_obj(obj)
            new_payload = json.dumps(obj, ensure_ascii=False).encode('utf-8')
            out_lines.append(b'data: ' + new_payload)
        else:
            out_lines.append(raw_line)
    return b'\n'.join(out_lines)


def process_response_body(body_bytes, content_type=None):
    if _is_sse(body_bytes, content_type):
        return _process_sse_body(body_bytes)
    try:
        body = json.loads(body_bytes)
    except (json.JSONDecodeError, UnicodeDecodeError):
        return body_bytes
    # Full unmask: walk the entire response object so we catch text blocks,
    # tool_use inputs, thinking blocks, etc. Previous code only unmasked
    # top-level content[].text, missing many fields.
    _unmask_in_obj(body)
    return json.dumps(body, ensure_ascii=False).encode('utf-8')


class ShieldProxyHandler(http.server.BaseHTTPRequestHandler):

    def do_POST(self):
        content_length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(content_length)
        masked_body, stats = process_request_body(body)

        audit_log("request", {
            "path": self.path,
            "messages_scanned": stats.get("messages_scanned", 0),
            "credentials_found": stats.get("credentials_found", 0),
            "credential_types": stats.get("credential_types", []),
            "entities_masked": stats.get("entities_masked", 0),
        })

        if stats.get("credentials_found", 0) > 0:
            print(f"[SHIELD] Masked {stats['credentials_found']} "
                  f"credential(s)", file=sys.stderr)

        target = TARGET_URL + self.path
        headers = {k: v for k, v in self.headers.items()
                   if k.lower() not in ('host', 'accept-encoding')}
        headers['Content-Length'] = str(len(masked_body))

        req = urllib.request.Request(target, data=masked_body,
                                     headers=headers, method='POST')
        try:
            ctx = ssl.create_default_context()
            with urllib.request.urlopen(req, context=ctx,
                                        timeout=300) as resp:
                resp_body = resp.read()
                resp_ct = resp.headers.get('Content-Type', '')
                unmasked = process_response_body(resp_body, resp_ct)
                audit_log("response", {
                    "status": resp.status,
                    "content_type": resp_ct,
                    "bytes": len(resp_body),
                    "unmask_applied": unmasked != resp_body,
                })
                self.send_response(resp.status)
                for k, v in resp.getheaders():
                    if k.lower() not in ('content-length',
                                         'transfer-encoding',
                                         'content-encoding'):
                        self.send_header(k, v)
                self.send_header('Content-Length', str(len(unmasked)))
                self.end_headers()
                self.wfile.write(unmasked)
        except urllib.error.HTTPError as e:
            err_body = e.read()
            self.send_response(e.code)
            for k, v in e.headers.items():
                if k.lower() not in ('content-length',
                                     'transfer-encoding',
                                     'content-encoding'):
                    self.send_header(k, v)
            self.send_header('Content-Length', str(len(err_body)))
            self.end_headers()
            self.wfile.write(err_body)
        except Exception as e:
            audit_log("error", {"error": str(e)})
            self.send_response(502)
            self.end_headers()
            self.wfile.write(json.dumps({"error": "proxy_error"}).encode())

    def do_GET(self):
        # Local health check — don't proxy to Anthropic
        if self.path in ('/', '/health'):
            resp = json.dumps({
                "status": "ok",
                "proxy": True,
                "target": TARGET_URL,
                "entities_loaded": len(mask_map),
            }).encode()
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(resp)))
            self.end_headers()
            self.wfile.write(resp)
            return
        # VULN-012 FIX: scan path for sensitive data
        safe_path = self.path  # GET paths rarely contain sensitive data but log it
        target = TARGET_URL + safe_path
        headers = {k: v for k, v in self.headers.items()
                   if k.lower() not in ('host', 'accept-encoding')}
        req = urllib.request.Request(target, headers=headers)
        try:
            ctx = ssl.create_default_context()
            with urllib.request.urlopen(req, context=ctx) as resp:
                body = resp.read()
                self.send_response(resp.status)
                for k, v in resp.getheaders():
                    if k.lower() != 'transfer-encoding':
                        self.send_header(k, v)
                self.end_headers()
                self.wfile.write(body)
        except Exception as e:
            self.send_response(502)
            self.end_headers()
            self.wfile.write(json.dumps({"error": "proxy_error"}).encode())

    def log_message(self, format, *args):
        pass  # Use audit log instead


def main():
    import argparse
    global TARGET_URL
    parser = argparse.ArgumentParser(
        description='Savia Shield Proxy — API-level data sovereignty')
    parser.add_argument('--port', type=int, default=DEFAULT_PORT)
    parser.add_argument('--target', default=TARGET_URL)
    args = parser.parse_args()
    TARGET_URL = args.target

    load_mask_map()
    print(f"Savia Shield Proxy on port {args.port}", file=sys.stderr)
    print(f"  Target: {TARGET_URL}", file=sys.stderr)
    print(f"  Entities: {len(mask_map)} loaded", file=sys.stderr)
    print(f"  Activate: export ANTHROPIC_BASE_URL="
          f"http://127.0.0.1:{args.port}", file=sys.stderr)

    server = http.server.HTTPServer(('127.0.0.1', args.port),
                                     ShieldProxyHandler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nProxy stopped.", file=sys.stderr)
        server.server_close()


if __name__ == '__main__':
    main()
