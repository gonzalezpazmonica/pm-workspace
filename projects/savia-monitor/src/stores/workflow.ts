import { ref, computed } from 'vue'
import { defineStore } from 'pinia'

export interface HealthScore {
  total: number
  shield_score: number
  git_score: number
  agent_score: number
  profile_score: number
  breakdown: string[]
}

export const useWorkflowStore = defineStore('workflow', () => {
  const ollamaUp = ref(false)
  const ollamaModels = ref<string[]>([])
  const currentTask = ref('')
  const health = ref<HealthScore | null>(null)

  const modelCount = computed(() => ollamaModels.value.length)
  const healthScore = computed(() => health.value?.total ?? 0)

  function updateFromHealth(data: { ollama_up?: boolean; ollama_models?: string[] }) {
    if (data.ollama_up !== undefined) ollamaUp.value = data.ollama_up
    if (data.ollama_models) ollamaModels.value = data.ollama_models
  }

  async function loadAll() {
    try {
      const { invoke } = await import('@tauri-apps/api/core')
      const [h, task, shieldHealth] = await Promise.all([
        invoke<HealthScore>('get_health_score'),
        invoke<string>('get_current_task'),
        invoke<any>('get_shield_health'),
      ])
      health.value = h
      currentTask.value = task
      updateFromHealth(shieldHealth)
    } catch {
      // Outside Tauri
    }
  }

  return { ollamaUp, ollamaModels, modelCount, currentTask, health, healthScore, updateFromHealth, loadAll }
})
