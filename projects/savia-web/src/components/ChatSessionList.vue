<script setup lang="ts">
import { Plus, Trash2, MessageSquare } from 'lucide-vue-next'
import { useChatStore } from '../stores/chat'

const store = useChatStore()

function formatDate(ts: number) {
  if (!ts) return ''
  const d = new Date(ts)
  const now = new Date()
  if (d.toDateString() === now.toDateString()) return d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
  return d.toLocaleDateString([], { month: 'short', day: 'numeric' })
}
</script>

<template>
  <div class="session-list">
    <button class="new-chat-btn" @click="store.newSession()">
      <Plus :size="14" /> New Chat
    </button>
    <div class="sessions">
      <div
        v-for="s in store.sessions" :key="s.id"
        class="session-item" :class="{ active: s.id === store.sessionId }"
        @click="store.switchSession(s.id)"
      >
        <MessageSquare :size="14" class="session-icon" />
        <div class="session-info">
          <span class="session-title">{{ s.title || 'New chat' }}</span>
          <span class="session-meta">{{ formatDate(s.lastMessageAt) }} · {{ s.messageCount }} msgs</span>
        </div>
        <button
          v-if="s.id !== store.sessionId"
          class="delete-btn"
          @click.stop="store.deleteSession(s.id)"
          title="Delete"
        >
          <Trash2 :size="12" />
        </button>
      </div>
      <div v-if="!store.sessions.length" class="empty">No sessions yet</div>
    </div>
  </div>
</template>

<style scoped>
.session-list { display: flex; flex-direction: column; height: 100%; width: 260px; min-width: 260px; background: var(--savia-surface); border-right: 1px solid var(--savia-surface-variant); }
.new-chat-btn {
  display: flex; align-items: center; gap: 6px; margin: 10px; padding: 8px 14px;
  background: var(--savia-primary); color: white; border: none; border-radius: var(--savia-radius);
  cursor: pointer; font-size: 13px; font-family: inherit; font-weight: 500;
}
.new-chat-btn:hover { opacity: 0.9; }
.sessions { flex: 1; overflow-y: auto; padding: 0 6px; }
.session-item {
  display: flex; align-items: center; gap: 8px; padding: 8px 10px;
  border-radius: var(--savia-radius); cursor: pointer; font-size: 13px;
  margin-bottom: 2px;
}
.session-item:hover { background: var(--savia-surface-variant); }
.session-item.active { background: var(--savia-primary-container); font-weight: 500; }
.session-icon { flex-shrink: 0; color: var(--savia-outline); }
.session-info { flex: 1; min-width: 0; }
.session-title { display: block; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.session-meta { display: block; font-size: 10px; color: var(--savia-outline); }
.delete-btn {
  background: none; border: none; cursor: pointer; color: var(--savia-outline);
  padding: 2px; display: flex; opacity: 0; transition: opacity 0.2s;
}
.session-item:hover .delete-btn { opacity: 1; }
.delete-btn:hover { color: var(--savia-error); }
.empty { padding: 16px; text-align: center; color: var(--savia-outline); font-size: 12px; }
</style>
