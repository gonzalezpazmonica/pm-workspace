#!/usr/bin/env python3
"""
savia-shield-daemon.py — Unified Savia Shield daemon
/scan /mask /unmask /health on localhost.
Fallback: if down, hooks exit 0. Claude Code always works.
"""
import http.server, json, os, re, sys, time, base64
from datetime import datetime, timezone
from pathlib import Path

PORT = int(os.environ.get("SAVIA_SHIELD_PORT", "8444"))
PROJ = os.environ.get("CLAUDE_PROJECT_DIR", str(Path(__file__).resolve().parent.parent))
CRED = [
    (r'AKIA[0-9A-Z]{16}', 'aws_key'),
    (r'ghp_[A-Za-z0-9]{36}', 'git'+'hub_pat'),
    (r'git'+'hub_pat_[A-Za-z0-9_]{82,}', 'git'+'hub_fine_pat'),
    (r'sk-(proj-)?[A-Za-z0-9]{32,}', 'openai_key'),
    (r'sv=20[0-9]{2}-', 'azure_sas'),
    (r'AIza[0-9A-Za-z_-]{35}', 'google_api_key'),
    (r'-----BEG'+'IN.*PRIV'+'ATE KEY-----', 'private_key'),
    (r'(jdbc:|mongodb\+srv://|Ser'+'ver=.*Pass'+'word=)', 'connection_string'),
    (r'(192\.168\.\d+\.\d+|10\.\d+\.\d+\.\d+|172\.(1[6-9]|2\d|3[01])\.\d+\.\d+)', 'internal_ip'),
]
ner = None; mmap = {}; rmap = {}

def init():
    global ner, mmap, rmap
    t0 = time.time()
    for p in [f'{PROJ}/config.local/savia-shield/mask-map.json',
              f'{PROJ}/output/data-sovereignty-validation/mask-map.json']:
        if os.path.exists(p):
            with open(p,'r') as f: mmap=json.load(f); rmap={v:k for k,v in mmap.items()}
            print(f"  Mask: {len(mmap)} entities",file=sys.stderr); break
    try:
        from presidio_analyzer import AnalyzerEngine,PatternRecognizer
        from presidio_analyzer.nlp_engine import SpacyNlpEngine
        nlp=SpacyNlpEngine(models=[{"lang_code":"es","model_name":"es_core_news_md"}])
        ner_eng=AnalyzerEngine(nlp_engine=nlp,supported_languages=["es","en"])
        for g in Path(PROJ).glob("projects/*/GLOSSARY-MASK.md"):
            cat=None; ents={}
            with open(g,'r') as f:
                for ln in f:
                    ln=ln.strip()
                    if ln.startswith('## '): cat=ln[3:].strip().lower(); ents.setdefault(cat,[])
                    elif ln.startswith('- **') and cat:
                        t=ln.split('**')[1] if '**' in ln else ''
                        if t and len(t)>1: ents[cat].append(t)
            for c,terms in ents.items():
                if terms:
                    for la in ["es","en"]:
                        ner_eng.registry.add_recognizer(PatternRecognizer(
                            supported_entity=f"CUSTOM_{c.upper()}",deny_list=terms,supported_language=la))
            print(f"  Glossary: {sum(len(v) for v in ents.values())} terms",file=sys.stderr); break
        globals()['ner']=ner_eng
        print(f"  NER: {len(ner_eng.registry.recognizers)} recognizers",file=sys.stderr)
    except Exception as e: print(f"  NER unavailable: {e}",file=sys.stderr)
    print(f"  Boot: {time.time()-t0:.1f}s",file=sys.stderr)

def scan(text,th=0.7):
    t0=time.time(); hits=[]
    for p,t2 in CRED:
        for m in re.finditer(p,text,re.I):
            hits.append({"type":t2,"text":m.group(),"score":1.0,"action":"BLOCK","layer":1})
    for blob in re.findall(r'[A-Za-z0-9+/]{40,200}={0,2}',text)[:20]:
        try:
            dec=base64.b64decode(blob).decode('utf-8',errors='ignore')
            for p,t2 in CRED:
                if re.search(p,dec,re.I):
                    hits.append({"type":f"b64_{t2}","text":blob[:30]+"...","score":1.0,"action":"BLOCK","layer":1})
        except: pass
    if ner and len(text)>=10:
        for la in ["es","en"]:
            try:
                for r in ner.analyze(text=text,language=la,score_threshold=0.4):
                    hits.append({"type":r.entity_type,"text":text[r.start:r.end],"score":round(r.score,2),
                        "action":"BLOCK" if r.score>=th else "WARN","layer":1.5})
            except: pass
    seen=set(); dd=[]
    for h in hits:
        k=(h["text"],h["type"])
        if k not in seen: seen.add(k); dd.append(h)
    return {"verdict":"PII_DETECTED" if any(h["action"]=="BLOCK" for h in dd) else "CLEAN",
            "entities":dd,"latency_ms":int((time.time()-t0)*1000)}

