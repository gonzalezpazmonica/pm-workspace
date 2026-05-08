#!/usr/bin/env python3
"""
vault-init.py — Idempotent vault scaffolder for SPEC-PROJECT-UPDATE F1.

Creates per-project vault structure under:
  projects/{slug}_main/{slug}-{username}/vault/

Layout:
  00-Inbox/        Quick captures, unsorted notes
  10-PBIs/         Product Backlog Items (one .md per PBI)
  20-Decisions/    Architectural & business decisions
  30-Meetings/     Meeting notes & digests
  40-Stakeholders/ People & companies
  50-Digests/      Aggregated source digests (mail, calendar, sharepoint)
  60-Risks/        Risk register entries
  70-Specs/        Specs (spec writer output, not the canonical docs/specs/)
  80-Sessions/     Work session logs
  90-MOC/          Maps of Content (index notes)
  templates/       Frontmatter templates per entity_type

Idempotent: existing dirs/files are left untouched. Templates are written only
if missing (or with --force-templates to overwrite).

Templates emit frontmatter that validates against scripts/vault-validate.py.

Usage:
  vault-init.py --slug aurora [--username monica] [--root .]
  vault-init.py --slug aurora --dry-run
  vault-init.py --slug aurora --force-templates
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

VAULT_DIRS = [
    "00-Inbox",
    "10-PBIs",
    "20-Decisions",
    "30-Meetings",
    "40-Stakeholders",
    "50-Digests",
    "60-Risks",
    "70-Specs",
    "80-Sessions",
    "90-MOC",
    "templates",
]

# Templates emit valid frontmatter per scripts/vault-validate.py schema.
# Common required: confidentiality, project, entity_type, title, created, updated.
# Per-entity required (see ENTITY_REQUIRED in vault-validate.py):
#   pbi:      pbi_id, state
#   decision: decision_id, decided_at
#   meeting:  meeting_id, meeting_date, attendees, transcript_source, digest_status
#   person:   role
#   risk:     risk_id, severity, status, owner
#   spec:     spec_id, status
#   session:  session_date, frontend
#   digest:   source, source_id, digested_at, digest_agent
#   moc, inbox: only common
TEMPLATES: dict[str, str] = {
    "pbi.md": """---
entity_type: pbi
project: {{slug}}
title: "<PBI title>"
confidentiality: N4
pbi_id: "PBI-XXXX"
state: new
created: {{date}}
updated: {{date}}
tags: []
---

# {{title}}

## Context

<Why this PBI exists. Link to source: meeting, email, decision.>

## Acceptance criteria

- [ ] AC-1
- [ ] AC-2

## Notes

""",
    "decision.md": """---
entity_type: decision
project: {{slug}}
title: "<Decision title>"
confidentiality: N4
decision_id: "DEC-XXXX"
decided_at: {{date}}
created: {{date}}
updated: {{date}}
tags: []
---

# {{title}}

## Context

<Forces in tension. What problem are we solving?>

## Decision

<What did we decide?>

## Consequences

<Trade-offs accepted. What did we sacrifice?>

## Alternatives considered

""",
    "meeting.md": """---
entity_type: meeting
project: {{slug}}
title: "<Meeting subject>"
confidentiality: N4
meeting_id: "MTG-XXXX"
meeting_date: {{date}}
attendees: ["TBD"]
transcript_source: "TBD"
digest_status: pending
created: {{date}}
updated: {{date}}
tags: []
---

# {{title}}

## Agenda

## Decisions

## Action items

- [ ] @owner — action — due YYYY-MM-DD

## Notes

""",
    "person.md": """---
entity_type: person
project: {{slug}}
title: "<Full name>"
confidentiality: N4b
role: "TBD"
created: {{date}}
updated: {{date}}
tags: []
---

# {{title}}

## Context

<Role in project. Why they matter.>

## Communication preferences

## History

""",
    "risk.md": """---
entity_type: risk
project: {{slug}}
title: "<Risk title>"
confidentiality: N4
risk_id: "RSK-XXXX"
severity: medium
status: open
owner: "TBD"
created: {{date}}
updated: {{date}}
tags: []
---

# {{title}}

## Description

## Impact

## Likelihood

## Mitigation

""",
    "spec.md": """---
entity_type: spec
project: {{slug}}
title: "<Spec title>"
confidentiality: N4
spec_id: "SPEC-XXXX"
status: pending
created: {{date}}
updated: {{date}}
tags: []
---

# {{title}}

## Goal

## Constraints

## Acceptance criteria

## Out of scope

""",
    "session.md": """---
entity_type: session
project: {{slug}}
title: "<Session label>"
confidentiality: N4
session_date: {{date}}
frontend: opencode
created: {{date}}
updated: {{date}}
tags: []
---

# {{title}}

## Goal

## Done

## Next

""",
    "digest.md": """---
entity_type: digest
project: {{slug}}
title: "<Digest source/period>"
confidentiality: N4
source: meeting
source_id: "TBD"
digested_at: {{date}}
digest_agent: "TBD"
created: {{date}}
updated: {{date}}
tags: []
---

# {{title}}

## Highlights

## Threads

## Action items

""",
    "moc.md": """---
entity_type: moc
project: {{slug}}
title: "<Map of Content title>"
confidentiality: N4
created: {{date}}
updated: {{date}}
tags: [moc]
---

# {{title}}

## Index

- [[note-1]]
- [[note-2]]

""",
    "inbox.md": """---
entity_type: inbox
project: {{slug}}
title: "<Capture title>"
confidentiality: N4
created: {{date}}
updated: {{date}}
tags: [inbox]
---

