import { ref, computed, watch } from 'vue'
import { defineStore } from 'pinia'
import { useBridge } from '../composables/useBridge'
import { useProjectStore } from './project'

export interface SpecItem {
  id: string
  title: string
  state: string
  assigned_to: string
  pbis: PbiItem[]
}

export interface PbiItem {
  id: string
  title: string
  state: string
  type: string
  priority: string
  assigned_to: string
  estimated_hours: number
  tasks: TaskItem[]
}

export interface TaskItem {
  id: string
  title: string
  state: string
  type: string
  assigned_to: string
  estimated_hours: number
  remaining_hours: number
}

export interface BacklogFilters {
  showSpecs: boolean
  showPbis: boolean
  showTasks: boolean
  states: string[]
  assignee: string // '' = all, '@handle' = specific
}

type ViewMode = 'tree' | 'kanban'
const STORAGE_PREFIX = 'savia:backlog:'

function loadPersisted<T>(key: string, fallback: T): T {
  try {
    const v = localStorage.getItem(STORAGE_PREFIX + key)
    return v ? JSON.parse(v) : fallback
  } catch { return fallback }
}

function persist(key: string, value: unknown) {
  try { localStorage.setItem(STORAGE_PREFIX + key, JSON.stringify(value)) } catch {}
}

export const useBacklogStore = defineStore('backlog', () => {
  const { get } = useBridge()
  const specs = ref<SpecItem[]>([])
  const loading = ref(false)
  const viewMode = ref<ViewMode>(loadPersisted('viewMode', 'tree'))
  const selectedItemId = ref<string | null>(loadPersisted('selectedId', null))
  const selectedItemType = ref<'spec' | 'pbi' | null>(loadPersisted('selectedType', null))
  const expandedItems = ref<Set<string>>(new Set(loadPersisted<string[]>('expanded', [])))
  const filters = ref<BacklogFilters>(loadPersisted('filters', {
    showSpecs: true, showPbis: true, showTasks: true,
    states: [], assignee: '',
  }))
  let nextPbiNum = 100
  let nextTaskSeq = 100

  // Persistence watchers
  watch(viewMode, v => persist('viewMode', v))
  watch(selectedItemId, v => persist('selectedId', v))
  watch(selectedItemType, v => persist('selectedType', v))
  watch(expandedItems, v => persist('expanded', [...v]), { deep: true })
  watch(filters, v => persist('filters', v), { deep: true })

  const allPbis = computed(() => specs.value.flatMap(s => s.pbis))

  const allAssignees = computed(() => {
    const set = new Set<string>()
    for (const pbi of allPbis.value) {
      if (pbi.assigned_to) set.add(pbi.assigned_to)
      for (const t of pbi.tasks) if (t.assigned_to) set.add(t.assigned_to)
    }
    return [...set].sort()
  })

  const activeFilterCount = computed(() => {
    let c = 0
    if (!filters.value.showSpecs) c++
    if (!filters.value.showPbis) c++
    if (!filters.value.showTasks) c++
    if (filters.value.states.length > 0) c++
    if (filters.value.assignee) c++
    return c
  })

  function matchesFilters(state: string, assignee: string): boolean {
    const f = filters.value
    if (f.states.length > 0 && !f.states.includes(state)) return false
    if (f.assignee && assignee !== f.assignee) return false
    return true
  }

  // Filtered view for tree
  const filteredSpecs = computed(() => {
    const f = filters.value
    return specs.value
      .filter(s => f.showSpecs || s.pbis.some(p => matchesFilters(p.state, p.assigned_to)))
      .map(s => ({
        ...s,
        pbis: f.showPbis
          ? s.pbis.filter(p => matchesFilters(p.state, p.assigned_to)).map(p => ({
              ...p,
              tasks: f.showTasks ? p.tasks.filter(t => matchesFilters(t.state, t.assigned_to)) : [],
            }))
          : [],
      }))
      .filter(s => f.showSpecs || s.pbis.length > 0)
  })

  // Filtered PBIs for kanban
  const filteredPbisByState = computed(() => {
    const map: Record<string, PbiItem[]> = {}
    for (const col of columns) map[col] = []
    for (const pbi of allPbis.value) {
      if (!matchesFilters(pbi.state, pbi.assigned_to)) continue
      const col = map[pbi.state] ?? map['New']
      col.push(pbi)
    }
    return map
  })

  const selectedSpec = computed(() =>
    selectedItemType.value === 'spec'
      ? specs.value.find(s => s.id === selectedItemId.value) ?? null : null
  )

  const selectedPbi = computed(() => {
    if (selectedItemType.value !== 'pbi') return null
    for (const spec of specs.value) {
      const pbi = spec.pbis.find(p => p.id === selectedItemId.value)
      if (pbi) return pbi
    }
    return null
  })

  const columns = ['New', 'Active', 'Resolved', 'Closed']

  function toggleExpand(id: string) {
    if (expandedItems.value.has(id)) expandedItems.value.delete(id)
    else expandedItems.value.add(id)
  }

  function selectSpec(id: string) { selectedItemId.value = id; selectedItemType.value = 'spec' }
  function selectPbi(id: string | null) { selectedItemId.value = id; selectedItemType.value = id ? 'pbi' : null }
  function setViewMode(mode: ViewMode) { viewMode.value = mode }

  function setFilter(patch: Partial<BacklogFilters>) { Object.assign(filters.value, patch) }
  function clearFilters() {
    filters.value = { showSpecs: true, showPbis: true, showTasks: true, states: [], assignee: '' }
  }

  async function load() {
    loading.value = true
    try {
      const projectStore = useProjectStore()
      const data = await get<{ pbis: PbiItem[] }>(`/backlog?project=${projectStore.selectedId}`)
      const fetched = data?.pbis ?? []
      specs.value = groupPbisIntoSpecs(fetched.length > 0 ? fetched : mockPbis())
      for (const s of specs.value) expandedItems.value.add(s.id)
    } catch {
      specs.value = groupPbisIntoSpecs(mockPbis())
      for (const s of specs.value) expandedItems.value.add(s.id)
    } finally { loading.value = false }
  }

  function movePbi(id: string, st: string) { for (const s of specs.value) { const p = s.pbis.find(x => x.id === id); if (p) { p.state = st; return } } }
  function updatePbi(id: string, f: Partial<PbiItem>) { for (const s of specs.value) { const p = s.pbis.find(x => x.id === id); if (p) { Object.assign(p, f); return } } }
  function updateSpec(id: string, f: Partial<SpecItem>) { const s = specs.value.find(x => x.id === id); if (s) Object.assign(s, f) }

  function addPbi(title: string, type = 'User Story', specId?: string) {
    const id = `PBI-${String(nextPbiNum++).padStart(3, '0')}`
    const pbi: PbiItem = { id, title, state: 'New', type, priority: '3-Medium', assigned_to: '', estimated_hours: 0, tasks: [] }
    const target = specId ? specs.value.find(s => s.id === specId) : specs.value[0]
    if (target) target.pbis.push(pbi)
    selectedItemId.value = id; selectedItemType.value = 'pbi'
    return id
  }

  function addTask(pbiId: string) {
    for (const s of specs.value) {
      const pbi = s.pbis.find(p => p.id === pbiId); if (!pbi) continue
      const num = pbiId.split('-')[1] || '000'
      pbi.tasks.push({ id: `TASK-${num}-${String(nextTaskSeq++).padStart(3, '0')}`, title: 'New task', state: 'New', type: 'Development', assigned_to: '', estimated_hours: 0, remaining_hours: 0 })
      return
    }
  }

  function addSpec(title: string) {
    const id = `SPEC-${String(specs.value.length + 1).padStart(3, '0')}`
    specs.value.push({ id, title, state: 'Draft', assigned_to: '', pbis: [] })
    selectedItemId.value = id; selectedItemType.value = 'spec'
    return id
  }

  const projectStore = useProjectStore()
  watch(() => projectStore.selectedId, () => { load() })

  return {
    specs, loading, viewMode, selectedItemId, selectedItemType, filters,
    selectedSpec, selectedPbi, allPbis, allAssignees, expandedItems, columns,
    filteredSpecs, filteredPbisByState, activeFilterCount,
    load, selectSpec, selectPbi, setViewMode, toggleExpand, movePbi,
    updatePbi, updateSpec, addPbi, addTask, addSpec, setFilter, clearFilters,
  }
})

