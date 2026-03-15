import { describe, it, expect, vi, beforeEach } from 'vitest'
import { setActivePinia, createPinia } from 'pinia'
import type { DashboardData } from '../../types/bridge'

const mockGet = vi.fn()
vi.mock('../../composables/useBridge', () => ({
  useBridge: () => ({ get: mockGet }),
}))

const { useDashboardStore } = await import('../../stores/dashboard')

const sampleDashboard: DashboardData = {
  greeting: 'Good morning, Alice',
  projects: [
    { id: 'p1', name: 'Project Alpha', team: 'Team A', currentSprint: 'Sprint 1', health: 'green' },
  ],
  selectedProjectId: 'p1',
  sprint: { name: 'Sprint 1', progress: 60, completedPoints: 12, totalPoints: 20, blockedItems: 1, daysRemaining: 3, velocity: 18 },
  myTasks: [],
  recentActivity: ['Merged PR #42'],
  blockedItems: 1,
  hoursToday: 4.5,
}

describe('useDashboardStore', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    mockGet.mockReset()
  })

  it('starts with null data, false loading, null error', () => {
    const store = useDashboardStore()
    expect(store.data).toBeNull()
    expect(store.loading).toBe(false)
    expect(store.error).toBeNull()
  })

  describe('load', () => {
    it('sets data on successful fetch', async () => {
      mockGet.mockResolvedValueOnce(sampleDashboard)
      const store = useDashboardStore()
      await store.load()
      expect(store.data).toEqual(sampleDashboard)
      expect(store.error).toBeNull()
    })

    it('sets error message when fetch returns null', async () => {
      mockGet.mockResolvedValueOnce(null)
      const store = useDashboardStore()
      await store.load()
      expect(store.data).toBeNull()
      expect(store.error).toContain('Bridge')
    })

    it('sets loading true during fetch, false after', async () => {
      mockGet.mockResolvedValueOnce(sampleDashboard)
      const store = useDashboardStore()
      const promise = store.load()
      expect(store.loading).toBe(true)
      await promise
      expect(store.loading).toBe(false)
    })

    it('fetches /dashboard endpoint with project param', async () => {
      mockGet.mockResolvedValueOnce(sampleDashboard)
      const store = useDashboardStore()
      await store.load()
      expect(mockGet).toHaveBeenCalledWith(expect.stringContaining('/dashboard?project='))
    })

    it('clears previous error on reload', async () => {
      mockGet.mockResolvedValueOnce(null)
      const store = useDashboardStore()
      await store.load()
      expect(store.error).toBeTruthy()
      mockGet.mockResolvedValueOnce(sampleDashboard)
      await store.load()
      expect(store.error).toBeNull()
    })
  })

  describe('selectProject', () => {
    it('updates selectedProjectId when data is loaded', async () => {
      mockGet.mockResolvedValueOnce(sampleDashboard)
      const store = useDashboardStore()
      await store.load()
      store.selectProject('p2')
      expect(store.data?.selectedProjectId).toBe('p2')
    })

    it('does nothing when data is null', () => {
      const store = useDashboardStore()
      expect(() => store.selectProject('p2')).not.toThrow()
    })
  })
})
