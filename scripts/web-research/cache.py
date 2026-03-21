"""Local cache for web research results — offline-first, LRU eviction."""
import json, hashlib, os, time
from pathlib import Path

DEFAULT_DIR = os.path.expanduser("~/.savia/web-cache")
DEFAULT_MAX_MB = 50

# TTL by category (seconds)
TTL = {
    "docs": 7 * 86400,
    "versions": 1 * 86400,
    "cve": 12 * 3600,
    "general": 3 * 86400,
    "code": 3 * 86400,
    "academic": 7 * 86400,
}


def _key(query):
    normalized = query.strip().lower()
    return hashlib.sha256(normalized.encode()).hexdigest()[:16]


def _ensure_dir(cache_dir):
    Path(cache_dir).mkdir(parents=True, exist_ok=True)
    results_dir = Path(cache_dir) / "results"
    results_dir.mkdir(exist_ok=True)
    return cache_dir


def _index_path(cache_dir):
    return os.path.join(cache_dir, "index.json")


def _load_index(cache_dir):
    path = _index_path(cache_dir)
    if os.path.isfile(path):
        with open(path) as f:
            return json.load(f)
    return {}


def _save_index(cache_dir, index):
    with open(_index_path(cache_dir), "w") as f:
        json.dump(index, f, indent=2)


def get(query, category="general", cache_dir=DEFAULT_DIR, ignore_ttl=False):
    """Retrieve cached result. Returns None if miss or expired."""
    _ensure_dir(cache_dir)
    key = _key(query)
    index = _load_index(cache_dir)
    entry = index.get(key)
    if not entry:
        return None
    ttl = TTL.get(category, TTL["general"])
    age = time.time() - entry["timestamp"]
    if not ignore_ttl and age > ttl:
        return None
    result_path = os.path.join(cache_dir, "results", f"{key}.json")
    if not os.path.isfile(result_path):
        return None
    with open(result_path) as f:
        data = json.load(f)
    data["_cache"] = {"hit": True, "age_hours": round(age / 3600, 1)}
    return data


def put(query, results, category="general", source="web",
        cache_dir=DEFAULT_DIR):
    """Store search results in cache."""
    _ensure_dir(cache_dir)
    key = _key(query)
    index = _load_index(cache_dir)
    result_path = os.path.join(cache_dir, "results", f"{key}.json")
    data = {
        "query": query,
        "category": category,
        "source": source,
        "results": results,
        "timestamp": time.time(),
    }
    with open(result_path, "w") as f:
        json.dump(data, f, indent=2)
    index[key] = {
        "query": query,
        "category": category,
        "source": source,
        "timestamp": time.time(),
        "size": os.path.getsize(result_path),
    }
    _save_index(cache_dir, index)
    _evict_if_needed(cache_dir, DEFAULT_MAX_MB)
    return key


def _evict_if_needed(cache_dir, max_mb):
    """LRU eviction if cache exceeds max size."""
    index = _load_index(cache_dir)
    total = sum(e.get("size", 0) for e in index.values())
    if total <= max_mb * 1024 * 1024:
        return
    by_age = sorted(index.items(), key=lambda x: x[1]["timestamp"])
    while total > max_mb * 1024 * 1024 * 0.8 and by_age:
        key, entry = by_age.pop(0)
        path = os.path.join(cache_dir, "results", f"{key}.json")
        if os.path.isfile(path):
            total -= entry.get("size", 0)
            os.remove(path)
        del index[key]
    _save_index(cache_dir, index)


def stats(cache_dir=DEFAULT_DIR):
    """Return cache statistics."""
    _ensure_dir(cache_dir)
    index = _load_index(cache_dir)
    total_size = sum(e.get("size", 0) for e in index.values())
    categories = {}
    for entry in index.values():
        cat = entry.get("category", "general")
        categories[cat] = categories.get(cat, 0) + 1
    return {
        "entries": len(index),
        "size_mb": round(total_size / (1024 * 1024), 2),
        "categories": categories,
        "max_mb": DEFAULT_MAX_MB,
    }


def clear(cache_dir=DEFAULT_DIR):
    """Clear entire cache."""
    _ensure_dir(cache_dir)
    results_dir = os.path.join(cache_dir, "results")
    for f in os.listdir(results_dir):
        os.remove(os.path.join(results_dir, f))
    _save_index(cache_dir, {})
