import { defineStore } from 'pinia'
import { ref } from 'vue'
import { useAuthStore } from './auth'
import type { ChatMessage, PermissionInfo } from '../types/chat'

export interface SessionInfo {
  id: string
  title?: string
  updatedAt?: number
}

export const useChatStore = defineStore('chat', () => {
  const messages = ref<ChatMessage[]>([])
  const sessionId = ref('')
  const currentTool = ref<string | null>(null)
  const pendingPermission = ref<PermissionInfo | null>(null)
  const sessions = ref<SessionInfo[]>([])

  function initSession(username: string) {
    const slug = username.replace(/^@/, '')
    sessionId.value = `${slug}-default`
  }

  function addMessage(msg: ChatMessage) {
    messages.value.push(msg)
  }

  function updateLastAssistant(text: string) {
    for (let i = messages.value.length - 1; i >= 0; i--) {
      if (messages.value[i].role === 'assistant' && messages.value[i].isStreaming) {
        messages.value[i].content += text
        return
      }
    }
  }

  function finishStreaming() {
    for (const msg of messages.value) {
      if (msg.isStreaming) msg.isStreaming = false
    }
    currentTool.value = null
  }

  function clearMessages() {
    const auth = useAuthStore()
    const slug = auth.username.replace(/^@/, '')
    messages.value = []
    sessionId.value = `${slug}-${Date.now()}`
  }

  async function loadSessions() {
    const auth = useAuthStore()
    if (!auth.serverUrl || !auth.token) return
    try {
      const res = await fetch(`${auth.serverUrl}/sessions`, {
        headers: { 'Authorization': `Bearer ${auth.token}` },
      })
      if (res.ok) {
        const data = await res.json()
        sessions.value = Array.isArray(data) ? data : (data.sessions ?? [])
      }
    } catch {
      // silently ignore — sessions are optional
    }
  }

  function switchSession(id: string) {
    messages.value = []
    sessionId.value = id
  }

  return {
    messages, sessionId, currentTool, pendingPermission, sessions,
    initSession, addMessage, updateLastAssistant, finishStreaming,
    clearMessages, loadSessions, switchSession,
  }
})
