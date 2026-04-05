import { ref, computed } from 'vue'
import { defineStore } from 'pinia'

export interface BranchInfo {
  name: string
  current: boolean
  remote: boolean
  merged: boolean
  group: string
  pending_files: number
}

export interface GitProject {
  name: string
  path: string
  branch: string
  has_changes: boolean
}

export interface Nido {
  name: string
  branch: string
  path: string
}

export const useGitStore = defineStore('git', () => {
  const projects = ref<GitProject[]>([])
  const selectedProject = ref<string | null>(null)
  const branches = ref<BranchInfo[]>([])
  const nidos = ref<Nido[]>([])

  const currentProject = computed(() =>
    projects.value.find((p) => p.path === selectedProject.value) ?? projects.value[0],
  )

  const currentBranch = computed(() =>
    branches.value.find((b) => b.current)?.name ?? currentProject.value?.branch ?? '',
  )

  const groupOrder = ['main', 'feat', 'fix', 'agent', 'nido', 'other']

  const localBranches = computed(() => branches.value.filter((b) => !b.remote))
  const remoteBranches = computed(() => branches.value.filter((b) => b.remote))

  function groupBy(list: BranchInfo[]) {
    const groups: Record<string, BranchInfo[]> = {}
    for (const b of list) {
      if (!groups[b.group]) groups[b.group] = []
      groups[b.group].push(b)
    }
    return groupOrder
      .filter((g) => groups[g]?.length)
      .map((g) => ({ group: g, branches: groups[g] }))
  }

  const groupedLocal = computed(() => groupBy(localBranches.value))
  const groupedRemote = computed(() => groupBy(remoteBranches.value))

  async function loadProjects() {
    try {
      const { invoke } = await import('@tauri-apps/api/core')
      projects.value = await invoke<GitProject[]>('get_git_projects')
    } catch {
      projects.value = []
    }
    if (projects.value.length && !selectedProject.value) {
      selectedProject.value = projects.value[0].path
    }
  }

  async function loadBranches() {
    try {
      const { invoke } = await import('@tauri-apps/api/core')
      branches.value = await invoke<BranchInfo[]>('get_branches', {
        projectPath: selectedProject.value,
      })
    } catch {
      branches.value = []
    }
  }

  async function loadNidos() {
    try {
      const { invoke } = await import('@tauri-apps/api/core')
      const raw = await invoke<string>('get_nidos')
      nidos.value = raw
        .split('\n')
        .filter(Boolean)
        .map((l) => {
          const [name, branch] = l.split('=')
          return { name, branch: branch || '', path: `~/.savia/nidos/${name}` }
        })
    } catch {
      nidos.value = []
    }
  }

  async function selectProject(path: string) {
    selectedProject.value = path
    await loadBranches()
  }

  async function deleteBranch(branch: string) {
    try {
      const { invoke } = await import('@tauri-apps/api/core')
      await invoke<string>('delete_branch', {
        branch,
        projectPath: selectedProject.value,
      })
      await loadBranches()
    } catch {
      // Branch deletion failed — will show stale data until next refresh
    }
  }

  return {
    projects, selectedProject, branches, nidos, currentProject,
    currentBranch, groupedLocal, groupedRemote, loadProjects, loadBranches,
    loadNidos, selectProject, deleteBranch,
  }
})
