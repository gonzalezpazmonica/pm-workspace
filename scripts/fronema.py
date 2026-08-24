#!/usr/bin/env python3
"""fronema.py — SE-344 Frónesis como Código: casos de juicio con consecuencia verificada.

Fronema = unidad de frónesis externalizable: decisión difícil + tensión entre
principios + señales que el senior buscó (RPD) + deliberación + decisión/razón
+ CONSECUENCIA verificada + límites. Vive en una cúpula de conocimiento (notas
markdown con frontmatter YAML) y se propaga a (a) proyectos (gate de
precedentes por tensión×dominio) y (b) formación (loop predict→reveal→calibrate).

Principio rector: sin consecuencia verificada no hay fronema. El sistema
expulsa lo que deja de requerir juicio (graduación a regla).

Cero egress. CRIT-001: los casos completos N4 viven en la cúpula del proyecto;
en la cúpula de frónesis solo entra la versión destilada N1/N2 (jamás N3+).

Usage:
  fronema.py register --tension T --decision D --razon R --limites L \
             --senal "s1" [--senal ...] --pregunta "p1" [--pregunta ...] \
             --dominio datos [--dominio ...] --fuente F [--nivel N2] \
             [--verificacion T+30 --resultado "..."] [--vault DIR|--dome NAME]
  fronema.py verify --id pc-XXXX --resultado "..." [--arrepentimiento ...] \
             [--correccion ...] [--ventana T+90]
  fronema.py overrule --id pc-XXXX --resultado "..." [--correccion ...]
  fronema.py calibrate --id pc-XXXX --aciertos N --total M
  fronema.py graduate --id pc-XXXX
  fronema.py query --tension T [--dominio D] [--madurez M] [--vault DIR]
  fronema.py list [--madurez M] [--dominio D] [--vault DIR]
  fronema.py train --dominio D [--sesion S] [--vault DIR]

Exit: 0 ok · 1 no results/IO · 2 validación · 3 caso no encontrado
Env: SAVIA_FRONEMA_VAULT (dir de la cúpula de frónesis, default ~/.savia-vaults/fronesis)
"""

import argparse
import hashlib
import json
import os
import random
import re
import sys
import time
from pathlib import Path

FRONEMA_ID_RE = re.compile(r"^pc-\d{4}$")
MADUREZ = {"draft", "verified", "calibrated", "overruled", "graduated"}
LEVELS = {"N1", "N2"}
TENSIONS = {"rigor", "velocidad", "seguridad", "operatividad", "compasion",
            "justicia", "confianza", "evidencia", "autonomia", "supervision",
            "honestidad", "humanidad", "dato", "persona", "velocidad"}
DEFAULT_VAULT = Path(os.environ.get("SAVIA_FRONEMA_VAULT",
                                    Path.home() / ".savia-vaults" / "fronesis"))


def _parse_frontmatter_tail(content: str) -> list[str]:
    """Lines after the first frontmatter block (skip `---` delimiters)."""
    lines = content.splitlines()
    if not lines or lines[0].strip() != "---":
        return []
    end = 1
    for i in range(1, len(lines)):
        if lines[i].strip() == "---":
            end = i
            break
    return lines[end + 1:]


