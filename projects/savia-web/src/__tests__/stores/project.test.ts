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
    parentId: null,
    children: [],
    confidentiality: null,
  },
  {
    id: 'savia-web',
    name: 'savia-web',
    path: 'projects/savia-web',
    hasClaude: true,
    hasBacklog: true,
    health: 'healthy',
    parentId: null,
    children: [],
    confidentiality: null,
  },
]

const projectsWithSubprojects: ProjectInfo[] = [
  ...sampleProjects,
  {
    id: 'trazabios_main',
    name: 'TrazaBios',
    path: 'projects/trazabios_main',
    hasClaude: true,
    hasBacklog: false,
    health: 'healthy',
    parentId: null,
    children: ['trazabios', 'trazabios-vass', 'trazabios-pm'],
    confidentiality: null,
  },
  {
    id: 'trazabios',
    name: 'trazabios',
    path: 'projects/trazabios_main/trazabios',
    hasClaude: false,
    hasBacklog: true,
    health: 'healthy',
    parentId: 'trazabios_main',
    children: [],
    confidentiality: 'N4-SHARED',
  },
  {
    id: 'trazabios-vass',
    name: 'trazabios-vass',
    path: 'projects/trazabios_main/trazabios-vass',
    hasClaude: false,
    hasBacklog: false,
    health: 'healthy',
    parentId: 'trazabios_main',
    children: [],
    confidentiality: 'N4-VASS',
  },
  {
    id: 'trazabios-pm',
    name: 'trazabios-pm',
    path: 'projects/trazabios_main/trazabios-pm',
    hasClaude: false,
    hasBacklog: false,
    health: 'healthy',
    parentId: 'trazabios_main',
    children: [],
    confidentiality: 'N4b-PM',
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

    it('redirects umbrella selection to first child on load', async () => {
      localStorage.setItem('savia:selectedProject', 'trazabios_main')
      mockGet.mockResolvedValueOnce(projectsWithSubprojects)
      const store = useProjectStore()
      await store.load()
      expect(store.selectedId).toBe('trazabios')
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

  describe('topLevel computed', () => {
    it('returns only projects with parentId === null', async () => {
      mockGet.mockResolvedValueOnce(projectsWithSubprojects)
      const store = useProjectStore()
      await store.load()
      const ids = store.topLevel.map(p => p.id)
      expect(ids).toEqual(['_workspace', 'savia-web', 'trazabios_main'])
    })

    it('returns all projects when none have parents', async () => {
      mockGet.mockResolvedValueOnce(sampleProjects)
      const store = useProjectStore()
      await store.load()
      expect(store.topLevel.length).toBe(sampleProjects.length)
    })
  })

  describe('childrenOf', () => {
    it('returns children of an umbrella project', async () => {
      mockGet.mockResolvedValueOnce(projectsWithSubprojects)
      const store = useProjectStore()
      await store.load()
      const children = store.childrenOf('trazabios_main')
      expect(children.map(c => c.id)).toEqual(['trazabios', 'trazabios-vass', 'trazabios-pm'])
    })

    it('returns empty array for standalone projects', async () => {
      mockGet.mockResolvedValueOnce(projectsWithSubprojects)
      const store = useProjectStore()
      await store.load()
      expect(store.childrenOf('savia-web')).toEqual([])
    })
  })

  describe('parentOf', () => {
    it('returns parent for a child project', async () => {
      mockGet.mockResolvedValueOnce(projectsWithSubprojects)
      const store = useProjectStore()
      await store.load()
      const parent = store.parentOf('trazabios-pm')
      expect(parent?.id).toBe('trazabios_main')
      expect(parent?.name).toBe('TrazaBios')
    })

    it('returns undefined for top-level projects', async () => {
      mockGet.mockResolvedValueOnce(projectsWithSubprojects)
      const store = useProjectStore()
      await store.load()
      expect(store.parentOf('savia-web')).toBeUndefined()
    })
  })

  describe('effective computed', () => {
    it('returns the selected project for standalone', async () => {
      mockGet.mockResolvedValueOnce(projectsWithSubprojects)
      const store = useProjectStore()
      await store.load()
      store.select('savia-web')
      expect(store.effective?.id).toBe('savia-web')
    })

    it('returns first child for umbrella selection', async () => {
      mockGet.mockResolvedValueOnce(projectsWithSubprojects)
      const store = useProjectStore()
      store.projects = projectsWithSubprojects
      store.select('trazabios_main')
      expect(store.effective?.id).toBe('trazabios')
    })

    it('returns selected child directly', async () => {
      mockGet.mockResolvedValueOnce(projectsWithSubprojects)
      const store = useProjectStore()
      await store.load()
      store.select('trazabios-vass')
      expect(store.effective?.id).toBe('trazabios-vass')
      expect(store.effective?.confidentiality).toBe('N4-VASS')
    })
  })
})
