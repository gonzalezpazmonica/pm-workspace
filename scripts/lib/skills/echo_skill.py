"""Echo skill — used by tests. Returns args verbatim, no state mutation."""
def run(args: dict, state: dict) -> dict:
    return {"echoed": args, "state_seen": dict(state)}
