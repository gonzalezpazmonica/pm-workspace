import { defineStore } from 'pinia'
import { ref } from 'vue'
import type { ChatMessage, PermissionInfo } from '../types/chat'

export const useChatStore = defineStore('chat', () => {
  const messages = ref<ChatMessage[]>([])
  const sessionId = ref(crypto.randomUUID())
  const currentTool = ref<string | null>(null)
  const pendingPermission = ref<PermissionInfo | null>(null)

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
    messages.value = []
    sessionId.value = crypto.randomUUID()
  }

  return { messages, sessionId, currentTool, pendingPermission, addMessage, updateLastAssistant, finishStreaming, clearMessages }
})
