"""set_key skill — writes args.value to args.key in flow state.

Used by parallel-wave tests to verify each node's patch lands in distinct keys.
"""
def run(args: dict, state: dict) -> dict:
    k = args["key"]
    v = args["value"]
    return {"k": k, "v": v, "_state_patch": {k: v}}
