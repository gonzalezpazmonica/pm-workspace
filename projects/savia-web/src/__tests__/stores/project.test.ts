import { describe, it, expect, vi, beforeEach } from 'vitest'
import { setActivePinia, createPinia } from 'pinia'
import type { ProjectInfo } from '../../types/bridge'

const mockGet = vi.fn()
vi.mock('../../composables/useBridge', () => ({
  useBridge: () => ({ get: mockGet }),
}))

const { useProjectStore } = await import('../../stores/project')

const sampleProjects: ProjectInfo[] = [
  {
    id: '_workspace',
    name: 'Savia (workspace)',
    path: '.',
    hasClaude: true,
    hasBacklog: false,
    health: 'healthy',
  },
  {
    id: 'savia-web',
    name: 'savia-web',
    path: 'projects/savia-web',
    hasClaude: true,
    hasBacklog: true,
    health: 'healthy',
  },
]

describe('useProjectStore', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    mockGet.mockReset()
    localStorage.clear()
  })

  it('starts with empty projects and _workspace selectedId', () => {
    const store = useProjectStore()
    expect(store.projects).toEqual([])
    expect(store.selectedId).toBe('_workspace')
  })

  it('reads selectedId from localStorage on init', () => {
    localStorage.setItem('savia:selectedProject', 'savia-web')
    const store = useProjectStore()
    expect(store.selectedId).toBe('savia-web')
  })

  describe('load', () => {
    it('fetches /projects and stores result', async () => {
      mockGet.mockResolvedValueOnce(sampleProjects)
      const store = useProjectStore()
      await store.load()
      expect(store.projects).toEqual(sampleProjects)
      expect(mockGet).toHaveBeenCalledWith('/projects')
    })

    it('keeps empty array when fetch returns null', async () => {
      mockGet.mockResolvedValueOnce(null)
      const store = useProjectStore()
      await store.load()
      expect(store.projects).toEqual([])
    })
  })

  describe('select', () => {
    it('updates selectedId and persists to localStorage', () => {
      const store = useProjectStore()
      store.select('savia-web')
      expect(store.selectedId).toBe('savia-web')
      expect(localStorage.getItem('savia:selectedProject')).toBe('savia-web')
    })
  })

  describe('selected computed', () => {
    it('returns the matching project', async () => {
      mockGet.mockResolvedValueOnce(sampleProjects)
      const store = useProjectStore()
      await store.load()
      store.select('savia-web')
      expect(store.selected?.id).toBe('savia-web')
      expect(store.selected?.name).toBe('savia-web')
    })

    it('returns undefined when selectedId not in projects', () => {
      const store = useProjectStore()
      store.select('nonexistent')
      expect(store.selected).toBeUndefined()
    })
  })
})