class Fronema:
    def __init__(self, vault: Path, dome: str):
        self.vault = Path(vault)
        self.dome = dome
        self.dir = self.vault
        self.dir.mkdir(parents=True, exist_ok=True)

    def _path(self, fid: str) -> Path:
        return self.dir / f"{fid}.md"

    def _find(self, fid: str) -> tuple[list[str], Path]:
        f = self._path(fid)
        if f.exists():
            return open(f, encoding="utf-8").read().splitlines(), f
        # fallback: match by frontmatter id anywhere (import war only)
        for cand in self.dir.glob("*.md"):
            head = "\n".join(_parse_frontmatter_tail(cand.read_text(encoding="utf-8")))
            if f"id: {fid}" in cand.read_text(encoding="utf-8").split("---")[1] if "---" in cand.read_text(encoding="utf-8") else False:
                return cand.read_text(encoding="utf-8").splitlines(), cand
        return [], f

    def register(self, args) -> int:
        # validación estricta (AC-2)
        required = {
            "tension": args.tension, "decision": args.decision,
            "razon": args.razon, "limites": args.limites,
        }
        for k, v in required.items():
            if not (v and str(v).strip()):
                print(f"ERROR: {k} required", file=sys.stderr)
                return 2
        if not args.senal or not args.pregunta:
            print("ERROR: --senal (>=1) y --pregunta (>=1) required", file=sys.stderr)
            return 2
        if not args.dominio:
            print("ERROR: --dominio required (dominio L23)", file=sys.stderr)
            return 2
        nivel = args.nivel or "N2"
        if nivel not in LEVELS:
            print(f"ERROR: --nivel {nivel} inválido (solo N1/N2; los casos N3+/N4 jamás aquí)", file=sys.stderr)
            return 2

        madurez = "draft"
        if args.verificacion and args.resultado:
            madurez = "verified"  # seed cases (AC-3)

        # id: siguiente pc-XXXX libre
        nxt = 1
        while self._path(f"pc-{nxt:04d}").exists():
            nxt += 1
        fid = f"pc-{nxt:04d}"

        sh = hashlib.sha256(
            f"{fid}|{args.tension}|{args.decision}|{args.fuente}".encode()).hexdigest()[:8]

        lines = [
            "---",
            f"entity: {{type: phronesis-case, id: {fid}, hash: {sh}}}",
            f"dominio: [{', '.join(args.dominio)}]",
            f"tension: \"{args.tension}\"",
            "prototipo:",
        ]
        for s in args.senal:
            lines.append(f"  - \"{s}\"")
        lines.append("deliberacion:")
        for p in args.pregunta:
            lines.append(f"  - \"{p}\"")
        lines.append(f"decision: \"{args.decision}\"")
        lines.append(f"razon: \"{args.razon}\"")
        lines.append("consecuencia:")
        v = args.verificacion or "pending"
        lines.append(f"  verificacion: {v}")
        lines.append(f"  resultado: {json.dumps(args.resultado) if args.resultado else 'null'}")
        lines.append(f"  arrepentimiento: {json.dumps(args.arrepentimiento) if args.arrepentimiento else 'null'}")
        lines.append(f"  correccion: {json.dumps(args.correccion) if args.correccion else 'null'}")
        lines.append(f"limites: \"{args.limites}\"")
        lines.append(f"madurez: {madurez}")
        lines.append(f"fuente: \"{args.fuente}\"")
        lines.append(f"nivel: {nivel}")
        lines.append("---")

        self._path(fid).write_text("\n".join(lines) + "\n", encoding="utf-8")
        print(f"registered: {fid} ({madurez}) {self._path(fid)}")
        return 0

    def _load(self, fid: str) -> tuple[dict, Path]:
        lines, path = self._find(fid)
        if not path.exists():
            return {}, path
        text = path.read_text(encoding="utf-8")
        m = re.search(r"madurez: (\w+)", text)
        v = re.search(r"consecuencia:\s*\n\s*verificacion: (\w+)", text)
        res = re.search(r"consecuencia:\s*\n\s*verificacion: [^\n]*\n\s*resultado: (.*)", text)
        return {
            "madurez": m.group(1) if m else "draft",
            "verificacion": v.group(1) if v else "pending",
            "resultado": res.group(1).strip() if res else "null",
            "contenido": text,
        }, path

    def _set_field(self, fid: str, field: str, value: str) -> int:
        text, path = self._find(fid)[0], self._find(fid)[1]
        if not path.exists():
            print(f"ERROR: caso {fid} no existe", file=sys.stderr)
            return 3
        new = re.sub(rf"(?m)^{re.escape(field)}: .*$", f"{field}: {value}", text, count=1)
        if new == text:
            print(f"ERROR: campo {field} no encontrado en {fid}", file=sys.stderr)
            return 2
        path.write_text(new, encoding="utf-8")
        return 0

    def verify(self, args) -> int:
        data, path = self._load(args.id)
        if not path.exists():
            print(f"ERROR: caso {args.id} no existe", file=sys.stderr); return 3
        if data["madurez"] == "overruled":
            print(f"ERROR: {args.id} está overruled; no se puede reverificar", file=sys.stderr); return 3
        new_res = json.dumps(args.resultado)
        lines = path.read_text(encoding="utf-8").splitlines()
        out = []
        replaced_res = False
        for ln in lines:
            if ln.startswith("  resultado:"):
                out.append(f"  resultado: {new_res}"); replaced_res = True
            elif ln.startswith("  arrepentimiento:"):
                out.append(f"  arrepentimiento: {json.dumps(args.arrepentimiento) if args.arrepentimiento else 'null'}")
            elif ln.startswith("  correccion:"):
                out.append(f"  correccion: {json.dumps(args.correccion) if args.correccion else 'null'}")
            elif ln.startswith("madurez:"):
                out.append(f"madurez: verified")
            else:
                out.append(ln)
        if not replaced_res:
            print(f"ERROR: no campo resultado en {args.id}", file=sys.stderr); return 2
        path.write_text("\n".join(out) + "\n", encoding="utf-8")
        print(f"verified: {args.id} -> madurez verified ({args.ventana or 'T+??'})")
        return 0

    def overrule(self, args) -> int:
        data, path = self._load(args.id)
        if not path.exists():
            print(f"ERROR: caso {args.id} no existe", file=sys.stderr); return 3
        lines = path.read_text(encoding="utf-8").splitlines()
        out = []
        for ln in lines:
            if ln.startswith("  resultado:"):
                out.append(f"  resultado: {json.dumps(args.resultado)}")
            elif ln.startswith("  correccion:") and args.correccion:
                out.append(f"  correccion: {json.dumps(args.correccion)}")
            elif ln.startswith("madurez:"):
                out.append("madurez: overruled")  # no se borra: la revocación es historial
            else:
                out.append(ln)
        path.write_text("\n".join(out) + "\n", encoding="utf-8")
        print(f"overruled: {args.id} (la consecuencia desmintió la lección; el caso permanece como historial)")
        return 0

    def calibrate(self, args) -> int:
        data, path = self._load(args.id)
        if not path.exists():
            print(f"ERROR: caso {args.id} no existe", file=sys.stderr); return 3
        acc, tot = int(args.aciertos), int(args.total)
        if tot <= 0 or acc > tot:
            print(f"ERROR: --aciertos {acc} inválido para --total {tot}", file=sys.stderr); return 2
        rate = acc / tot
        print(f"calibrated: {args.id} (aciertos={acc}/{tot}, rate={rate:.0%})")
        if rate >= 0.9:
            print(f"  SUGERENCIA: rate>=90% — candidato a gravación (fronema.py graduate {args.id})")
        return 0

    def graduate(self, args) -> int:
        data, path = self._load(args.id)
        if not path.exists():
            print(f"ERROR: caso {args.id} no existe", file=sys.stderr); return 3
        lines = path.read_text(encoding="utf-8").splitlines()
        out = []
        for ln in lines:
            if ln.startswith("madurez:"):
                out.append("madurez: graduated")  # migra a regla; no se borra
            elif ln.startswith("razon:"):
                out.append(ln + "  # graduado a regla (CRITERIO.md/regla de dominio)")
            else:
                out.append(ln)
        path.write_text("\n".join(out) + "\n", encoding="utf-8")
        print(f"graduated: {args.id} -> regla explícita (el caso queda como historial)")
        return 0

    def query(self, args) -> int:
        tension = (args.tension or "").lower()
        dominio = (args.dominio or "").lower()
        madurez_filter = args.madurez
        if madurez_filter and madurez_filter not in MADUREZ:
            print(f"ERROR: madurez {madurez_filter} inválida", file=sys.stderr); return 2
        order_prio = {"calibrated": 0, "verified": 1, "draft": 2, "overruled": 3, "graduated": 4}
        results = []
        for f in sorted(self.dir.glob("*.md"), reverse=False):
            txt = f.read_text(encoding="utf-8")
            ids = re.search(r"id: (pc-\d{4})", txt.split("---")[1] if "---" in txt else txt)
            if not ids:
                continue
            fid = ids.group(1)
            mad = re.search(r"madurez: (\w+)", txt)
            mad = mad.group(1) if mad else "draft"
            ten = (re.search(r"tension: \"([^\"]+)\"", txt) or [None, ""])
            ten = ten.group(1).lower() if hasattr(ten, "group") and ten.group(1) else ""
            dom = re.search(r"dominio: \[([^\]]*)\]", txt)
            dom = dom.group(1).lower() if dom else ""
            if tension and tension not in ten:
                continue
            if dominio and dominio not in dom:
                continue
            if madurez_filter and mad != madurez_filter:
                continue
            ts = re.search(r"consecuencia:\s*\n\s*verificacion: (T\+[\d]+|T\+0|pending)", txt)
            results.append((order_prio.get(mad, 9), tid := fid, mad, ten, dom, ts.group(1) if ts else "?"))
        results.sort(key=lambda r: (r[0], r[1]), reverse=False)
        if not results:
            return 1
        for prio, fid, mad, ten, dom, ver in results:
            print(f"{fid}  {mad:10s}  tensión={ten:12s}  dominio=[{dom}]  verificación={ver}")
        return 0

    def list_cases(self, args) -> int:
        return self.query(argparse.Namespace(
            tension=None, dominio=getattr(args, "dominio", None),
            madurez=getattr(args, "madurez", None)))

    def train(self, args) -> int:
        dominio = args.dominio or ""
        pool = []
        for f in sorted(self.dir.glob("*.md")):
            txt = f.read_text(encoding="utf-8")
            if "---" not in txt:
                continue
            fm = txt.split("---")[1]
            if "id: pc-" in fm and ("madurez: verified" in fm or "madurez: calibrated" in fm):
                if dominio and f"dominio: [{dominio}" not in fm:
                    continue
                pool.append((f.stem, txt))
        if not pool:
            print("train: sin casos verified/calibrated para entrenar", file=sys.stderr)
            return 1
        rng = random.Random(args.sesion or 0)  # determinista por sesión (AC-8)
        rng.shuffle(pool)
        # el caso: enmascarar decision/razon/consecuencia (AC-8)
        fid, txt = pool[0]
        tens = re.search(r"tension: \"([^\"]+)\"", txt)
        # señales RPD del bloque prototipo (lista YAML de strings)
        signs_block = re.search(r"prototipo:\n((?:\s+-\s*\"[^\"]*\"\n?)*)", txt)
        signs = re.findall(r'-\s*"([^"]+)"', signs_block.group(1) if signs_block else "")
        limites = (re.search(r"limites: \"([^\"]+)\"", txt) or [None, "—"])
        limites_m = limites.group(1) if hasattr(limites, "group") and limites.group(1) else "—"
        decision = (re.search(r"decision: \"([^\"]+)\"", txt) or [None, "…"]).group(1)
        razon = (re.search(r"razon: \"([^\"]+)\"", txt) or [None, "…"]).group(1)
        cons = re.search(r"resultado: (.*)", txt)
        cons_val = cons.group(1).strip() if cons else "…"
        print("─── CASO ENMASCARADO (predice antes de revelar) ───")
        print(f"ID oculto · tensión: {tens.group(1) if tens else '?'}")
        print(f"Señales (RPD): {json.dumps(signs, ensure_ascii=False) if signs else '—'}")
        print(f"Límites: {limites_m}")
        print("→ ¿qué harías? ¿confianza 0-100%? (responde; luego se revela)")
        # lectura de respuesta: stdin si no es tty (tests/pipe), input() si tty
        if sys.stdin.isatty():
            rev = input("... ").strip()
        else:
            rev = sys.stdin.read().strip()[:200]
        print("\n─── REVELACIÓN ───")
        print(f"Decisión del senior: {decision}")
        print(f"Razón: {razon}")
        print(f"Consecuencia verificada: {cons_val}")
        line = {"sesion": args.sesion or 0, "case": fid, "response": rev[:200]}
        (self.vault / "training.jsonl").open("a", encoding="utf-8").write(json.dumps(line) + "\n")
        print(f"registrado en {self.vault}/training.jsonl")
        return 0


