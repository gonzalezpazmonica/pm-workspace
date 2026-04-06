<script setup lang="ts">
import { onMounted, onUnmounted } from 'vue'
import { RefreshCw, Bot, Shield, Terminal, Search, FileEdit } from 'lucide-vue-next'
import { useActivityStore } from '@/stores/activity'
import { useI18n } from '@/locales/i18n'
import type { ActivityFilter } from '@/stores/activity'

const store = useActivityStore()
const { t } = useI18n()

const filters: { key: string; value: ActivityFilter; icon: any }[] = [
  { key: 'activity.all', value: 'all', icon: null },
  { key: 'activity.tools', value: 'tool', icon: Terminal },
  { key: 'activity.agents', value: 'agent', icon: Bot },
  { key: 'activity.shield', value: 'shield', icon: Shield },
]

function kindColor(kind: string): string {
  switch (kind) {
    case 'agent': return 'var(--savia-primary)'
    case 'shield': return 'var(--savia-error)'
    case 'edit': return 'var(--savia-warning)'
    case 'search': return 'var(--savia-primary-light)'
    default: return 'var(--savia-on-surface-variant)'
  }
}

function kindIcon(kind: string) {
  switch (kind) {
    case 'agent': return Bot
    case 'shield': return Shield
    case 'edit': return FileEdit
    case 'search': return Search
    default: return Terminal
  }
}

let pollTimer: ReturnType<typeof setInterval> | null = null

onMounted(() => {
  store.loadActivity()
  pollTimer = setInterval(() => store.loadActivity(), 10000)
})

onUnmounted(() => {
  if (pollTimer) clearInterval(pollTimer)
})
</script>

<template>
  <div class="activity">
    <div class="activity__bar">
      <button
        v-for="f in filters" :key="f.value"
        class="activity__pill"
        :class="{ 'activity__pill--active': store.filter === f.value }"
        @click="store.filter = f.value"
      >{{ t(f.key) }}</button>
      <button class="activity__refresh" :title="t('activity.refresh')" @click="store.loadActivity()">
        <RefreshCw :size="12" />
      </button>
    </div>

    <!-- Active agents -->
    <div v-if="store.agents.length" class="glass-card activity__agents">
      <span class="activity__section-label">{{ t('activity.runningAgents') }}</span>
      <div v-for="a in store.agents" :key="a.id" class="activity__agent">
        <Bot :size="11" />
        <span class="activity__agent-type">{{ a.agent_type }}</span>
        <span class="activity__agent-event" :class="a.event === 'start' ? 'activity__agent-event--running' : ''">
          {{ a.event === 'start' ? t('activity.running') : t('activity.completed') }}
        </span>
        <span class="activity__agent-ts">{{ a.ts.substring(11, 19) }}</span>
      </div>
    </div>

    <!-- Feed -->
    <div class="glass-card activity__feed">
      <div v-if="!store.filtered.length" class="activity__empty">{{ t('activity.empty') }}</div>
      <div v-for="(entry, i) in store.filtered" :key="i" class="activity__item">
        <component :is="kindIcon(entry.kind)" :size="11" :style="{ color: kindColor(entry.kind) }" />
        <span class="activity__ts">{{ entry.ts }}</span>
        <span class="activity__msg">{{ entry.message }}</span>
      </div>
    </div>
  </div>
</template>

<style scoped>
.activity { display: flex; flex-direction: column; gap: var(--space-3); padding: var(--space-4); flex: 1; min-height: 0; }
.activity__bar { display: flex; gap: var(--space-1); align-items: center; }
.activity__pill { padding: 3px 10px; border: 1px solid var(--savia-outline); border-radius: 12px; background: transparent; color: var(--savia-on-surface-variant); font-size: 11px; font-weight: 600; cursor: pointer; font-family: inherit; }
.activity__pill--active { background: var(--savia-primary); color: #fff; border-color: var(--savia-primary); }
.activity__refresh { margin-left: auto; background: none; border: none; color: var(--savia-on-surface-variant); cursor: pointer; padding: 4px; border-radius: var(--savia-radius); }
.activity__refresh:hover { color: var(--savia-primary); }
.activity__agents { padding: var(--space-2) var(--space-3); }
.activity__section-label { font-size: 10px; font-weight: 700; color: var(--savia-on-surface-variant); display: block; margin-bottom: var(--space-1); }
.activity__agent { display: flex; align-items: center; gap: var(--space-2); padding: 2px 0; font-size: 11px; }
.activity__agent-type { font-weight: 600; color: var(--savia-primary); }
.activity__agent-event { font-size: 9px; padding: 1px 5px; border-radius: 6px; background: var(--savia-surface-variant); }
.activity__agent-event--running { background: var(--savia-success-container); color: var(--savia-success); }
.activity__agent-ts { margin-left: auto; font-family: monospace; font-size: 10px; color: var(--savia-on-surface-variant); }
.activity__feed { flex: 1; overflow-y: auto; padding: var(--space-2); }
.activity__item { display: flex; align-items: flex-start; gap: var(--space-2); padding: 3px 0; font-size: 11px; border-bottom: 1px solid var(--savia-glass-border); min-height: 24px; }
.activity__ts { font-family: monospace; font-size: 10px; color: var(--savia-on-surface-variant); white-space: nowrap; flex-shrink: 0; }
.activity__msg { color: var(--savia-on-surface); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.activity__empty { text-align: center; color: var(--savia-on-surface-variant); font-size: 12px; padding: var(--space-6); }
</style>
