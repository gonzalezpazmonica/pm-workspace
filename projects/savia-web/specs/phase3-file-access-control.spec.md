---
id: "phase3-file-access-control"
title: "File Access Control by Role"
status: "approved"
developer_type: "agent-single"
parent_pbi: ""
---

# File Access Control by Role

## Objetivo

Restrict file browser access based on user role. Admin can browse the entire Savia workspace. Regular users can only browse project directories. The pm-workspace (Savia) project itself is admin-only.

## Roles and Access

| Path | Admin | User |
|------|-------|------|
| `/` (workspace root: ~/savia/) | Full access | Blocked — redirect to projects/ |
| `projects/` | Full access | Full access |
| `projects/savia-web/` | Full access | Full access |
| `projects/proyecto-alpha/` | Full access | Full access |
| `projects/pm-workspace-devops/` | Full access | Blocked (admin project) |
| `.claude/` | Full access | Blocked |
| `scripts/` | Full access | Blocked |
| `docs/` | Full access | Blocked |

## Requisitos Funcionales

### RF-01: Bridge File Access Filter

- `GET /files?path=X` checks user role from `_auth_user`
- If user role is "user" and path doesn't start with `projects/`:
  - Return 403 Forbidden with message "Access restricted to project directories"
  - Exception: `projects/` itself (listing) is allowed
- Admin-only projects (configurable list): `pm-workspace-devops`

### RF-02: Project Selector Filter

- `GET /projects` filters results by role
- Admin sees all projects including `_workspace` (Savia root)
- User sees only `projects/*` entries, NOT `_workspace`
- The "Savia (workspace)" option is hidden from non-admin users

### RF-03: File Browser UI Adaptation

- When user navigates to `/files`, start at `projects/` not root
- Breadcrumb root for users is "Projects" not "Savia"
- No way for users to navigate above `projects/`

### RF-04: Admin Project List

Configurable list of admin-only projects in Bridge config:
```
ADMIN_ONLY_PROJECTS = ["pm-workspace-devops"]
```

## Criterios de Aceptacion

- [ ] Admin can browse full workspace including root, .claude/, scripts/
- [ ] User cannot access root directory (redirected to projects/)
- [ ] User cannot access .claude/, scripts/, docs/ via file browser
- [ ] User sees only project directories in project selector (no workspace)
- [ ] Admin-only projects are hidden from regular users
- [ ] Bridge returns 403 for unauthorized file access attempts
- [ ] File browser breadcrumb starts at "Projects" for regular users
