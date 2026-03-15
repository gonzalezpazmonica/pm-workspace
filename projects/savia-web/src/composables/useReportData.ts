import { ref, watch, type Ref } from 'vue'
import { useBridge } from './useBridge'
import { useProjectStore } from '../stores/project'
import type { ReportResponse } from '../types/reports'

export function useReportData<T>(endpoint: string) {
  const data: Ref<T | null> = ref(null)
  const loading = ref(false)
  const error = ref<string | null>(null)

  async function load(extraParams = '') {
    const { get } = useBridge()
    const projectStore = useProjectStore()
    const projectId = projectStore.selectedId
    loading.value = true
    error.value = null

    const sep = endpoint.includes('?') ? '&' : '?'
    const url = `${endpoint}${sep}project=${encodeURIComponent(projectId)}${extraParams}`
    const result = await get<ReportResponse<T>>(url)

    if (result?.data) {
      data.value = result.data
    } else {
      error.value = 'Failed to load report data'
    }
    loading.value = false
  }

  // Reload when project changes
  const projectStore = useProjectStore()
  watch(() => projectStore.selectedId, () => { load() })

  return { data, loading, error, load }
}
