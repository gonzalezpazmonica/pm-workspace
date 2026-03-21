#!/usr/bin/env python3
"""CLI for Savia Web Research — cache management and query tools.

Usage:
  python3 -m scripts.web-research cache-stats
  python3 -m scripts.web-research cache-clear
  python3 -m scripts.web-research sanitize "query here"
  python3 -m scripts.web-research classify "query here"
  python3 -m scripts.web-research cache-get "query here"
"""
import sys, json, argparse
from . import cache, sanitizer, formatter


def cmd_cache_stats(args):
    s = cache.stats()
    print(formatter.format_cache_stats(s))
    return 0


def cmd_cache_clear(args):
    cache.clear()
    print("Cache cleared.")
    return 0


def cmd_sanitize(args):
    clean, warnings = sanitizer.sanitize(args.query)
    if warnings:
        for w in warnings:
            print(f"  ⚠️  {w}", file=sys.stderr)
    print(clean if clean else "(empty — search aborted)")
    return 0 if clean else 1


def cmd_classify(args):
    cat = sanitizer.classify_category(args.query)
    print(cat)
    return 0


def cmd_cache_get(args):
    cat = sanitizer.classify_category(args.query)
    result = cache.get(args.query, category=cat, ignore_ttl=args.ignore_ttl)
    if result:
        print(json.dumps(result, indent=2, default=str))
    else:
        print("Cache miss.", file=sys.stderr)
        return 1
    return 0


def main():
    parser = argparse.ArgumentParser(description="Savia Web Research CLI")
    sub = parser.add_subparsers(dest="command")

    sub.add_parser("cache-stats", help="Show cache statistics")
    sub.add_parser("cache-clear", help="Clear cache")

    p_san = sub.add_parser("sanitize", help="Sanitize a query")
    p_san.add_argument("query")

    p_cls = sub.add_parser("classify", help="Classify query category")
    p_cls.add_argument("query")

    p_get = sub.add_parser("cache-get", help="Get cached result")
    p_get.add_argument("query")
    p_get.add_argument("--ignore-ttl", action="store_true")

    args = parser.parse_args()
    if not args.command:
        parser.print_help()
        return 2

    cmds = {
        "cache-stats": cmd_cache_stats,
        "cache-clear": cmd_cache_clear,
        "sanitize": cmd_sanitize,
        "classify": cmd_classify,
        "cache-get": cmd_cache_get,
    }
    return cmds[args.command](args)


if __name__ == "__main__":
    sys.exit(main())
