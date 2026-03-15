---
id: "phase3-user-management"
title: "User Management — Admin Panel with Roles"
status: "approved"
developer_type: "agent-single"
parent_pbi: ""
---

# User Management

## Objetivo

Add a user management page to savia-web accessible only to admins. Manage users, roles, and tokens. Two roles: admin (full access) and user (everything except user management).

## Roles

| Role | Permissions |
|------|------------|
| **admin** | Full access: all pages + user management + token rotation + user creation/deletion |
| **user** | All pages except `/admin/users`. Cannot create/delete users or rotate other users' tokens. Can rotate own token. |

## Requisitos Funcionales

### RF-01: User List Page (`/admin/users`)

- Route: `/admin/users` (admin only, redirect to / if not admin)
- Table: @handle, name, role, created date, last login, status (active/revoked)
- Actions per user: edit role, rotate token, revoke access, delete
- "Add User" button opens form

### RF-02: Add User Form

- Fields: @handle (required, unique), name, email, role (admin/user)
- On create: generates token, shows it ONCE in a modal (copyable)
- Warns: "Save this token — it won't be shown again"

### RF-03: Edit User

- Change name, email, role
- Admin can promote user to admin or demote admin to user
- Cannot demote the last admin (safety)

### RF-04: Token Operations

- **Rotate**: Generate new token, invalidate old one. Show new token once
- **Revoke**: Invalidate token without deleting user (can re-activate later)
- Admin can rotate any user's token
- User can only rotate their own (from Profile page)

### RF-05: Role-Based Route Guard

- Vue Router guard checks user role from auth store
- `/admin/*` routes require `role === 'admin'`
- Non-admin users see no "Users" nav item
- Direct URL access to `/admin/users` redirects to `/`

### RF-06: Bridge Endpoints

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/users` | admin | List all users |
| POST | `/users` | admin | Create user (returns token) |
| PUT | `/users/{slug}` | admin | Update user profile/role |
| DELETE | `/users/{slug}` | admin | Delete user |
| POST | `/users/{slug}/rotate-token` | admin or self | Regenerate token |
| POST | `/users/{slug}/revoke` | admin | Revoke access |

### RF-07: Sidebar Navigation

- Admin sees: all existing nav items + "Users" (Shield icon) between Settings and Profile
- User sees: all nav items except "Users"

## Criterios de Aceptacion

- [ ] Admin can create users with unique tokens
- [ ] Token shown once on creation (not retrievable later)
- [ ] Admin can change user roles
- [ ] Admin can rotate/revoke tokens
- [ ] User cannot access /admin/users (redirected)
- [ ] User can rotate own token from Profile
- [ ] Last admin cannot be demoted
- [ ] Non-admin users don't see "Users" nav item
- [ ] All user operations logged in Bridge audit log
