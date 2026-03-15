---
id: "phase3-chat-sessions"
title: "Chat Session Management — List, Switch, New"
status: "approved"
developer_type: "agent-single"
parent_pbi: ""
---

# Chat Session Management

## Objetivo

Allow users to manage multiple chat sessions like Claude Code CLI: list past sessions, switch between them, start new ones. Sessions persist across page reloads.

## Requisitos Funcionales

### RF-01: Session List Sidebar

- Collapsible panel on the left side of the chat page
- Shows all sessions for the current user, sorted by last activity (newest first)
- Each entry: title (date + first message digest, e.g. "Mar 15 — hola sabes quién..."), message count
- Active session highlighted
- Toggle button to show/hide session list

### RF-02: New Session

- "New Chat" button at top of session list
- Creates a fresh session with new UUID
- Clears message history in the chat view
- Previous session remains in the list

### RF-03: Switch Session

- Click a session in the list to switch to it
- Loads message history from Bridge GET `/sessions/{id}/messages`
- Current session state saved before switching

### RF-04: Session Persistence

- Session list stored in localStorage: `savia:chat:sessions`
- Each session: `{ id, title, createdAt, lastMessageAt, messageCount }`
- On page load, restore last active session
- Messages stored per-session in localStorage: `savia:chat:messages:{id}`

### RF-05: Bridge Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/sessions` | List all sessions (already exists) |
| DELETE | `/sessions/{id}` | Delete a specific session |

### RF-06: Delete Session

- Delete icon on each session entry (visible on hover)
- Reactive: session disappears immediately from list (splice, not filter)
- Cannot delete the currently active session (switch first)

### RF-07: Session Title Format

- New session: "New chat — Mar 15, 17:30"
- After first user message: "Mar 15 — first 30 chars of message..."
- Ensures unique, identifiable titles for each session

## Criterios de Aceptacion

- [ ] Session list shows past conversations
- [ ] "New Chat" creates fresh session
- [ ] Clicking a session loads its history
- [ ] Sessions persist across page reload
- [ ] Active session is visually highlighted
- [ ] Delete removes session from list and Bridge
