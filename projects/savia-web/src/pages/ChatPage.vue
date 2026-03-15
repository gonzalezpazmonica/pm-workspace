<script setup lang="ts">
import { ref, nextTick, watch, onMounted } from 'vue'
import { useChatStore } from '../stores/chat'
import { useSSE } from '../composables/useSSE'
import { useAuthStore } from '../stores/auth'
import { marked } from 'marked'
import { PanelLeftClose, PanelLeftOpen } from 'lucide-vue-next'
import ChatSessionList from '../components/ChatSessionList.vue'
import type { StreamEvent } from '../types/chat'

function renderMd(text: string): string {
  if (!text) return '...'
  return marked.parse(text, { gfm: true, breaks: true }) as string
}

const store = useChatStore()
const auth = useAuthStore()
const { isStreaming, streamChat, sendPermission } = useSSE()

const showSessions = ref(true)

onMounted(() => {
  store.initSession(auth.username)
  store.loadSessions()
})
const input = ref('')
const messagesEl = ref<HTMLElement | null>(null)

function scrollBottom() {
  nextTick(() => { messagesEl.value?.scrollTo(0, messagesEl.value.scrollHeight) })
}

watch(() => store.messages.length, scrollBottom)

async function send() {
  const text = input.value.trim()
  if (!text || isStreaming.value) return
  input.value = ''
  store.addMessage({ id: crypto.randomUUID(), role: 'user', content: text, timestamp: Date.now(), isStreaming: false })
  const assistantId = crypto.randomUUID()
  store.addMessage({ id: assistantId, role: 'assistant', content: '', timestamp: Date.now(), isStreaming: true })
  scrollBottom()

  await streamChat(text, store.sessionId, (ev: StreamEvent) => {
    if (ev.type === 'text') { store.updateLastAssistant(ev.text); scrollBottom() }
    else if (ev.type === 'tool_use') store.currentTool = ev.toolName ?? null
    else if (ev.type === 'permission_request') {
      store.pendingPermission = { requestId: ev.requestId ?? '', toolName: ev.toolName ?? '', toolInput: ev.toolInput ?? {}, description: ev.description ?? '' }
    }
    else if (ev.type === 'error') {
      const errorText = ev.text?.includes('Session conflict')
        ? 'Session sync — please resend your message.'
        : (ev.text || 'Connection error — check Bridge settings')
      store.updateLastAssistant(errorText)
      store.finishStreaming()
    }
    else if (ev.type === 'done') store.finishStreaming()
  })
}

async function handlePermission(granted: boolean) {
  if (!store.pendingPermission) return
  await sendPermission(store.pendingPermission.requestId, granted)
  store.pendingPermission = null
}

function formatTime(ts: number) {
  return new Date(ts).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
}
</script>

<template>
  <div class="chat-page" :class="{ 'has-sidebar': showSessions }">
    <ChatSessionList v-if="showSessions" />
    <div class="chat-main">
    <button class="toggle-sessions" @click="showSessions = !showSessions" :title="showSessions ? 'Hide sessions' : 'Show sessions'">
      <component :is="showSessions ? PanelLeftClose : PanelLeftOpen" :size="16" />
    </button>
    <div ref="messagesEl" class="messages">
      <div v-if="!store.messages.length" class="empty-chat">
        <img src="/savia-logo.png" alt="Savia" class="empty-logo" />
        <p class="empty-title">Chat with Savia</p>
        <p class="empty-hint">Type a message below to start a conversation</p>
      </div>
      <div v-for="msg in store.messages" :key="msg.id" class="msg" :class="msg.role">
        <div class="bubble">
          <div v-if="msg.isStreaming && !msg.content" class="typing-indicator">
            <span class="dot" /><span class="dot" /><span class="dot" />
          </div>
          <div v-else class="bubble-content" v-html="renderMd(msg.content)" />
          <span class="bubble-time">{{ formatTime(msg.timestamp) }}</span>
        </div>
      </div>
      <div v-if="store.currentTool" class="tool-indicator">Using {{ store.currentTool }}...</div>
    </div>
    <div v-if="store.pendingPermission" class="permission-bar">
      <span>{{ store.pendingPermission.toolName }}: {{ store.pendingPermission.description }}</span>
      <button class="btn-allow" @click="handlePermission(true)">Allow</button>
      <button class="btn-deny" @click="handlePermission(false)">Deny</button>
    </div>
    <form class="input-bar" @submit.prevent="send">
      <input v-model="input" placeholder="Send a message to Savia..." :disabled="isStreaming" />
      <button type="submit" :disabled="isStreaming || !input.trim()">Send</button>
    </form>
    </div>
  </div>
