<script setup lang="ts">
import { onMounted, onUnmounted, ref } from 'vue'
import { GitBranch, FolderGit2, Trash2, ChevronDown } from 'lucide-vue-next'
import { useGitStore } from '@/stores/git'
import { useI18n } from '@/locales/i18n'

const git = useGitStore()
const { t } = useI18n()
const contextBranch = ref<string | null>(null)
const contextPos = ref({ x: 0, y: 0 })

let pollTimer: ReturnType<typeof setInterval> | null = null
async function refreshAll() { await git.loadProjects(); await git.loadBranches(); await git.loadNidos() }
onMounted(async () => { await refreshAll(); pollTimer = setInterval(refreshAll, 30_000) })
onUnmounted(() => { if (pollTimer) clearInterval(pollTimer) })

function onRightClick(e: MouseEvent, branchName: string, merged: boolean) {
  if (!merged) return
  e.preventDefault()
  contextBranch.value = branchName
  contextPos.value = { x: e.clientX, y: e.clientY }
}

function closeContext() { contextBranch.value = null }

async function handleDelete() {
  if (contextBranch.value) {
    await git.deleteBranch(contextBranch.value)
    contextBranch.value = null
  }
}

const groupLabels: Record<string, string> = {
  main: 'main', feat: 'feat/', fix: 'fix/', agent: 'agent/', nido: 'nido/', other: t('git.other'),
}
</script>

<template>
  <div class="git-tab" @click="closeContext">
    <!-- Project selector -->
    <div v-if="git.projects.length" class="glass-card git-tab__selector">
      <label class="git-tab__label">{{ t('git.project') }}</label>
      <select
        :value="git.selectedProject"
        class="git-tab__select"
        @change="git.selectProject(($event.target as HTMLSelectElement).value)"
      >
        <option v-for="p in git.projects" :key="p.path" :value="p.path">
          {{ p.name }} — {{ p.branch }} {{ p.has_changes ? '●' : '' }}
        </option>
      </select>
    </div>

    <!-- Current branch -->
    <div class="glass-card git-tab__current">
      <GitBranch :size="14" />
      <span class="git-tab__branch">{{ git.currentBranch || 'detached' }}</span>
    </div>

    <!-- Local branches -->
    <div class="glass-card git-tab__section">
      <span class="git-tab__label">{{ t('git.localBranches') }}</span>
      <div class="git-tab__list">
        <template v-for="group in git.groupedLocal" :key="group.group">
          <div class="git-tab__group-header">
            <ChevronDown :size="10" />
            {{ groupLabels[group.group] || group.group }}
            <span class="git-tab__group-count">{{ group.branches.length }}</span>
          </div>
          <div
            v-for="b in group.branches"
            :key="b.name"
            class="git-tab__item"
            :class="{ 'git-tab__item--current': b.current, 'git-tab__item--merged': b.merged }"
            @contextmenu="onRightClick($event, b.name, b.merged)"
          >
            <GitBranch :size="11" />
            <span class="git-tab__name">{{ b.name }}</span>
            <span v-if="b.current" class="git-tab__tag git-tab__tag--head">HEAD</span>
            <span v-if="b.pending_files > 0" class="git-tab__pending">({{ b.pending_files }})</span>
            <span v-if="b.merged" class="git-tab__tag git-tab__tag--merged">{{ t('git.merged') }}</span>
          </div>
        </template>
        <div v-if="!git.groupedLocal.length" class="git-tab__empty">{{ t('git.noBranches') }}</div>
      </div>
    </div>

    <!-- Remote branches -->
    <div v-if="git.groupedRemote.length" class="glass-card git-tab__section">
      <span class="git-tab__label">{{ t('git.remoteBranches') }}</span>
      <div class="git-tab__list">
        <template v-for="group in git.groupedRemote" :key="group.group">
          <div class="git-tab__group-header">
            <ChevronDown :size="10" />
            {{ groupLabels[group.group] || group.group }}
            <span class="git-tab__group-count">{{ group.branches.length }}</span>
          </div>
          <div
            v-for="b in group.branches"
            :key="b.name"
            class="git-tab__item"
            :class="{ 'git-tab__item--merged': b.merged }"
          >
            <GitBranch :size="11" />
            <span class="git-tab__name">{{ b.name.replace('remotes/origin/', '') }}</span>
            <span v-if="b.merged" class="git-tab__tag git-tab__tag--merged">{{ t('git.merged') }}</span>
          </div>
        </template>
      </div>
    </div>

    <!-- Nidos -->
    <div class="glass-card git-tab__section">
      <span class="git-tab__label"><FolderGit2 :size="12" /> {{ t('git.nidos') }}</span>
      <div class="git-tab__list">
        <div v-if="!git.nidos.length" class="git-tab__empty">{{ t('git.noNidos') }}</div>
        <div v-for="n in git.nidos" :key="n.name" class="git-tab__item">
          <span class="git-tab__name">{{ n.name }}</span>
          <span class="git-tab__tag">{{ n.branch }}</span>
        </div>
      </div>
    </div>

    <!-- Context menu -->
    <div
      v-if="contextBranch"
      class="git-tab__context"
      :style="{ left: contextPos.x + 'px', top: contextPos.y + 'px' }"
    >
      <button class="git-tab__context-btn" @click="handleDelete">
        <Trash2 :size="12" /> {{ t('git.deleteBranch') }}
      </button>
    </div>
  </div>
