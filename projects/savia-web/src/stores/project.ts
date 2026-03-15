import { ref, computed } from 'vue'
import { defineStore } from 'pinia'
import { useBridge } from '../composables/useBridge'
import type { ProjectInfo } from '../types/bridge'

const STORAGE_KEY = 'savia:selectedProject'

export const useProjectStore = defineStore('project', () => {
  const { get } = useBridge()
  const projects = ref<ProjectInfo[]>([])
  const selectedId = ref(localStorage.getItem(STORAGE_KEY) ?? '_workspace')

  const selected = computed(() =>
    projects.value.find(p => p.id === selectedId.value)
  )

  async function load() {
    const data = await get<ProjectInfo[]>('/projects')
    projects.value = data ?? []
  }

  function select(id: string) {
    selectedId.value = id
    localStorage.setItem(STORAGE_KEY, id)
  }

  return { projects, selectedId, selected, load, select }
})