</template>

<style scoped>
.chat-page { display: flex; height: 100%; }
.chat-page.has-sidebar { }
.chat-main { flex: 1; display: flex; flex-direction: column; min-width: 0; position: relative; }
.toggle-sessions {
  position: absolute; top: 8px; left: 8px; z-index: 10;
  background: var(--savia-surface-variant); border: none; padding: 4px 6px;
  border-radius: var(--savia-radius); cursor: pointer; display: flex; color: var(--savia-on-surface);
}
.toggle-sessions:hover { background: var(--savia-outline); color: white; }
.messages { flex: 1; overflow-y: auto; padding: 16px; padding-top: 36px; display: flex; flex-direction: column; gap: 8px; }
.empty-chat { flex: 1; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 8px; opacity: 0.6; }
.empty-logo { width: 64px; height: 64px; opacity: 0.5; }
.empty-title { font-size: 18px; font-weight: 600; }
.empty-hint { font-size: 13px; color: var(--savia-on-surface-variant); }
.msg { display: flex; } .msg.user { justify-content: flex-end; } .msg.assistant { justify-content: flex-start; }
.bubble { max-width: 70%; padding: 10px 14px; border-radius: var(--savia-radius-lg); font-size: 14px; line-height: 1.5; }
.msg.user .bubble { background: var(--savia-user-bubble); color: white; }
.msg.assistant .bubble { background: var(--savia-assistant-bubble); color: var(--savia-on-surface); }
.bubble-content :deep(p) { margin: 0 0 4px; } .bubble-content :deep(p:last-child) { margin: 0; }
.bubble-content :deep(strong) { font-weight: 600; }
.bubble-content :deep(code) { background: rgba(0,0,0,0.1); padding: 1px 4px; border-radius: 3px; font-size: 12px; }
.bubble-content :deep(pre) { background: rgba(0,0,0,0.1); padding: 8px; border-radius: var(--savia-radius); overflow-x: auto; }
.bubble-content :deep(ul), .bubble-content :deep(ol) { margin: 4px 0; padding-left: 18px; }
.bubble-time { font-size: 10px; opacity: 0.6; display: block; text-align: right; margin-top: 4px; }
.tool-indicator { font-size: 12px; color: var(--savia-on-surface-variant); padding: 4px 16px; font-style: italic; }
.permission-bar { display: flex; align-items: center; gap: 8px; padding: 8px 16px; background: var(--savia-warning); font-size: 13px; border-radius: var(--savia-radius); margin: 0 16px; }
.permission-bar span { flex: 1; } .btn-allow, .btn-deny { padding: 4px 12px; border-radius: 4px; font-size: 12px; color: white; }
.btn-allow { background: #155724; } .btn-deny { background: var(--savia-error); }
.input-bar { display: flex; gap: 8px; padding: 16px; background: var(--savia-surface); border-top: 1px solid var(--savia-surface-variant); }
.input-bar input { flex: 1; padding: 10px 14px; border: 1px solid var(--savia-outline); border-radius: var(--savia-radius); font-size: 14px; background: var(--savia-background); color: var(--savia-on-surface); }
.input-bar button { padding: 10px 20px; background: var(--savia-primary); color: white; border-radius: var(--savia-radius); font-size: 14px; font-weight: 600; }
.input-bar button:disabled { opacity: 0.5; cursor: not-allowed; }
.typing-indicator { display: flex; gap: 4px; padding: 4px 0; align-items: center; }
.dot { width: 8px; height: 8px; border-radius: 50%; background: var(--savia-primary); animation: bounce 1.4s infinite ease-in-out both; }
.dot:nth-child(1) { animation-delay: -0.32s; } .dot:nth-child(2) { animation-delay: -0.16s; }
@keyframes bounce { 0%, 80%, 100% { transform: scale(0.4); opacity: 0.4; } 40% { transform: scale(1); opacity: 1; } }
@media (max-width: 767px) { .bubble { max-width: 88%; } .messages { padding: 8px; } .input-bar { padding: 8px; } }
</style>
