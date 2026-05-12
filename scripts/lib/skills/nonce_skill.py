"""Nonce skill — produces a fresh UUID each call. Used by Slice 4 cache tests
to distinguish a cache hit (same nonce across runs) from a fresh execution
(different nonce)."""
import uuid


def run(args: dict, state: dict) -> dict:
    return {"nonce": uuid.uuid4().hex, "label": args.get("label", "")}
