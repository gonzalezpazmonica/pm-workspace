import { defineStore } from 'pinia'
import { ref } from 'vue'
import { useBridge } from '../composables/useBridge'
import type { DashboardData } from '../types/bridge'

export const useDashboardStore = defineStore('dashboard', () => {
  const data = ref<DashboardData | null>(null)
  const loading = ref(false)
  const error = ref<string | null>(null)

  async function load() {
    const { get } = useBridge()
    loading.value = true
    error.value = null
    const result = await get<DashboardData>('/dashboard')
    if (result) {
      data.value = result
    } else {
      error.value = 'Failed to load dashboard. Check Bridge connection.'
    }
    loading.value = false
  }

  function selectProject(projectId: string) {
    if (data.value) data.value.selectedProjectId = projectId
  }

  return { data, loading, error, load, selectProject }
})
