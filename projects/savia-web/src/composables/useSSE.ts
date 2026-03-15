import { ref } from 'vue'
import { useAuthStore } from '../stores/auth'
import type { StreamEvent } from '../types/chat'

export function useSSE() {
  const isStreaming = ref(false)

  function baseUrl(): string {
    const auth = useAuthStore()
    const proto = auth.useTls ? 'https' : 'http'
    return `${proto}://${auth.host}:${auth.port}`
  }

  async function streamChat(
    message: string,
    sessionId: string,
    onEvent: (ev: StreamEvent) => void
  ) {
    const auth = useAuthStore()
    isStreaming.value = true
    try {
      const res = await fetch(`${baseUrl()}/chat`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'text/event-stream',
          ...(auth.token ? { 'Authorization': `Bearer ${auth.token}` } : {})
        },
        body: JSON.stringify({ message, session_id: sessionId, interactive: true })
      })
      if (!res.body) { isStreaming.value = false; return }

      const reader = res.body.getReader()
      const decoder = new TextDecoder()
      let buffer = ''

      let streamDone = false
      while (!streamDone) {
        const { done, value } = await reader.read()
        if (done) break
        buffer += decoder.decode(value, { stream: true })
        const lines = buffer.split('\n')
        buffer = lines.pop() || ''
        for (const line of lines) {
          if (!line.startsWith('data: ')) continue
          try {
            const ev = JSON.parse(line.slice(6)) as StreamEvent
            onEvent(ev)
            if (ev.type === 'done' || ev.type === 'error') { streamDone = true; break }
          } catch { /* skip malformed */ }
        }
      }
      reader.cancel().catch(() => {})
    } catch (err) {
      onEvent({ type: 'error', text: String(err) })
    } finally {
      isStreaming.value = false
    }
  }

  async function sendPermission(requestId: string, granted: boolean) {
    const auth = useAuthStore()
    try {
      await fetch(`${baseUrl()}/chat/permission`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          ...(auth.token ? { 'Authorization': `Bearer ${auth.token}` } : {})
        },
        body: JSON.stringify({ request_id: requestId, granted })
      })
    } catch { /* silent */ }
  }

  return { isStreaming, streamChat, sendPermission }
}