def main(argv=None) -> int:
    argv = argv if argv is not None else sys.argv[1:]
    p = argparse.ArgumentParser(prog="fronema")
    p.add_argument("--vault", default=str(DEFAULT_VAULT), help="cúpula de frónesis (dir)")
    sub = p.add_subparsers(dest="cmd", required=True)
    # comando -> método de Fronema(args)
    methods = {
        "register": "register", "verify": "verify", "overrule": "overrule",
        "calibrate": "calibrate", "graduate": "graduate",
        "query": "query", "list": "list_cases", "train": "train",
    }
    for cmd, method in methods.items():
        sp = sub.add_parser(cmd)
        sp.set_defaults(fn=lambda a, m=method: getattr(Fronema(a.vault, "fronesis"), m)(a))
        if cmd == "register":
            sp.add_argument("--tension"); sp.add_argument("--decision"); sp.add_argument("--razon")
            sp.add_argument("--limites"); sp.add_argument("--senal", action="append")
            sp.add_argument("--pregunta", action="append"); sp.add_argument("--dominio", action="append")
            sp.add_argument("--fuente"); sp.add_argument("--nivel", choices=sorted(LEVELS))
            sp.add_argument("--verificacion"); sp.add_argument("--resultado")
            sp.add_argument("--arrepentimiento"); sp.add_argument("--correccion")
        elif cmd in ("verify", "overrule", "calibrate", "graduate"):
            sp.add_argument("--id", required=True)
            if cmd in ("verify", "overrule"):
                sp.add_argument("--resultado"); sp.add_argument("--arrepentimiento")
                sp.add_argument("--correccion")
            if cmd == "verify":
                sp.add_argument("--ventana")
            if cmd == "calibrate":
                sp.add_argument("--aciertos", type=int, required=True)
                sp.add_argument("--total", type=int, required=True)
        elif cmd == "query":
            sp.add_argument("--tension"); sp.add_argument("--dominio")
            sp.add_argument("--madurez", choices=sorted(MADUREZ))
        elif cmd == "list":
            sp.add_argument("--madurez", choices=sorted(MADUREZ)); sp.add_argument("--dominio")
        elif cmd == "train":
            sp.add_argument("--dominio"); sp.add_argument("--sesion", type=int, default=0)
    if "--version" in argv:
        print("fronema.py 0.1.0 (SE-344)")
        return 0
    args = p.parse_args(argv)
    return args.fn(args)


if __name__ == "__main__":
    sys.exit(main())