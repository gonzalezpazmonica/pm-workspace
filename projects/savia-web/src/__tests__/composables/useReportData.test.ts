import { describe, it, expect, vi, beforeEach } from 'vitest'
import type { DashboardData } from '../../types/bridge'
import { setActivePinia, createPinia } from 'pinia'

// Mock useBridge before importing the composable
const mockGet = vi.fn()
vi.mock('../../composables/useBridge', () => ({
  useBridge: () => ({ get: mockGet }),
}))

const { useReportData } = await import('../../composables/useReportData')
const { useDashboardStore } = await import('../../stores/dashboard')

describe('useReportData', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    mockGet.mockReset()
  })

  it('starts with null data, false loading, null error', () => {
    const { data, loading, error } = useReportData('/reports/sprint')
    expect(data.value).toBeNull()
    expect(loading.value).toBe(false)
    expect(error.value).toBeNull()
  })

  it('sets loading true during fetch then false after', async () => {
    mockGet.mockResolvedValueOnce({ data: { sprints: [] } })
    const { loading, load } = useReportData('/reports/sprint')
    const promise = load()
    expect(loading.value).toBe(true)
    await promise
    expect(loading.value).toBe(false)
  })

  it('populates data on successful response', async () => {
    const payload = { sprints: [{ name: 'Sprint 1', planned: 20, completed: 18 }] }
    mockGet.mockResolvedValueOnce({ data: payload })
    const { data, load } = useReportData('/reports/sprint')
    await load()
    expect(data.value).toEqual(payload)
  })

  it('sets error when response has no data', async () => {
    mockGet.mockResolvedValueOnce(null)
    const { error, load } = useReportData('/reports/sprint')
    await load()
    expect(error.value).toBe('Failed to load report data')
  })

  it('sets error when result.data is falsy', async () => {
    mockGet.mockResolvedValueOnce({ data: null })
    const { error, data, load } = useReportData('/reports/sprint')
    await load()
    expect(error.value).toBe('Failed to load report data')
    expect(data.value).toBeNull()
  })

  it('builds url with project param from dashboard store', async () => {
    const dashboard = useDashboardStore()
    dashboard.data = { selectedProjectId: 'proj-42' } as unknown as DashboardData
    mockGet.mockResolvedValueOnce({ data: {} })
    const { load } = useReportData('/reports/sprint')
    await load()
    const calledUrl: string = mockGet.mock.calls[0][0]
    expect(calledUrl).toContain('project=proj-42')
  })

  it('appends extraParams to url', async () => {
    mockGet.mockResolvedValueOnce({ data: {} })
    const { load } = useReportData('/reports/sprint')
    await load('&limit=5')
    const calledUrl: string = mockGet.mock.calls[0][0]
    expect(calledUrl).toContain('limit=5')
  })

  it('uses & separator when endpoint already has query string', async () => {
    mockGet.mockResolvedValueOnce({ data: {} })
    const { load } = useReportData('/reports/sprint?foo=bar')
    await load()
    const calledUrl: string = mockGet.mock.calls[0][0]
    expect(calledUrl).toContain('foo=bar&project=')
  })

  it('clears error on subsequent successful load', async () => {
    mockGet.mockResolvedValueOnce(null)
    const { error, load } = useReportData('/reports/sprint')
    await load()
    expect(error.value).toBeTruthy()
    mockGet.mockResolvedValueOnce({ data: { sprints: [] } })
    await load()
    expect(error.value).toBeNull()
  })
})
