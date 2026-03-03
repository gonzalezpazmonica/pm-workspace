#!/bin/bash
# company-repo-templates-init.sh — Heredoc templates for repo initialization
# Sourced by company-repo-templates.sh — do NOT run directly.

# ── Init: create full repo structure ────────────────────────────────
do_init() {
  local repo_dir="${1:?Uso: company-repo-templates.sh init <dir> <org_name> <admin_handle>}"
  local org_name="${2:?Falta org_name}"
  local admin_handle="${3:?Falta admin_handle}"

  # Company directories
  mkdir -p "$repo_dir"/{company/{rules,resources,projects,inbox},users,teams}
  # Savia Flow directories (teams already created above)

  # README.md
  cat > "$repo_dir/README.md" <<EOF
# ${org_name} — Company Savia

Shared knowledge repository for **${org_name}**, powered by [Company Savia](https://github.com/gonzalezpazmonica/pm-workspace).

## Structure

- \`company/\` — Org identity, rules, resources (protected by CODEOWNERS)
- \`users/{handle}/\` — Personal folders (self-service per member)
- \`company/inbox/\` — Company-wide announcements (persistent)

## Getting Started

1. Ask your admin for this repo URL
2. Run \`/company-repo connect\` in pm-workspace
3. Your personal folders are created automatically
EOF

  # CHANGELOG.md
  cat > "$repo_dir/CHANGELOG.md" <<EOF
# Changelog — ${org_name}

## [1.0.0] — $(date +%Y-%m-%d)
- Company Savia repository initialized by @${admin_handle}
EOF

  # CODEOWNERS
  cat > "$repo_dir/CODEOWNERS" <<EOF
# Company Savia — CODEOWNERS
# company/ is protected: only admins can modify
company/ @${admin_handle}
# Personal folders: each member owns their own
# users/{handle}/ @{handle}  (added on connect)
EOF

  # .github/PULL_REQUEST_TEMPLATE.md
  mkdir -p "$repo_dir/.github"
  cat > "$repo_dir/.github/PULL_REQUEST_TEMPLATE.md" <<'EOF'
## What changes
<!-- Brief description -->

## Why
<!-- Motivation -->

## Affected areas
- [ ] company/ (requires admin review)
- [ ] users/{my-handle}/ (personal folder)
- [ ] company/inbox/ (announcement)
EOF

  # directory.md — team directory
  cat > "$repo_dir/directory.md" <<EOF
# Team Directory — ${org_name}

| Handle | Name | Role | Status |
|--------|------|------|--------|
| @${admin_handle} | Admin | Admin | active |
EOF

  # .gitignore
  cat > "$repo_dir/.gitignore" <<'EOF'
# Private keys (never commit)
*.pem
!**/pubkey.pem
*.key
.env*
config.local/
*.secret
EOF

  # Company identity files
  cat > "$repo_dir/company/identity.md" <<EOF
# ${org_name}

- **Founded**: $(date +%Y)
- **Admin**: @${admin_handle}
- **Savia Version**: Company Savia v0.99.0
EOF

  cat > "$repo_dir/company/org-chart.md" <<EOF
# Org Chart — ${org_name}

## Teams
- Default Team: @${admin_handle} (admin)
EOF

  cat > "$repo_dir/company/holidays.md" <<EOF
# Holidays — ${org_name}

## $(date +%Y)
<!-- Add company holidays here -->
| Date | Description |
|------|-------------|
EOF

  cat > "$repo_dir/company/conventions.md" <<EOF
# Conventions — ${org_name}

## Communication
- Use @handle for addressing team members
- Company announcements go to \`company/inbox/\`
- Personal messages go to \`users/{handle}/inbox/\`

## Encryption
- E2E encryption available (RSA-4096 + AES-256-CBC)
- Public keys stored in \`users/{handle}/pubkey.pem\`
EOF

  log_ok "Repo structure created at $repo_dir"
}
