import { describe, it, expect, vi, beforeEach } from 'vitest'
import { setActivePinia, createPinia } from 'pinia'

vi.mock('../../composables/useBridge', () => ({
  useBridge: () => ({ get: vi.fn().mockResolvedValue(null) }),
}))

const { useBacklogStore } = await import('../../stores/backlog')

describe('backlog filters', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    localStorage.clear()
  })

  it('starts with all types visible and no state/assignee filter', async () => {
    const store = useBacklogStore()
    expect(store.filters.showSpecs).toBe(true)
    expect(store.filters.showPbis).toBe(true)
    expect(store.filters.showTasks).toBe(true)
    expect(store.filters.states).toEqual([])
    expect(store.filters.assignee).toBe('')
  })

  it('setFilter updates filter state', async () => {
    const store = useBacklogStore()
    store.setFilter({ showTasks: false })
    expect(store.filters.showTasks).toBe(false)
    expect(store.filters.showPbis).toBe(true)
  })

  it('clearFilters resets all to defaults', async () => {
    const store = useBacklogStore()
    store.setFilter({ showPbis: false, assignee: '@alice', states: ['Active'] })
    store.clearFilters()
    expect(store.filters.showPbis).toBe(true)
    expect(store.filters.assignee).toBe('')
    expect(store.filters.states).toEqual([])
  })

  it('activeFilterCount reflects number of active filters', async () => {
    const store = useBacklogStore()
    expect(store.activeFilterCount).toBe(0)
    store.setFilter({ showTasks: false })
    expect(store.activeFilterCount).toBe(1)
    store.setFilter({ assignee: '@alice' })
    expect(store.activeFilterCount).toBe(2)
  })

  it('filteredSpecs hides PBIs when showPbis is false', async () => {
    const store = useBacklogStore()
    await store.load()
    store.setFilter({ showPbis: false })
    for (const spec of store.filteredSpecs) {
      expect(spec.pbis).toEqual([])
    }
  })

  it('filteredSpecs hides tasks when showTasks is false', async () => {
    const store = useBacklogStore()
    await store.load()
    store.setFilter({ showTasks: false })
    for (const spec of store.filteredSpecs) {
      for (const pbi of spec.pbis) {
        expect(pbi.tasks).toEqual([])
      }
    }
  })

  it('state filter reduces visible PBIs', async () => {
    const store = useBacklogStore()
    await store.load()
    const totalBefore = store.allPbis.length
    store.setFilter({ states: ['Active'] })
    const totalAfter = store.filteredSpecs.flatMap(s => s.pbis).length
    expect(totalAfter).toBeLessThan(totalBefore)
    expect(totalAfter).toBeGreaterThan(0)
  })

  it('assignee filter shows only matching items', async () => {
    const store = useBacklogStore()
    await store.load()
    store.setFilter({ assignee: '@alice' })
    for (const spec of store.filteredSpecs) {
      for (const pbi of spec.pbis) {
        expect(pbi.assigned_to).toBe('@alice')
      }
    }
  })

  it('allAssignees extracts unique handles', async () => {
    const store = useBacklogStore()
    await store.load()
    expect(store.allAssignees).toContain('@alice')
    expect(store.allAssignees).toContain('@bob')
  })

  it('persists viewMode to localStorage', async () => {
    const store = useBacklogStore()
    store.setViewMode('kanban')
    await new Promise(r => setTimeout(r, 10))
    expect(localStorage.getItem('savia:backlog:viewMode')).toBe('"kanban"')
  })

  it('persists filters to localStorage', async () => {
    const store = useBacklogStore()
    store.setFilter({ assignee: '@bob' })
    await new Promise(r => setTimeout(r, 10))
    const stored = JSON.parse(localStorage.getItem('savia:backlog:filters') || '{}')
    expect(stored.assignee).toBe('@bob')
  })
})
