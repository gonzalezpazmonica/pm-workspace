"""Stage 4: fetch incidents in batch with relations expanded."""
from __future__ import annotations

import json
import sys
import importlib.util
from pathlib import Path

_root = Path(__file__).parent
_spec = importlib.util.spec_from_file_location("_devops_client", _root / "_devops_client.py")
_dc = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_dc)


def fetch_incidents(org, ids, token, *, batch_size=200, timeout=60):
    """Fetch incidents with relations expanded, normalize each."""
    raw = _dc.fetch_in_chunks(org, ids, token, expand="relations", batch_size=batch_size, timeout=timeout)
    return [_dc.normalize_workitem(r) for r in raw]


def main(argv):
    if len(argv) < 3:
        print("Usage: 04_fetch_incidents.py <org> <token_file> <ids_json>", file=sys.stderr)
        return 2
    org, token_file, ids_json = argv[0], argv[1], argv[2]
    token = _dc.load_pat(token_file)
    ids = json.loads(Path(ids_json).read_text(encoding="utf-8")).get("ids", [])
    incidents = fetch_incidents(org, ids, token)
    print(json.dumps({"incidents": incidents}, indent=2, ensure_ascii=False, default=str))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
