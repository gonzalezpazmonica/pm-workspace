---
id: "phase3-chat-multithread"
title: "Chat Multi-Thread — Session-Scoped Streaming"
status: "approved"
developer_type: "agent-single"
parent_pbi: ""
---

# Chat Multi-Thread — Session-Scoped Streaming

## Problema

When user switches between chat sessions while a response is streaming,
the SSE events from session A are written into session B's messages.
This is because:

1. The SSE stream is not cancelled on session switch
2. `updateLastAssistant()` writes to the current active messages array
   regardless of which session the response belongs to
3. There is no session-scoping of streaming events

## Solución

Associate every streaming operation with its originating session ID.
Cancel active streams on session switch. Guard message updates against
session mismatch.

## Requisitos Funcionales

### RF-01: Session-Scoped Streaming

- `streamChat()` receives `sessionId` and captures it in closure
- `onEvent` callback checks that `store.sessionId` still matches
  the original session before writing to messages
- If mismatch: event is silently dropped (belongs to background session)

### RF-02: Cancel Stream on Session Switch

- When user clicks a different session in the list:
  1. Call `reader.cancel()` on any active SSE stream
  2. Mark current streaming message as finished (remove isStreaming flag)
  3. Save current session's messages to localStorage
  4. Load new session's messages
- Expose a `cancelStream()` function from `useSSE` composable

### RF-03: Background Response Handling

- When a streamed response arrives for a non-active session:
  - Option A (simple): Drop it — user will re-send when switching back
  - Option B (advanced): Buffer it in a per-session queue
- For v1: use Option A (drop) with session guard in onEvent

### RF-04: Visual Indicator

- If user switches session while streaming, show brief toast:
  "Response in progress — switching will stop it"
- Or: disable session switching while streaming (simpler)

## Implementación Recomendada

```typescript
// In ChatPage.vue send():
const originSession = store.sessionId  // capture at send time

await streamChat(text, originSession, (ev) => {
  // Guard: only write if still on the same session
  if (store.sessionId !== originSession) return
  // ... handle event
})
```

```typescript
// In useSSE.ts:
let activeReader: ReadableStreamDefaultReader | null = null

function cancelStream() {
  activeReader?.cancel().catch(() => {})
  activeReader = null
  isStreaming.value = false
}
```

```typescript
// In chat store switchSession():
// Cancel any active stream before switching
```

## Criterios de Aceptacion

- [ ] Sending in session A, switching to B: response stays in A (not B)
- [ ] Switching session cancels active SSE stream
- [ ] Streaming indicator clears on session switch
- [ ] Re-sending in session B works independently
- [ ] Messages don't leak between sessions
- [ ] E2E test validates cross-session isolation
