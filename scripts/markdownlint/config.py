"""Configuration loading and rule enablement logic."""
import json, os, re

DEFAULT_CONFIG = {
    "default": True,
    "MD013": False,
    "MD033": False,
    "MD041": False,
    "MD024": {"siblings_only": True},
}


def load_config(path):
    if path and os.path.isfile(path):
        with open(path) as f:
            return json.load(f)
    return DEFAULT_CONFIG


def is_enabled(cfg, rule):
    val = cfg.get(rule)
    if val is False:
        return False
    if cfg.get("default") is False and val is None:
        return False
    return True


def in_fenced_block(lines, line_idx):
    """Check if line_idx is inside a fenced code block."""
    fence_count = 0
    for i in range(line_idx):
        if re.match(r'^(`{3,}|~{3,})', lines[i]):
            fence_count += 1
    return fence_count % 2 == 1
