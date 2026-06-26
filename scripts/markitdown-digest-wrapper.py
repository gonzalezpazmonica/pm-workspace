#!/usr/bin/env python3
"""
markitdown-digest-wrapper.py — Orquestador SE-172

Acepta --file y --agent (pdf|word|excel|pptx|visual|meeting)
Llama digest-extract.sh via subprocess
Devuelve JSON con el markdown extraído o fallback_used=true

AC-05: convert_local por defecto
AC-06: fallback_used=true si markitdown falla
"""
import argparse
import json
import os
import subprocess
import sys
import hashlib
from pathlib import Path
from datetime import datetime, timezone

SCRIPT_DIR = Path(__file__).parent
WORKSPACE_ROOT = SCRIPT_DIR.parent
DIGEST_EXTRACT = SCRIPT_DIR / "digest-extract.sh"

SUPPORTED_AGENTS = {"pdf", "word", "excel", "pptx", "visual", "meeting"}

AGENT_MIME_MAP = {
    "pdf":     ["pdf"],
    "word":    ["docx", "doc"],
    "excel":   ["xlsx", "xls", "csv"],
    "pptx":    ["pptx", "ppt"],
    "visual":  ["png", "jpg", "jpeg", "gif", "webp", "bmp", "tiff", "tif"],
    "meeting": ["vtt", "txt", "docx"],
}


def get_markitdown_version() -> str:
    try:
        import markitdown
        return markitdown.__version__
    except ImportError:
        return "not_installed"


def resolve_workspace_path(file_path: str) -> str:
    """Resolve path — absolute or relative to WORKSPACE_ROOT."""
    p = Path(file_path)
    if p.is_absolute():
        return str(p)
    candidate = WORKSPACE_ROOT / p
    if candidate.exists():
        return str(candidate)
    return str(p)


def run_digest_extract(input_file: str, external: bool = False) -> dict:
    """
    Run digest-extract.sh and return dict with markdown content.
    AC-06: on failure, returns fallback_used=True.
    """
    markitdown_enabled = os.environ.get("MARKITDOWN_ENABLED", "true").lower()
    if markitdown_enabled == "false":
        return {
            "ok": False,
            "fallback_used": True,
            "reason": "MARKITDOWN_ENABLED=false",
            "markdown": "",
        }

    cmd = ["bash", str(DIGEST_EXTRACT), input_file]
    if external:
        cmd.append("--external")

    env = os.environ.copy()
    env["WORKSPACE_ROOT"] = str(WORKSPACE_ROOT)

    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=120,
            env=env,
        )
        if result.returncode == 0:
            return {
                "ok": True,
                "fallback_used": False,
                "markdown": result.stdout,
                "stderr": result.stderr,
            }
        else:
            return {
                "ok": False,
                "fallback_used": True,
                "reason": result.stderr.strip() or f"exit {result.returncode}",
                "markdown": "",
                "stderr": result.stderr,
            }
    except subprocess.TimeoutExpired:
        return {
            "ok": False,
            "fallback_used": True,
            "reason": "timeout (120s)",
            "markdown": "",
        }
    except Exception as e:
        return {
            "ok": False,
            "fallback_used": True,
            "reason": str(e),
            "markdown": "",
        }


def build_output(agent: str, file_path: str, extract_result: dict) -> dict:
    """Build the JSON output for the agent."""
    timestamp = datetime.now(timezone.utc).isoformat()
    markitdown_version = get_markitdown_version()

    output = {
        "agent": agent,
        "source_file": file_path,
        "timestamp": timestamp,
        "markitdown_version": markitdown_version,
        "fallback_used": extract_result.get("fallback_used", True),
        "ok": extract_result.get("ok", False),
    }

    if extract_result.get("ok"):
        output["markdown"] = extract_result["markdown"]
        output["markdown_length"] = len(extract_result["markdown"])
    else:
        output["reason"] = extract_result.get("reason", "unknown")
        output["markdown"] = ""

    return output


def main():
    parser = argparse.ArgumentParser(
        description="markitdown-digest-wrapper — SE-172 universal extraction layer"
    )
    parser.add_argument("--file", required=True, help="Input file path")
    parser.add_argument(
        "--agent",
        required=True,
        choices=sorted(SUPPORTED_AGENTS),
        help="Digest agent type",
    )
    parser.add_argument(
        "--external",
        action="store_true",
        help="Allow paths outside workspace (AC-07)",
    )
    parser.add_argument(
        "--output",
        help="Output JSON file (default: stdout)",
    )

    args = parser.parse_args()

    # Validate input
    if not args.file or not args.file.strip():
        err = {
            "ok": False,
            "fallback_used": True,
            "reason": "empty input file path",
            "markitdown_version": get_markitdown_version(),
        }
        print(json.dumps(err, ensure_ascii=False, indent=2))
        sys.exit(1)

    resolved_path = resolve_workspace_path(args.file)

    # Run extraction
    extract_result = run_digest_extract(resolved_path, external=args.external)
    output = build_output(args.agent, resolved_path, extract_result)

    output_json = json.dumps(output, ensure_ascii=False, indent=2)

    if args.output:
        out_path = Path(args.output)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(output_json, encoding="utf-8")
        print(f"OK: Written to {args.output}", file=sys.stderr)
    else:
        print(output_json)

    sys.exit(0 if output["ok"] else 1)


if __name__ == "__main__":
    main()