# {{title}}

<Raw capture. Process later into PBI / Decision / Meeting / etc.>

""",
}

README_TEMPLATE = """# Vault — {slug}

Per-project knowledge vault. Frontmatter-gated.

## Structure

| Folder           | Purpose                                  |
|------------------|------------------------------------------|
| 00-Inbox/        | Quick captures, unsorted                 |
| 10-PBIs/         | Product Backlog Items                    |
| 20-Decisions/    | ADR-style decisions                      |
| 30-Meetings/     | Meeting notes & digests                  |
| 40-Stakeholders/ | People & companies                       |
| 50-Digests/      | Source digests (mail, calendar, etc.)    |
| 60-Risks/        | Risk register                            |
| 70-Specs/        | Spec drafts                              |
| 80-Sessions/     | Work session logs                        |
| 90-MOC/          | Maps of Content (indexes)                |
| templates/       | Frontmatter templates per entity_type    |

## Rules

1. Every `.md` MUST have valid frontmatter — see `templates/`.
2. `confidentiality` MUST be one of: N1, N2, N3, N4, N4b.
3. Files under `projects/` default to N4 (project-level).
4. Personal data → N4b. Internal infra → N2/N3. Public artefacts → N1.
5. The hook `vault-frontmatter-gate.sh` blocks writes with invalid frontmatter.

## Generated by

`scripts/vault-init.py` — SPEC-PROJECT-UPDATE F1.
"""

SLUG_RE = re.compile(r"^[a-z0-9]([a-z0-9-]*[a-z0-9])?$")


def validate_slug(slug: str) -> None:
    if not SLUG_RE.match(slug):
        raise SystemExit(
            f"ERROR: invalid slug '{slug}'. "
            f"Use lowercase a-z, 0-9, hyphens; start/end alphanumeric."
        )


def resolve_username(explicit: str | None, root: Path) -> str:
    if explicit:
        validate_slug(explicit)
        return explicit
    profile = root / ".claude" / "profiles" / "active-user.md"
    if profile.exists():
        try:
            text = profile.read_text(encoding="utf-8")
            m = re.search(r'^active_slug:\s*"?([^"\n]+)"?\s*$', text, re.M)
            if m:
                return m.group(1).strip()
        except OSError:
            pass
    return "user"


def vault_path(root: Path, slug: str, username: str) -> Path:
    return root / "projects" / f"{slug}_main" / f"{slug}-{username}" / "vault"


def render_template(content: str, slug: str, date: str) -> str:
    title_default = slug.replace("-", " ").title()
    return (
        content.replace("{{slug}}", slug)
        .replace("{{date}}", date)
        .replace("{{title}}", title_default)
    )


def init_vault(
    root: Path,
    slug: str,
    username: str,
    dry_run: bool,
    force_templates: bool,
) -> int:
    from datetime import date as _date

    today = _date.today().isoformat()
    base = vault_path(root, slug, username)
    created = 0
    skipped = 0
    overwritten = 0

    def announce(action: str, target: Path) -> None:
        try:
            rel = target.relative_to(root)
        except ValueError:
            rel = target
        print(f"  {action:13s} {rel}")

    print(f"vault-init: slug={slug} username={username} dry_run={dry_run}")
    print(f"  target: {base}")

    # Directories
    for d in VAULT_DIRS:
        target = base / d
        if target.exists():
            skipped += 1
            announce("skip-dir", target)
            continue
        if not dry_run:
            target.mkdir(parents=True, exist_ok=True)
        created += 1
        announce("mkdir", target)

    # README at vault root
    readme = base / "README.md"
    if readme.exists() and not force_templates:
        skipped += 1
        announce("skip-readme", readme)
    else:
        existed = readme.exists()
        if not dry_run:
            base.mkdir(parents=True, exist_ok=True)
            readme.write_text(README_TEMPLATE.format(slug=slug), encoding="utf-8")
        if existed:
            overwritten += 1
            announce("overwrite", readme)
        else:
            created += 1
            announce("write", readme)

    # Templates
    tpl_dir = base / "templates"
    for name, content in TEMPLATES.items():
        target = tpl_dir / name
        rendered = render_template(content, slug, today)
        if target.exists() and not force_templates:
            skipped += 1
            announce("skip-tpl", target)
            continue
        existed = target.exists()
        if not dry_run:
            tpl_dir.mkdir(parents=True, exist_ok=True)
            target.write_text(rendered, encoding="utf-8")
        if existed:
            overwritten += 1
            announce("overwrite", target)
        else:
            created += 1
            announce("write", target)

    print(
        f"\nvault-init: done. created={created} skipped={skipped} "
        f"overwritten={overwritten} dry_run={dry_run}"
    )
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    ap.add_argument("--slug", required=True, help="Project slug (lowercase, hyphens).")
    ap.add_argument(
        "--username",
        default=None,
        help="Active user slug (default: from .claude/profiles/active-user.md).",
    )
    ap.add_argument("--root", default=".", help="Workspace root (default: cwd).")
    ap.add_argument("--dry-run", action="store_true", help="Show actions without writing.")
    ap.add_argument(
        "--force-templates",
        action="store_true",
        help="Overwrite README + templates if they exist (dirs & user notes never touched).",
    )
    args = ap.parse_args()

    validate_slug(args.slug)
    root = Path(args.root).resolve()
    username = resolve_username(args.username, root)

    return init_vault(
        root=root,
        slug=args.slug,
        username=username,
        dry_run=args.dry_run,
        force_templates=args.force_templates,
    )


if __name__ == "__main__":
    sys.exit(main())
