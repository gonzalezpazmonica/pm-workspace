"""
cli.py — Entry point: python3 -m artifacts

Uso:
  python3 -m artifacts list [--run-id RUN_ID] [--mime MIME]
  python3 -m artifacts export ARTIFACT_ID [--ttl TTL] [--base-url URL]
  python3 -m artifacts save NAME PATH [--mime MIME] [--run-id RUN_ID]

Rule #26: lógica en Python, bash solo wrappers.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


def cmd_list(args: argparse.Namespace) -> int:
    from scripts.lib.artifacts.store import ArtifactStore
    from scripts.lib.artifacts.tools import configure_store, list_artifacts

    if args.artifacts_dir:
        configure_store(ArtifactStore(Path(args.artifacts_dir)))

    items = list_artifacts(
        run_id=args.run_id or None,
        filter_mime_type=args.mime or None,
    )
    output = [m.model_dump() for m in items]
    print(json.dumps(output, indent=2, ensure_ascii=False))
    return 0


def cmd_export(args: argparse.Namespace) -> int:
    from scripts.lib.artifacts.store import ArtifactStore
    from scripts.lib.artifacts.tools import configure_store, export_artifact

    if args.artifacts_dir:
        configure_store(ArtifactStore(Path(args.artifacts_dir)))

    result = export_artifact(
        args.artifact_id,
        ttl_seconds=args.ttl,
        base_url=args.base_url or None,
    )
    print(json.dumps(result.model_dump(), indent=2, ensure_ascii=False))
    return 0


def cmd_save(args: argparse.Namespace) -> int:
    from scripts.lib.artifacts.store import ArtifactStore
    from scripts.lib.artifacts.tools import configure_store, save_artifact

    if args.artifacts_dir:
        configure_store(ArtifactStore(Path(args.artifacts_dir)))

    path = Path(args.path)
    if not path.exists():
        print(f"ERROR: fichero no encontrado: {path}", file=sys.stderr)
        return 1

    content = path.read_bytes()
    mime = args.mime or _guess_mime(path)

    ref = save_artifact(
        name=args.name,
        content=content,
        mime_type=mime,
        run_id=args.run_id or None,
    )
    print(json.dumps(ref.model_dump(), indent=2, ensure_ascii=False))
    return 0


def _guess_mime(path: Path) -> str:
    """Inferencia básica de MIME type por extensión."""
    ext = path.suffix.lower()
    mapping = {
        ".csv": "text/csv",
        ".txt": "text/plain",
        ".json": "application/json",
        ".pdf": "application/pdf",
        ".png": "image/png",
        ".jpg": "image/jpeg",
        ".jpeg": "image/jpeg",
        ".md": "text/markdown",
    }
    return mapping.get(ext, "application/octet-stream")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="artifacts",
        description="Savia Agent Artifacts CLI — SPEC-AGENT-ARTIFACTS Slice 1",
    )
    parser.add_argument(
        "--artifacts-dir",
        default=None,
        help="Directorio raíz de artifacts (default: output/artifacts/)",
    )

    sub = parser.add_subparsers(dest="command", required=True)

    # list
    p_list = sub.add_parser("list", help="Listar artifacts de un run")
    p_list.add_argument("--run-id", default=None)
    p_list.add_argument("--mime", default=None, help="Filtrar por MIME type")

    # export
    p_export = sub.add_parser("export", help="Generar URL efímera para un artifact")
    p_export.add_argument("artifact_id")
    p_export.add_argument("--ttl", type=int, default=3600, help="TTL en segundos")
    p_export.add_argument("--base-url", default=None)

    # save
    p_save = sub.add_parser("save", help="Guardar un fichero como artifact")
    p_save.add_argument("name", help="Nombre lógico del artifact")
    p_save.add_argument("path", help="Path al fichero a guardar")
    p_save.add_argument("--mime", default=None)
    p_save.add_argument("--run-id", default=None)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    if args.command == "list":
        return cmd_list(args)
    if args.command == "export":
        return cmd_export(args)
    if args.command == "save":
        return cmd_save(args)

    parser.print_help()
    return 1


if __name__ == "__main__":
    sys.exit(main())
