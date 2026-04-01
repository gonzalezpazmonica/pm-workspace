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

  /** Top-level projects only (parentId === null). For rendering the selector root level. */
  const topLevel = computed(() =>
    projects.value.filter(p => p.parentId === null)
  )

  /** Get children of a given umbrella project. */
  function childrenOf(parentId: string): ProjectInfo[] {
    return projects.value.filter(p => p.parentId === parentId)
  }

  /** Find parent project for a given child. */
  function parentOf(childId: string): ProjectInfo | undefined {
    const child = projects.value.find(p => p.id === childId)
    if (!child?.parentId) return undefined
    return projects.value.find(p => p.id === child.parentId)
  }

  /**
   * The effective project for data queries.
   * - If selected is an umbrella (has children), use the first child.
   * - If selected is a leaf or standalone, use it directly.
   */
  const effective = computed(() => {
    const sel = selected.value
    if (!sel) return null
    if (sel.children.length > 0) {
      return projects.value.find(p => p.id === sel.children[0]) ?? sel
    }
    return sel
  })

  async function load() {
    const data = await get<ProjectInfo[]>('/projects')
    projects.value = data ?? []
    // If selectedId points to an umbrella, redirect to first child
    const sel = projects.value.find(p => p.id === selectedId.value)
    if (sel && sel.children.length > 0) {
      select(sel.children[0])
    }
  }

  function select(id: string) {
    selectedId.value = id
    localStorage.setItem(STORAGE_KEY, id)
  }

  return { projects, selectedId, selected, topLevel, childrenOf, parentOf, effective, load, select }
})
