"""Stage 5: fetch related work items referenced by source items."""
from __future__ import annotations

import json
import sys
import importlib.util
from pathlib import Path

_root = Path(__file__).parent
_spec_dc = importlib.util.spec_from_file_location("_devops_client", _root / "_devops_client.py")
_dc = importlib.util.module_from_spec(_spec_dc)
_spec_dc.loader.exec_module(_dc)
_spec_rel = importlib.util.spec_from_file_location("_relations", _root / "_relations.py")
_rel = importlib.util.module_from_spec(_spec_rel)
_spec_rel.loader.exec_module(_rel)


def fetch_relations(org, parents, token, *, batch_size=200, http_timeout=60):
    """Fetch and normalize all relations referenced by parents."""
    all_ids = set()
    for p in parents:
        all_ids.update(_rel.extract_ids(p.get("relations", [])))
    if not all_ids:
        return []
    raw = _dc.fetch_in_chunks(org, sorted(all_ids), token, batch_size=batch_size, timeout=http_timeout)
    return [_dc.normalize_workitem(r) for r in raw]


def main(argv):
    if len(argv) < 3:
        print("Usage: 05_fetch_relations.py <org> <token_file> <parents_json>", file=sys.stderr)
        return 2
    org, token_file, p_json = argv[0], argv[1], argv[2]
    token = _dc.load_pat(token_file)
    parents = json.loads(Path(p_json).read_text(encoding="utf-8")).get("incidents", [])
    related = fetch_relations(org, parents, token)
    print(json.dumps({"related": related}, indent=2, ensure_ascii=False, default=str))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
