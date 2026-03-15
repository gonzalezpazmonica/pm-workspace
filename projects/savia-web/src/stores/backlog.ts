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

type ViewMode = 'tree' | 'kanban'

export const useBacklogStore = defineStore('backlog', () => {
  const { get } = useBridge()
  const specs = ref<SpecItem[]>([])
  const loading = ref(false)
  const viewMode = ref<ViewMode>('tree')
  const selectedItemId = ref<string | null>(null)
  const selectedItemType = ref<'spec' | 'pbi' | null>(null)
  const expandedItems = ref<Set<string>>(new Set())
  let nextPbiNum = 100
  let nextTaskSeq = 100

  // Flat list of all PBIs (for kanban)
  const allPbis = computed(() => specs.value.flatMap(s => s.pbis))

  const selectedSpec = computed(() =>
    selectedItemType.value === 'spec'
      ? specs.value.find(s => s.id === selectedItemId.value) ?? null
      : null
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

  const pbisByState = computed(() => {
    const map: Record<string, PbiItem[]> = {}
    for (const col of columns) map[col] = []
    for (const pbi of allPbis.value) {
      const col = map[pbi.state] ?? map['New']
      col.push(pbi)
    }
    return map
  })

  function toggleExpand(id: string) {
    if (expandedItems.value.has(id)) expandedItems.value.delete(id)
    else expandedItems.value.add(id)
  }

  function selectSpec(id: string) {
    selectedItemId.value = id
    selectedItemType.value = 'spec'
  }

  function selectPbi(id: string | null) {
    selectedItemId.value = id
    selectedItemType.value = id ? 'pbi' : null
  }

  function setViewMode(mode: ViewMode) { viewMode.value = mode }

  async function load() {
    loading.value = true
    try {
      const projectStore = useProjectStore()
      const projectId = projectStore.selectedId
      const data = await get<{ pbis: PbiItem[] }>(`/backlog?project=${projectId}`)
      const fetched = data?.pbis ?? []
      const pbis = fetched.length > 0 ? fetched : mockPbis()
      specs.value = groupPbisIntoSpecs(pbis)
      // Auto-expand all specs on load
      for (const s of specs.value) expandedItems.value.add(s.id)
    } catch {
      specs.value = groupPbisIntoSpecs(mockPbis())
      for (const s of specs.value) expandedItems.value.add(s.id)
    } finally { loading.value = false }
  }

  function movePbi(id: string, newState: string) {
    for (const spec of specs.value) {
      const pbi = spec.pbis.find(p => p.id === id)
      if (pbi) { pbi.state = newState; return }
    }
  }

  function updatePbi(id: string, fields: Partial<PbiItem>) {
    for (const spec of specs.value) {
      const pbi = spec.pbis.find(p => p.id === id)
      if (pbi) { Object.assign(pbi, fields); return }
    }
  }

  function updateSpec(id: string, fields: Partial<SpecItem>) {
    const spec = specs.value.find(s => s.id === id)
    if (spec) Object.assign(spec, fields)
  }

  function addPbi(title: string, type: string = 'User Story', specId?: string) {
    const id = `PBI-${String(nextPbiNum++).padStart(3, '0')}`
    const pbi: PbiItem = {
      id, title, state: 'New', type, priority: '3-Medium',
      assigned_to: '', estimated_hours: 0, tasks: [],
    }
    const target = specId ? specs.value.find(s => s.id === specId) : specs.value[0]
    if (target) target.pbis.push(pbi)
    selectedItemId.value = id
    selectedItemType.value = 'pbi'
    return id
  }

  function addTask(pbiId: string) {
    for (const spec of specs.value) {
      const pbi = spec.pbis.find(p => p.id === pbiId)
      if (!pbi) continue
      const pbiNum = pbiId.split('-')[1] || '000'
      const seq = String(nextTaskSeq++).padStart(3, '0')
      pbi.tasks.push({
        id: `TASK-${pbiNum}-${seq}`, title: 'New task', state: 'New',
        type: 'Development', assigned_to: '', estimated_hours: 0, remaining_hours: 0,
      })
      return
    }
  }

  function addSpec(title: string) {
    const num = specs.value.length + 1
    const id = `SPEC-${String(num).padStart(3, '0')}`
    specs.value.push({ id, title, state: 'Draft', assigned_to: '', pbis: [] })
    selectedItemId.value = id
    selectedItemType.value = 'spec'
    return id
  }

  const projectStore = useProjectStore()
  watch(() => projectStore.selectedId, () => { load() })

  return {
    specs, loading, viewMode, selectedItemId, selectedItemType,
    selectedSpec, selectedPbi, allPbis, expandedItems, columns, pbisByState,
    load, selectSpec, selectPbi, setViewMode, toggleExpand, movePbi,
    updatePbi, updateSpec, addPbi, addTask, addSpec,
  }
})

function groupPbisIntoSpecs(pbis: PbiItem[]): SpecItem[] {
  // Group by sprint or create a default spec
  const byState: Record<string, PbiItem[]> = {}
  for (const p of pbis) {
    const key = p.state === 'Closed' ? 'Completed' : 'Current Sprint'
    if (!byState[key]) byState[key] = []
    byState[key].push(p)
  }
  return Object.entries(byState).map(([name, items], i) => ({
    id: `SPEC-${String(i + 1).padStart(3, '0')}`,
    title: name,
    state: name === 'Completed' ? 'Done' : 'In Progress',
    assigned_to: '',
    pbis: items,
  }))
}

function mockPbis(): PbiItem[] {
  return [
    {
      id: 'PBI-001', title: 'User authentication flow', state: 'Active',
      type: 'User Story', priority: '2-High', assigned_to: '@alice',
      estimated_hours: 16, tasks: [
        { id: 'TASK-001-001', title: 'Login endpoint', state: 'Done', type: 'Development', assigned_to: '@alice', estimated_hours: 8, remaining_hours: 0 },
        { id: 'TASK-001-002', title: 'JWT middleware', state: 'Active', type: 'Development', assigned_to: '@bob', estimated_hours: 8, remaining_hours: 4 },
      ],
    },
    {
      id: 'PBI-002', title: 'Dashboard charts', state: 'New',
      type: 'User Story', priority: '3-Medium', assigned_to: '@bob',
      estimated_hours: 12, tasks: [],
    },
    {
      id: 'PBI-003', title: 'Fix login timeout', state: 'Closed',
      type: 'Bug', priority: '1-Critical', assigned_to: '@alice',
      estimated_hours: 4, tasks: [],
    },
  ]
}
