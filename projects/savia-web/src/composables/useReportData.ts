import { ref, type Ref } from 'vue'
import { useBridge } from './useBridge'
import { useDashboardStore } from '../stores/dashboard'
import type { ReportResponse } from '../types/reports'

export function useReportData<T>(endpoint: string) {
  const data: Ref<T | null> = ref(null)
  const loading = ref(false)
  const error = ref<string | null>(null)

  async function load(extraParams = '') {
    const { get } = useBridge()
    const dashboard = useDashboardStore()
    const projectId = dashboard.data?.selectedProjectId || ''
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

  return { data, loading, error, load }
}
