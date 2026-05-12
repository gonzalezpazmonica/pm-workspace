"""Counter skill — used by loop tests. Increments state.count."""
def run(args: dict, state: dict) -> dict:
    current = state.get("count", 0)
    new = current + int(args.get("step", 1))
    return {"count": new, "_state_patch": {"count": new}}
