import { ref, watch } from 'vue'
import { defineStore } from 'pinia'
import { useProjectStore } from './project'

export interface Workflow {
  id: string
  name: string
  active: boolean
  triggerType: string
  lastExecution: string
}

export interface Execution {
  id: string
  workflowName: string
  status: 'success' | 'error' | 'running'
  startedAt: string
  duration: string
}

export interface N8nConnection {
  url: string
  apiKey: string
  connected: boolean
}

export const useIntegrationsStore = defineStore('integrations', () => {
  const workflows = ref<Workflow[]>([])
  const executions = ref<Execution[]>([])
  const connection = ref<N8nConnection>({ url: '', apiKey: '', connected: false })
  const loading = ref(false)

  async function load() {
    loading.value = true
    try {
      workflows.value = mockWorkflows()
      executions.value = mockExecutions()
    } finally { loading.value = false }
  }

  function saveConnection(url: string, key: string) {
    connection.value = { url, apiKey: key, connected: url.length > 0 }
  }

  const projectStore = useProjectStore()
  watch(() => projectStore.selectedId, () => { load() })

  return { workflows, executions, connection, loading, load, saveConnection }
})

function mockWorkflows(): Workflow[] {
  return [
    { id: 'wf-1', name: 'Sprint notifications', active: true, triggerType: 'cron', lastExecution: '2026-03-14 09:00' },
    { id: 'wf-2', name: 'Daily report', active: true, triggerType: 'cron', lastExecution: '2026-03-14 08:00' },
    { id: 'wf-3', name: 'PR webhook', active: false, triggerType: 'webhook', lastExecution: '2026-03-13 16:30' },
  ]
}

function mockExecutions(): Execution[] {
  return [
    { id: 'ex-1', workflowName: 'Sprint notifications', status: 'success', startedAt: '2026-03-14 09:00', duration: '2s' },
    { id: 'ex-2', workflowName: 'Daily report', status: 'success', startedAt: '2026-03-14 08:00', duration: '5s' },
    { id: 'ex-3', workflowName: 'PR webhook', status: 'error', startedAt: '2026-03-13 16:30', duration: '1s' },
  ]
}
