<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useBridge } from '../composables/useBridge'
import LoadingSpinner from '../components/LoadingSpinner.vue'
import EmptyState from '../components/EmptyState.vue'

const { get } = useBridge()
const currentPath = ref('.')
const entries = ref<{ name: string; type: string; size: number }[]>([])
const fileContent = ref<string | null>(null)
const loading = ref(false)

async function loadDir(path: string) {
  currentPath.value = path; fileContent.value = null; loading.value = true
  try {
    const data = await get<{ entries: typeof entries.value }>(`/files?path=${encodeURIComponent(path)}`)
    entries.value = data?.entries || []
  } catch { entries.value = [] }
  finally { loading.value = false }
}

async function openEntry(entry: { name: string; type: string }) {
  const path = currentPath.value === '.' ? entry.name : `${currentPath.value}/${entry.name}`
  if (entry.type === 'directory') { await loadDir(path) }
  else {
    try {
      const data = await get<{ content: string }>(`/files/content?path=${encodeURIComponent(path)}`)
      fileContent.value = data?.content ?? 'Error loading file'
    } catch { fileContent.value = 'Error loading file' }
  }
}

function goUp() {
  const parts = currentPath.value.split('/')
  parts.pop()
  loadDir(parts.join('/') || '.')
}

onMounted(() => loadDir('.'))
</script>

<template>
  <div class="files-page">
    <div class="file-header">
      <h1>Files</h1>
      <button v-if="currentPath !== '.'" class="btn-back" @click="goUp">.. Up</button>
      <span class="path">{{ currentPath }}</span>
    </div>
    <LoadingSpinner v-if="loading" />
    <div v-else-if="fileContent" class="file-viewer">
      <button class="btn-back" @click="fileContent = null">Back to listing</button>
      <pre class="file-content">{{ fileContent }}</pre>
    </div>
    <EmptyState v-else-if="!entries.length" icon="📁" title="Empty directory" />
    <ul v-else class="file-list">
      <li v-for="e in entries" :key="e.name" class="file-item" @click="openEntry(e)">
        <span class="file-icon">{{ e.type === 'directory' ? '📁' : '📄' }}</span>
        <span class="file-name">{{ e.name }}</span>
        <span v-if="e.type !== 'directory'" class="file-size">{{ (e.size / 1024).toFixed(1) }}KB</span>
      </li>
    </ul>
  </div>
</template>

<style scoped>
.file-header { display: flex; align-items: center; gap: 12px; margin-bottom: 16px; }
h1 { font-size: 20px; }
.path { font-size: 13px; color: var(--savia-on-surface-variant); font-family: monospace; }
.btn-back { padding: 4px 12px; font-size: 13px; background: var(--savia-surface-variant); border-radius: var(--savia-radius); }
.file-list { list-style: none; background: var(--savia-surface); border-radius: var(--savia-radius-lg); box-shadow: var(--savia-shadow); overflow: hidden; }
.file-item { display: flex; align-items: center; gap: 8px; padding: 10px 14px; border-bottom: 1px solid var(--savia-surface-variant); cursor: pointer; font-size: 14px; }
.file-item:hover { background: var(--savia-surface-variant); }
.file-name { flex: 1; }
.file-size { font-size: 12px; color: var(--savia-outline); }
.file-content { padding: 16px; background: var(--savia-surface); border-radius: var(--savia-radius); font-size: 13px; overflow: auto; max-height: 60vh; white-space: pre-wrap; font-family: monospace; }
</style>
