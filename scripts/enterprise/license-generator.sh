#!/usr/bin/env bash
# license-generator.sh — SPEC-SE-008 MIT License Generator for Savia Enterprise Components
set -uo pipefail
#
# Genera licencias MIT para los componentes Savia Enterprise.
#
# Args:
#   --component NAME    Component name (required)
#   --year YYYY         Copyright year (default: current year)
#   --org "Nombre Org"  Organization name (default: "Savia Enterprise Contributors")
#   --output-dir DIR    Output directory (default: current dir)
#
# Output: LICENSE.md with MIT text + attribution
#         NOTICE.md with third-party attribution notice
#
# Reference: SPEC-SE-008 (docs/propuestas/savia-enterprise/SPEC-SE-008-licensing-distribution.md)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# ── Helpers ──────────────────────────────────────────────────────────────────

usage() {
  cat <<'USAGE'
license-generator.sh — SPEC-SE-008 MIT License Generator

Usage:
  license-generator.sh --component NAME [--year YYYY] [--org "ORG"] [--output-dir DIR]
  license-generator.sh --help

Options:
  --component NAME    Component identifier (required)
  --year YYYY         Copyright year (default: current year)
  --org "ORG"         Copyright holder (default: "Savia Enterprise Contributors")
  --output-dir DIR    Where to write LICENSE.md and NOTICE.md (default: current dir)

Output files:
  LICENSE.md   MIT license text with attribution
  NOTICE.md    Third-party attribution notice

Notes:
  All Savia Enterprise modules use MIT license (SPEC-SE-008 strategy).
  Documentation components use CC-BY-4.0 — generate separately.
USAGE
  exit 0
}

die() { echo "ERROR: $*" >&2; exit 1; }

COMPONENT=""
YEAR="$(date +%Y)"
ORG="Savia Enterprise Contributors"
OUTPUT_DIR="."

while [[ $# -gt 0 ]]; do
  case "$1" in
    --component)  COMPONENT="$2";  shift 2 ;;
    --year)       YEAR="$2";       shift 2 ;;
    --org)        ORG="$2";        shift 2 ;;
    --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) die "unknown argument: $1" ;;
  esac
done

[[ -z "$COMPONENT" ]] && die "--component is required"

# Validate year
if ! [[ "$YEAR" =~ ^[0-9]{4}$ ]]; then
  die "--year must be a 4-digit year (got: ${YEAR})"
fi

mkdir -p "$OUTPUT_DIR"

LICENSE_FILE="${OUTPUT_DIR}/LICENSE.md"
NOTICE_FILE="${OUTPUT_DIR}/NOTICE.md"

GENERATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# ── Generate LICENSE.md ───────────────────────────────────────────────────────

cat > "$LICENSE_FILE" <<LICENSE
# License — ${COMPONENT}

**License:** MIT
**Generated:** ${GENERATED_AT}
**Spec:** SPEC-SE-008 — Licensing & Distribution Strategy

---

MIT License

Copyright (c) ${YEAR} ${ORG}

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

---

## Attribution

This component (${COMPONENT}) is part of **Savia Enterprise** — an AI-supervised
project management workspace developed by ${ORG}.

- Savia Core: MIT license (same terms)
- Savia Enterprise modules: MIT license (same terms)
- Documentation: CC-BY-4.0

"Savia" and "Savia Enterprise" are project names. Forks must use a different name.
Use for attribution is permitted. Use in derived products requiring a different
name without attribution is not permitted.

See NOTICE.md for third-party component attributions.

## Trademark Note

The names "Savia" and "Savia Enterprise" are used as project identifiers.
They are not registered trademarks. Use for attribution is always permitted.
See docs/rules/domain/enterprise-licensing-policy.md for full trademark policy.
LICENSE

echo "  → ${LICENSE_FILE}"

# ── Generate NOTICE.md ────────────────────────────────────────────────────────

cat > "$NOTICE_FILE" <<NOTICE
# NOTICE — ${COMPONENT}

**Component:** ${COMPONENT}
**License:** MIT
**Generated:** ${GENERATED_AT}

This file lists third-party components used by ${COMPONENT} that require attribution.

---

## Savia Core

- License: MIT
- Copyright: Savia Enterprise Contributors
- URL: https://github.com/savia-enterprise/pm-workspace

## Third-party Dependencies

This component has no mandatory third-party runtime dependencies.
All shell scripts use POSIX-compatible tools (bash, sha256sum, grep, awk).

If you add dependencies, document them here with:
  - Name, version, license, copyright holder, source URL

---

## License Compatibility Notes

Per SPEC-SE-008 strategy, dependencies with the following licenses are
NOT permitted in Savia Enterprise components:

- GPL-2.0, GPL-3.0 — copyleft incompatible with MIT distribution
- AGPL-3.0 — network use disclosure requirement (incompatible with sovereign deployment)
- BSL (Business Source License) — vendor lock-in, incompatible with principles
- SSPL — not OSI-approved

Permitted: MIT, Apache-2.0, BSD-2/3-Clause, ISC, CC-BY-4.0 (docs only), MPL-2.0 (file-level).

Run scripts/enterprise/commercial-terms-check.sh to verify dependency compatibility.
NOTICE

echo "  → ${NOTICE_FILE}"
echo "OK: MIT license generated for '${COMPONENT}' (${YEAR}, ${ORG})"
