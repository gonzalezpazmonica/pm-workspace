"""Skills library — runner-invoked Python modules.

Each module exports `run(args: dict, state: dict) -> dict`.
The returned dict is the node's outputs. To mutate flow: state, include
a key `_state_patch` with the patch dict.
"""
