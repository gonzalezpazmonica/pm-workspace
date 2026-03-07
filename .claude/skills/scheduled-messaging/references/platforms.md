---
name: API Reference — Messaging Platforms
---

# API Reference: Plataformas

## Telegram Bot API

**Endpoint:** `https://api.telegram.org/bot{TOKEN}/sendMessage`
**Method:** POST | **Content-Type:** `application/json`

```json
{"chat_id":"{ID}","text":"Message","parse_mode":"Markdown"}
```

**Markdown:** `*bold*` `_italic_` `` `code` `` `[link](url)`
**Success:** HTTP 200, `"ok": true`

---

## Slack Webhooks

**Endpoint:** `{WEBHOOK_URL}` | **Method:** POST

```json
{"text":"Simple","blocks":[{"type":"section","text":{"type":"mrkdwn","text":"*Bold*"}}]}
```

**Success:** HTTP 200, "ok"

---

## Teams Adaptive Cards

**Endpoint:** `{WEBHOOK_URL}` | **Method:** POST

```json
{"@type":"MessageCard","@context":"https://schema.org/extensions","summary":"","themeColor":"0078D4","sections":[{"activityTitle":"","text":""}]}
```

**Success:** HTTP 200

---

## WhatsApp Twilio

**Endpoint:** `https://api.twilio.com/2010-04-01/Accounts/{SID}/Messages`
**Auth:** `Basic {base64(SID:Token)}`

```
From=whatsapp:{FROM}
To=whatsapp:{TO}
Body=Plain text (max 1600)
```

**Success:** HTTP 201, `"status":"queued"`

---

## NextCloud Talk

**Endpoint:** `{SERVER}/ocs/v2.php/apps/spreed/api/v4/chat/{conversationId}`
**Auth:** `Bearer {TOKEN}`

```
message=Plain text
```

**Get rooms:**
```
GET {SERVER}/ocs/v2.php/apps/spreed/api/v4/rooms
```

**Success:** HTTP 201, `"ocs":{"meta":{"status":"ok"}}`

---

## Error Handling

| Platform | Error | HTTP | Retry? | Wait |
|---|---|---|---|---|
| Telegram | Invalid token | 401 | No | — |
| Slack | Rate limit | 429 | Yes | 60s |
| Teams | Timeout | 408 | Yes | 30s |
| WhatsApp | Invalid # | 400 | No | — |
| NextCloud | 401 | No | — |

---

## Curl with Retry

```bash
# Telegram: 10s, 3x, 1s delay
curl -m 10 --retry 3 --retry-delay 1 https://api.telegram.org/...

# Slack: 10s, 2x, 2s delay
curl -m 10 --retry 2 --retry-delay 2 {WEBHOOK}

# Teams: 10s, 2x
curl -m 10 --retry 2 --retry-delay 2 {WEBHOOK}

# WhatsApp: 15s, 1x, 5s (slow API)
curl -m 15 --retry 1 --retry-delay 5 https://api.twilio.com/...

# NextCloud: 10s, 2x, 3s
curl -m 10 --retry 2 --retry-delay 3 {SERVER}/...
```

---

## Differences

- **Markdown:** Telegram ✅, Slack ✅, Teams ❌, WhatsApp ❌, NextCloud ❌
- **Auth:** Telegram/Slack (webhook), WhatsApp (basic), NextCloud (bearer)
- **Max length:** Telegram 4096, Slack 40000, Teams unlimited, WhatsApp 1600, NextCloud varies
