"""Historial de evaluaciones (SE-346): memoria + volcado CSV local.

CRIT-001: los CSV van a output/ (disco propio, gitignored).
"""

import csv
import os


class History:
    def __init__(self, items=None):
        self._items = []
        for feats, outcome in (items or []):
            self.add(feats, outcome)

    def add(self, features, outcome):
        self._items.append((list(features), float(outcome)))
        return self

    def __len__(self):
        return len(self._items)

    def __iter__(self):
        return iter(self._items)

    @property
    def items(self):
        return list(self._items)

    def to_csv(self, path):
        if not self._items:
            return
        os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
        dim = len(self._items[0][0])
        with open(path, "w", newline="") as f:
            w = csv.writer(f)
            w.writerow([f"f{i}" for i in range(dim)] + ["outcome"])
            for feats, out in self._items:
                w.writerow(list(feats) + [out])

    @classmethod
    def from_csv(cls, path):
        if not os.path.exists(path):
            return cls()
        items = []
        with open(path) as f:
            for row in csv.DictReader(f):
                feats = [float(v) for k, v in row.items() if k.startswith("f")]
                items.append((feats, float(row["outcome"])))
        return cls(items)
