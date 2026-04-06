import { ref, computed } from 'vue'
import { defineStore } from 'pinia'

export interface ActivityEntry {
  ts: string
  kind: string
  message: string
  project: string
}

export interface AgentEntry {
  ts: string
  event: string
  agent_type: string
  id: string
}

export type ActivityFilter = 'all' | 'tool' | 'agent' | 'shield' | 'error'

export const useActivityStore = defineStore('activity', () => {
  const entries = ref<ActivityEntry[]>([])
  const agents = ref<AgentEntry[]>([])
  const filter = ref<ActivityFilter>('all')

  const filtered = computed(() => {
    if (filter.value === 'all') return entries.value
    return entries.value.filter((e) => e.kind === filter.value)
  })

  const unreadCount = computed(() => entries.value.filter((e) => e.kind === 'shield' || e.kind === 'error').length)

  async function loadActivity() {
    try {
      const { invoke } = await import('@tauri-apps/api/core')
      entries.value = await invoke<ActivityEntry[]>('get_recent_activity', { limit: 50 })
      agents.value = await invoke<AgentEntry[]>('get_agent_activity')
    } catch {
      entries.value = []
      agents.value = []
    }
  }

  return { entries, agents, filter, filtered, unreadCount, loadActivity }
})
