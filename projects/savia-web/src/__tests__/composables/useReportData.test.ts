import { describe, it, expect, vi, beforeEach } from 'vitest'
import { setActivePinia, createPinia } from 'pinia'

const mockGet = vi.fn()
vi.mock('../../composables/useBridge', () => ({
  useBridge: () => ({ get: mockGet }),
}))

const { useReportData } = await import('../../composables/useReportData')
const { useProjectStore } = await import('../../stores/project')

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

  it('builds url with project param from project store', async () => {
    const projectStore = useProjectStore()
    projectStore.select('proyecto-alpha')
    mockGet.mockResolvedValueOnce({ data: {} })
    const { load } = useReportData('/reports/sprint')
    await load()
    const calledUrl: string = mockGet.mock.calls[0][0]
    expect(calledUrl).toContain('project=proyecto-alpha')
  })

  it('appends extraParams to url', async () => {
    mockGet.mockResolvedValueOnce({ data: {} })
    const { load } = useReportData('/reports/sprint')
    await load('&limit=5')
    const calledUrl: string = mockGet.mock.calls[0][0]
    expect(calledUrl).toContain('limit=5')
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