def mask(text):
    t0=time.time(); o=text
    for t in sorted(mmap.keys(),key=len,reverse=True): text=re.sub(re.escape(t),mmap[t],text,flags=re.I)
    for p,t2 in CRED: text=re.sub(p,f'[REDACTED_{t2.upper()}]',text,flags=re.I)
    return {"masked":text,"changed":text!=o,"latency_ms":int((time.time()-t0)*1000)}

def unmask(text):
    t0=time.time()
    for m in sorted(rmap.keys(),key=len,reverse=True): text=text.replace(m,rmap[m])
    return {"unmasked":text,"latency_ms":int((time.time()-t0)*1000)}

TOKEN = ""
def load_token():
    global TOKEN
    tp = os.path.expanduser("~/.savia/shield-token")
    if os.path.exists(tp):
        with open(tp) as f: TOKEN = f.read().strip()
        print(f"  Auth: token loaded", file=sys.stderr)
    else:
        TOKEN = ""
        print(f"  Auth: NO TOKEN (open access!)", file=sys.stderr)


def gate(hook_input):
    """Unified gate: parse hook JSON, classify destination, scan regex+NER."""
    t0 = time.time()
    ti = hook_input.get("tool_input", {})
    fp = ti.get("file_path", ti.get("path", ""))
    content = ti.get("content", ti.get("new_string", ""))[:20000]

    if not fp:
        return {"verdict": "ALLOW", "reason": "no_file_path", "latency_ms": 0}

    # Normalize path separators (Windows uses \, patterns use /)
    fp_norm = fp.replace("\\", "/")

    # Destination classification — private paths skip scanning
    private_patterns = ["/projects/", "projects/", ".local.", "/output/", "private-agent-memory",
                        "config.local", "/.savia/", "/.claude/sessions/", "settings.local.json"]
    for pat in private_patterns:
        if pat in fp_norm:
            return {"verdict": "ALLOW", "reason": "private_destination", "latency_ms": 0}

    # Whitelist for shield's own files
    shield_patterns = ["data-sovereignty", "ollama-classify", "shield-ner",
                       "savia-shield", "sovereignty-mask", "test-data-sovereignty"]
    for pat in shield_patterns:
        if pat in fp_norm:
            return {"verdict": "ALLOW", "reason": "shield_file", "latency_ms": 0}

    if not content or len(content) < 10:
        return {"verdict": "ALLOW", "reason": "trivial_content", "latency_ms": 0}

    # NFKC normalize
    import unicodedata
    content = unicodedata.normalize("NFKC", content)

    # Scan (regex + NER combined)
    result = scan(content)

    latency = int((time.time() - t0) * 1000)
    verdict = "BLOCK" if result["verdict"] == "PII_DETECTED" else "ALLOW"
    return {"verdict": verdict, "entities": result.get("entities", []),
            "file": fp, "latency_ms": latency}

class H(http.server.BaseHTTPRequestHandler):
    def _check_auth(self):
        
        if not TOKEN: return True
        auth = self.headers.get('X-Shield-Token', '')
        if auth != TOKEN:
            return False
        return True
    def _j(self):
        n=int(self.headers.get('Content-Length',0))
        if n > 1048576: raise ValueError('Request too large (max 1MB)')
        return json.loads(self.rfile.read(n)) if n else {}
    def _r(self,d,s=200):
        b=json.dumps(d,ensure_ascii=False).encode(); self.send_response(s)
        self.send_header('Content-Type','application/json'); self.send_header('Content-Length',str(len(b)))
        self.end_headers(); self.wfile.write(b)
    def do_POST(self):
        if not self._check_auth():
            self._r({"error":"unauthorized"},403); return
        try:
            d=self._j(); t=d.get("text","")
            if self.path=="/scan": self._r(scan(t,d.get("threshold",0.7)))
            elif self.path=="/mask": self._r(mask(t))
            elif self.path=="/unmask": self._r(unmask(t))
            elif self.path=="/gate": self._r(gate(d))
            else: self._r({"error":"not found"},404)
        except Exception as e: self._r({"error":str(e)},500)
    def do_GET(self):
        if self.path=="/health": self._r({"status":"ok","ner":ner is not None,"version":"2.0"})
        else: self._r({"error":"not found"},404)
    def log_message(self,*a): pass

if __name__=='__main__':
    import argparse; p=argparse.ArgumentParser(); p.add_argument('--port',type=int,default=PORT)
    a=p.parse_args(); print(f"Savia Shield Daemon :{a.port}",file=sys.stderr); init(); load_token()
    s=http.server.HTTPServer(('127.0.0.1',a.port),H); print(f"  Ready",file=sys.stderr)
    try: s.serve_forever()
    except KeyboardInterrupt: print("\nStopped.",file=sys.stderr)