</template>

<style scoped>
.git-tab { display: flex; flex-direction: column; gap: var(--space-3); padding: var(--space-4); overflow-y: auto; flex: 1; }
.git-tab__current { display: flex; align-items: center; gap: var(--space-2); padding: var(--space-2) var(--space-3); font-size: 13px; font-weight: 700; color: var(--savia-primary); }
.git-tab__branch { font-family: monospace; }
.git-tab__section { padding: var(--space-3); }
.git-tab__label { font-size: 10px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.05em; color: var(--savia-on-surface-variant); display: flex; align-items: center; gap: var(--space-1); margin-bottom: var(--space-2); }
.git-tab__list { max-height: 280px; overflow-y: auto; }
.git-tab__group-header { font-size: 10px; font-weight: 700; color: var(--savia-primary); padding: 4px 0 2px; display: flex; align-items: center; gap: 4px; letter-spacing: 0.02em; }
.git-tab__group-count { font-size: 9px; background: var(--savia-surface-variant); border-radius: 8px; padding: 0 5px; color: var(--savia-on-surface-variant); }
.git-tab__item { display: flex; align-items: center; gap: var(--space-2); padding: 3px 0 3px 12px; font-size: 11px; border-bottom: 1px solid var(--savia-glass-border); color: var(--savia-on-surface); }
.git-tab__item--current { font-weight: 700; color: var(--savia-primary); }
.git-tab__item--merged { opacity: 0.45; }
.git-tab__name { flex: 1; font-family: monospace; font-size: 11px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.git-tab__tag { font-size: 9px; padding: 1px 6px; border-radius: 8px; background: var(--savia-surface-variant); color: var(--savia-on-surface-variant); font-weight: 600; white-space: nowrap; }
.git-tab__tag--head { background: var(--savia-primary); color: #fff; }
.git-tab__tag--merged { background: var(--savia-surface-variant); color: var(--savia-on-surface-variant); font-style: italic; }
.git-tab__pending { font-size: 10px; color: var(--savia-warning); font-weight: 700; white-space: nowrap; }
.git-tab__empty { font-size: 11px; color: var(--savia-on-surface-variant); text-align: center; padding: var(--space-3); }
.git-tab__selector { display: flex; align-items: center; gap: var(--space-2); padding: var(--space-2) var(--space-3); }
.git-tab__select { flex: 1; appearance: none; background: var(--savia-surface-variant); border: 1px solid var(--savia-glass-border); border-radius: var(--savia-radius); padding: var(--space-1) var(--space-3); font-size: 11px; color: var(--savia-on-surface); font-family: monospace; }
.git-tab__context { position: fixed; z-index: 100; background: var(--savia-surface); border: 1px solid var(--savia-glass-border); border-radius: var(--savia-radius); box-shadow: var(--savia-shadow-lg); padding: 4px; }
.git-tab__context-btn { display: flex; align-items: center; gap: 6px; padding: 6px 12px; font-size: 11px; border: none; background: none; color: var(--savia-error); cursor: pointer; border-radius: var(--savia-radius); width: 100%; font-family: inherit; }
.git-tab__context-btn:hover { background: var(--savia-error-container); }
</style>
