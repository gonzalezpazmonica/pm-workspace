import { ref, computed } from 'vue'
import { defineStore } from 'pinia'

export interface BranchStatus {
  unpushed_commits: number
  has_pr: boolean
  merged: boolean
  dirty_files: number
}

export interface ActiveSession {
  pid: number
  name: string
  project_path: string
  branch: string
  recent_actions: string[]
  agent_count: number
  shield_active: boolean
  is_nido: boolean
  nido_name: string
  branch_status: BranchStatus
}

export const useSessionsStore = defineStore('sessions', () => {
  const sessions = ref<ActiveSession[]>([])
  const loading = ref(false)

  const sessionCount = computed(() => sessions.value.length)
  const protectedCount = computed(() => sessions.value.filter((s) => s.shield_active).length)
  const totalAgents = computed(() => sessions.value.reduce((sum, s) => sum + s.agent_count, 0))

  function branchLabel(s: ActiveSession): string {
    const parts: string[] = []
    if (s.branch_status.dirty_files > 0) parts.push(`${s.branch_status.dirty_files} modified`)
    if (s.branch_status.unpushed_commits > 0) parts.push(`${s.branch_status.unpushed_commits} unpushed`)
    if (s.branch_status.has_pr) parts.push('PR')
    if (s.branch_status.merged) parts.push('merged')
    return parts.join(' · ')
  }

  async function loadSessions() {
    loading.value = true
    try {
      const { invoke } = await import('@tauri-apps/api/core')
      sessions.value = await invoke<ActiveSession[]>('get_active_sessions')
    } catch {
      sessions.value = []
    } finally {
      loading.value = false
    }
  }

  return { sessions, loading, sessionCount, protectedCount, totalAgents, branchLabel, loadSessions }
})
