#!/usr/bin/env python3
"""learning-hybrid.py — SCL-005: fusión BM25 + embeddings para el recall.

Dado un query y una lista de documentos (texto + path), computa:
  - score léxico (términos en común normalizados, 0-1)
  - score semántico (similitud coseno del embedding, 0-1)
  - score híbrido = w_lex * lex + w_sem * sem

Degradación elegante: si sentence_transformers no está disponible, usa solo
el score léxico (equivalente al recall BM25 puro — comportamiento SCL-003).

Uso (stdin: JSON {"query": "...", "docs": [{"path": "...", "text": "..."}],
                   "w_lex": 0.4, "w_sem": 0.6}):
  echo '{"query":"...","docs":[...]}' | python3 learning-hybrid.py
Salida: JSON {"hits": [{"path","score","snippet"}]} ordenado desc.

Ref: docs/specs/SCL-005-embeddings-hibridos.spec.md
"""
import json
import math
import os
import re
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
PY = os.environ.get("SCL_VENV_PYTHON", os.path.join(os.path.expanduser("~"), ".savia", "venv", "bin", "python"))

def _clean_text(text):
    """Extrae el contenido útil de una nota: quita frontmatter (--- ... ---)
    y secciones repetidas, quedándose con diagnóstico/cambio/origen."""
    if not text:
        return ""
    # Quitar frontmatter
    if text.lstrip().startswith("---"):
        parts = text.lstrip().split("\n---", 1)
        if len(parts) > 1:
            text = parts[1]
    # Quitar líneas de frontmatter residuales
    text = re.sub(r"^[a-z_]+:.*$", "", text, flags=re.M)
    # Quitar plantillas/wiki/headers repetidos
    text = re.sub(r"\[\[[^\]]*\]\]", " ", text)
    text = re.sub(r"^(Ver también|# ).*$", "", text, flags=re.M)
    text = re.sub(r"\s+", " ", text).strip()
    return text

def _tokens(text):
    words = re.findall(r"[a-z0-9]{4,}", (text or "").lower())
    stop = {"para", "como", "con", "los", "las", "que", "esta", "este", "esto",
            "una", "uno", "del", "por", "cada", "muy", "solo", "mas", "menos",
            "sobre", "entre", "tiene", "debe", "para", "pero", "puede", "hacer"}
    return [w for w in words if w not in stop]

def lexical(query, doc):
    q = set(_tokens(query))
    d = set(_tokens(doc))
    if not q or not d:
        return 0.0
    return len(q & d) / len(q)  # qué fracción del query aparece en el doc

def cosine(a, b):
    if not a or not b:
        return 0.0
    dot = sum(x * y for x, y in zip(a, b))
    na = math.sqrt(sum(x * x for x in a))
    nb = math.sqrt(sum(x * x for x in b))
    if na == 0 or nb == 0:
        return 0.0
    return dot / (na * nb)

def semantic(query, docs_text):
    """Devuelve lista de similitudes coseno del query contra cada doc (o None)."""
    try:
        import importlib.util
        spec = importlib.util.spec_from_file_location("emb", os.path.join(ROOT, "embedding-server.py"))
        # embedding-server.py arranca un servidor; no lo importamos aquí.
        # Llamamos al modelo directamente via venv en modo subproceso si es necesario.
        # Implementación directa con sentence_transformers:
        import subprocess
        payload = json.dumps({"query": query, "docs": docs_text})
        code = (
            "import json,sys,os;"
            "from sentence_transformers import SentenceTransformer;"
            "m=SentenceTransformer(os.environ.get('SAVIA_EMBED_MODEL','all-MiniLM-L6-v2'));"
            "d=json.load(sys.stdin);"
            "q=m.encode([d['query']])[0];"
            "es=m.encode(d['docs']);"
            "import math;"
            "sims=[float(sum(a*b for a,b in zip(q,e))/max((sum(x*x for x in q)**0.5)*(sum(y*y for y in e)**0.5),1e-9)) for e in es];"
            "print(json.dumps(sims))"
        )
        r = subprocess.run([PY, "-c", code], input=payload, capture_output=True, text=True, timeout=30)
        if r.returncode != 0:
            return None
        return json.loads(r.stdout)
    except Exception:
        return None

def main():
    data = json.load(sys.stdin)
    query = _clean_text(data.get("query", ""))
    docs = data.get("docs", [])
    w_lex = float(data.get("w_lex", 0.4))
    w_sem = float(data.get("w_sem", 0.6))

    docs_clean = [_clean_text(d.get("text", "")) for d in docs]
    sem = semantic(query, docs_clean)

    hits = []
    for i, d in enumerate(docs):
        doc_text = docs_clean[i]
        lex = lexical(query, doc_text)
        sem_score = sem[i] if sem else 0.0
        hybrid = w_lex * lex + w_sem * sem_score
        snippet = (d.get("text", "") or "")[:160].replace("\n", " ")
        hits.append({"path": d.get("path", ""), "score": round(hybrid, 4),
                     "lex": round(lex, 4), "sem": round(sem_score, 4),
                     "snippet": snippet, "hybrid": bool(sem is not None)})

    hits.sort(key=lambda h: h["score"], reverse=True)
    print(json.dumps({"hits": hits}))

if __name__ == "__main__":
    main()
