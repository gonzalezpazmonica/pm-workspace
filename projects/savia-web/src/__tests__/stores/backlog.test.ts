import { describe, it, expect, vi, beforeEach } from 'vitest'
import { setActivePinia, createPinia } from 'pinia'

vi.mock('../../composables/useBridge', () => ({
  useBridge: () => ({ get: vi.fn().mockResolvedValue(null) }),
}))

const { useBacklogStore } = await import('../../stores/backlog')

describe('useBacklogStore', () => {
  beforeEach(() => setActivePinia(createPinia()))

  it('starts with empty specs and tree view', () => {
    const store = useBacklogStore()
    expect(store.specs).toEqual([])
    expect(store.viewMode).toBe('tree')
  })

  it('loads mock data grouped into specs', async () => {
    const store = useBacklogStore()
    await store.load()
    expect(store.specs.length).toBeGreaterThan(0)
    expect(store.allPbis.length).toBeGreaterThan(0)
    expect(store.loading).toBe(false)
  })

  it('selects a PBI', async () => {
    const store = useBacklogStore()
    await store.load()
    const pbiId = store.allPbis[0].id
    store.selectPbi(pbiId)
    expect(store.selectedPbi?.id).toBe(pbiId)
    expect(store.selectedItemType).toBe('pbi')
  })

  it('selects a Spec', async () => {
    const store = useBacklogStore()
    await store.load()
    store.selectSpec(store.specs[0].id)
    expect(store.selectedSpec?.id).toBe(store.specs[0].id)
    expect(store.selectedItemType).toBe('spec')
  })

  it('toggles expand state', () => {
    const store = useBacklogStore()
    store.toggleExpand('PBI-001')
    expect(store.expandedItems.has('PBI-001')).toBe(true)
    store.toggleExpand('PBI-001')
    expect(store.expandedItems.has('PBI-001')).toBe(false)
  })

  it('switches view mode', () => {
    const store = useBacklogStore()
    store.setViewMode('kanban')
    expect(store.viewMode).toBe('kanban')
  })

  it('moves PBI to new state', async () => {
    const store = useBacklogStore()
    await store.load()
    const pbi = store.allPbis.find(p => p.state === 'New')
    if (pbi) {
      store.movePbi(pbi.id, 'Active')
      expect(store.allPbis.find(p => p.id === pbi.id)?.state).toBe('Active')
    }
  })

  it('groups PBIs by state for kanban', async () => {
    const store = useBacklogStore()
    await store.load()
    const totalKanban = Object.values(store.pbisByState).flat().length
    expect(totalKanban).toBe(store.allPbis.length)
  })

  it('updates PBI fields', async () => {
    const store = useBacklogStore()
    await store.load()
    const pbi = store.allPbis[0]
    store.updatePbi(pbi.id, { title: 'Updated title', state: 'Resolved' })
    expect(store.allPbis.find(p => p.id === pbi.id)?.title).toBe('Updated title')
  })

  it('adds a new PBI to a spec', async () => {
    const store = useBacklogStore()
    await store.load()
    const before = store.allPbis.length
    const id = store.addPbi('New feature', 'User Story')
    expect(store.allPbis.length).toBe(before + 1)
    expect(id).toMatch(/^PBI-/)
    expect(store.selectedItemType).toBe('pbi')
  })

  it('adds a task to a PBI', async () => {
    const store = useBacklogStore()
    await store.load()
    const pbi = store.allPbis[0]
    const before = pbi.tasks.length
    store.addTask(pbi.id)
    expect(pbi.tasks.length).toBe(before + 1)
  })

  it('adds a new Spec', async () => {
    const store = useBacklogStore()
    await store.load()
    const before = store.specs.length
    store.addSpec('New spec')
    expect(store.specs.length).toBe(before + 1)
    expect(store.selectedItemType).toBe('spec')
  })
})
