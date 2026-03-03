# Message Schema — Company Savia (Branch-Based)

## Location

- **Pending delivery**: `exchange:pending/{msg_id}.md`
- **Personal inbox**: `user/{handle}/inbox/unread/{msg_id}.md` → `user/{handle}/inbox/read/{msg_id}.md`
- **Sent archive**: `user/{handle}/outbox/{msg_id}.md`
- **Announcements**: `main:company/announcements/{msg_id}.md` (admin-only)

## YAML Frontmatter

```yaml
---
id: YYYYMMDD-HHMMSS-{pid}
type: direct | reply | broadcast | announcement
sender: {handle}
recipient: {handle} | {team} | *
subject: "Plain text, no sensitive data"
created: ISO 8601 UTC
thread: {msg_id} | null
reply_to: {msg_id} | null
encrypted: false | true
encryption_alg: AES-256-CBC
encrypted_key: base64:{key}
read_at: ISO 8601 UTC | null
---
```

## Message Body

**Unencrypted**: plain markdown (bullets, links, code blocks, tables).
**Encrypted**: `{base64_encrypted_body}` — decrypt with `openssl enc -d -aes-256-cbc`.

## Field Definitions

| Field | Type | Req | Notes |
|---|---|---|---|
| `id` | string | Yes | YYYYMMDD-HHMMSS-{pid}, unique |
| `type` | enum | Yes | direct, reply, broadcast, announcement |
| `sender` | string | Yes | @handle (resolved from main:pubkeys/) |
| `recipient` | string | Yes | @handle, @team, or * |
| `subject` | string | Yes | ≤100 chars, NO PII/secrets |
| `created` | string | Yes | ISO 8601 UTC |
| `thread` | string | No | Parent thread msg ID |
| `reply_to` | string | No | Direct parent msg ID |
| `encrypted` | bool | Yes | True if body encrypted |
| `encryption_alg` | string | No | AES-256-CBC only |
| `encrypted_key` | string | No | Required if encrypted=true |
| `read_at` | string | No | ISO 8601 UTC when opened |

## Exchange Pattern

Pending messages in `exchange:pending/` follow schema above.
On sync, recipient fetches pending, decrypts if needed, writes to `user/{handle}/inbox/unread/`, removes from exchange.

## Example: Direct Message

```markdown
---
id: 20260303-091500-4521
type: direct
sender: alice
recipient: bob
subject: "Sprint planning clarification"
created: 2026-03-03T09:15:00Z
encrypted: false
---
Can you clarify the acceptance criteria for feature XYZ?
```

## Example: Encrypted Reply

```markdown
---
id: 20260303-101200-4522
type: reply
sender: bob
recipient: alice
subject: "Re: Sprint planning clarification"
created: 2026-03-03T10:12:00Z
thread: 20260303-091500-4521
reply_to: 20260303-091500-4521
encrypted: true
encryption_alg: AES-256-CBC
encrypted_key: base64:yv66vgBV...
---
{base64_encrypted_body}
```

## Example: Announcement

```markdown
---
id: 20260303-080000-admin
type: announcement
sender: admin
recipient: "*"
subject: "Server maintenance window"
created: 2026-03-03T08:00:00Z
encrypted: false
---
All services will be down for ~1 hour Friday 6-7pm.
```

## Validation

Savia validates on creation, delivery, and fetch:
1. All required fields present and well-formed
2. `id` unique, `sender` exists in main:pubkeys/
3. `recipient` valid (@handle, @team, or *)
4. If encrypted=true, encrypted_key present and valid base64
5. `subject` has no detected PII (via privacy-check-company.sh)
