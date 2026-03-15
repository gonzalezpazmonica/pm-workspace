import { defineStore } from 'pinia'
import { ref, watch } from 'vue'
import { useBridge } from '../composables/useBridge'
import { useProjectStore } from './project'
import type { DashboardData } from '../types/bridge'

export const useDashboardStore = defineStore('dashboard', () => {
  const { get } = useBridge()
  const data = ref<DashboardData | null>(null)
  const loading = ref(false)
  const error = ref<string | null>(null)

  async function load() {
    const projectStore = useProjectStore()
    loading.value = true
    error.value = null
    const raw = await get<Record<string, unknown>>(`/dashboard?project=${projectStore.selectedId}`)
    if (raw) {
      // Bridge returns greeting inside user.greeting — flatten it
      const greeting = (raw.user as Record<string, string>)?.greeting ?? raw.greeting as string ?? ''
      data.value = { ...raw, greeting } as unknown as DashboardData
    } else {
      error.value = 'Failed to load dashboard. Check Bridge connection.'
    }
    loading.value = false
  }

  function selectProject(projectId: string) {
    if (data.value) data.value.selectedProjectId = projectId
  }

  const projectStore = useProjectStore()
  watch(() => projectStore.selectedId, () => { load() })

  return { data, loading, error, load, selectProject }
})
