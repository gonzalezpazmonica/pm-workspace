import { defineStore } from 'pinia'
import { ref } from 'vue'

export const useReportsStore = defineStore('reports', () => {
  const activeTab = ref('sprint')
  const selectedProject = ref<string | null>(null)

  function setTab(tab: string) { activeTab.value = tab }
  function setProject(id: string) { selectedProject.value = id }

  return { activeTab, selectedProject, setTab, setProject }
})