function groupPbisIntoSpecs(pbis: PbiItem[]): SpecItem[] {
  const byState: Record<string, PbiItem[]> = {}
  for (const p of pbis) {
    const key = p.state === 'Closed' ? 'Completed' : 'Current Sprint'
    if (!byState[key]) byState[key] = []
    byState[key].push(p)
  }
  return Object.entries(byState).map(([name, items], i) => ({
    id: `SPEC-${String(i + 1).padStart(3, '0')}`, title: name,
    state: name === 'Completed' ? 'Done' : 'In Progress', assigned_to: '', pbis: items,
  }))
}

function mockPbis(): PbiItem[] {
  return [
    { id: 'PBI-001', title: 'User authentication flow', state: 'Active', type: 'User Story', priority: '2-High', assigned_to: '@alice', estimated_hours: 16, tasks: [
      { id: 'TASK-001-001', title: 'Login endpoint', state: 'Done', type: 'Development', assigned_to: '@alice', estimated_hours: 8, remaining_hours: 0 },
      { id: 'TASK-001-002', title: 'JWT middleware', state: 'Active', type: 'Development', assigned_to: '@bob', estimated_hours: 8, remaining_hours: 4 },
    ] },
    { id: 'PBI-002', title: 'Dashboard charts', state: 'New', type: 'User Story', priority: '3-Medium', assigned_to: '@bob', estimated_hours: 12, tasks: [] },
    { id: 'PBI-003', title: 'Fix login timeout', state: 'Closed', type: 'Bug', priority: '1-Critical', assigned_to: '@alice', estimated_hours: 4, tasks: [] },
  ]
}
