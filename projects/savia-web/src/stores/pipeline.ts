import { ref, computed, watch } from 'vue'
import { defineStore } from 'pinia'
import { useProjectStore } from './project'

export interface PipelineRun {
  id: string
  name: string
  status: 'success' | 'failed' | 'running' | 'pending'
  trigger: string
  startedAt: string
  duration: string
  stages: PipelineStage[]
}

export interface PipelineStage {
  name: string
  status: 'success' | 'failed' | 'running' | 'pending' | 'skipped'
  duration: string
  log?: string
}

export const usePipelineStore = defineStore('pipeline', () => {
  const runs = ref<PipelineRun[]>([])
  const selectedRunId = ref<string | null>(null)
  const loading = ref(false)

  const selectedRun = computed(() =>
    runs.value.find(r => r.id === selectedRunId.value) ?? null
  )

  function selectRun(id: string | null) { selectedRunId.value = id }

  async function load() {
    loading.value = true
    try { runs.value = mockRuns() }
    finally { loading.value = false }
  }

  const projectStore = useProjectStore()
  watch(() => projectStore.selectedId, () => { load() })

  return { runs, selectedRunId, selectedRun, loading, load, selectRun }
})

function mockRuns(): PipelineRun[] {
  return [
    {
      id: 'run-1', name: 'CI/CD Pipeline', status: 'success', trigger: 'push',
      startedAt: '2026-03-14 10:30', duration: '3m 42s',
      stages: [
        { name: 'Build', status: 'success', duration: '1m 12s', log: 'Build completed' },
        { name: 'Test', status: 'success', duration: '1m 45s', log: '42 tests passed' },
        { name: 'Deploy', status: 'success', duration: '45s', log: 'Deployed to dev' },
      ],
    },
    {
      id: 'run-2', name: 'CI/CD Pipeline', status: 'failed', trigger: 'push',
      startedAt: '2026-03-14 09:15', duration: '2m 10s',
      stages: [
        { name: 'Build', status: 'success', duration: '1m 05s' },
        { name: 'Test', status: 'failed', duration: '1m 05s', log: '3 tests failed' },
        { name: 'Deploy', status: 'skipped', duration: '-' },
      ],
    },
    {
      id: 'run-3', name: 'Security Scan', status: 'success', trigger: 'schedule',
      startedAt: '2026-03-14 02:00', duration: '5m 20s',
      stages: [
        { name: 'SAST', status: 'success', duration: '3m 10s' },
        { name: 'Dependency Check', status: 'success', duration: '2m 10s' },
      ],
    },
  ]
}
