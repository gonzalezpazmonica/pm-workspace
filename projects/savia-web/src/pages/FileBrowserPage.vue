<script setup lang="ts">
import { useI18n } from 'vue-i18n'
const { t } = useI18n()
import { ref, computed, onMounted } from 'vue'
import { EyeOff, Eye } from 'lucide-vue-next'
import { useBridge } from '../composables/useBridge'
import LoadingSpinner from '../components/LoadingSpinner.vue'
import EmptyState from '../components/EmptyState.vue'
import FileBreadcrumb from '../components/files/FileBreadcrumb.vue'
import FileListItem from '../components/files/FileListItem.vue'
import type { FileEntry } from '../components/files/FileListItem.vue'
import FileViewer from '../components/files/FileViewer.vue'

const { get } = useBridge()
const currentPath = ref('.')
const breadcrumb = ref<string[]>(['Savia'])
const entries = ref<FileEntry[]>([])
const fileContent = ref<string | null>(null)
const fileLanguage = ref<string>('')
const fileName = ref<string>('')
const loading = ref(false)
const showDotfiles = ref(false)

const visibleEntries = computed(() =>
  showDotfiles.value ? entries.value : entries.value.filter(e => !e.name.startsWith('.'))
)

async function loadDir(path: string, crumb?: string[]) {
  currentPath.value = path
  fileContent.value = null
  loading.value = true
  try {
    const data = await get<{ entries: FileEntry[]; breadcrumb?: string[] }>(`/files?path=${encodeURIComponent(path)}`)
    entries.value = data?.entries || []
    if (crumb) breadcrumb.value = crumb
    else if (data?.breadcrumb) breadcrumb.value = data.breadcrumb
  } catch { entries.value = [] }
  finally { loading.value = false }
}

async function openEntry(entry: FileEntry) {
  const path = currentPath.value === '.' ? entry.name : `${currentPath.value}/${entry.name}`
  if (entry.type === 'directory') {
    await loadDir(path, [...breadcrumb.value, entry.name])
  } else {
    fileName.value = entry.name
    try {
      const data = await get<{ content: string; language?: string }>(`/files/content?path=${encodeURIComponent(path)}`)
      fileContent.value = data?.content ?? 'Error loading file'
      fileLanguage.value = data?.language ?? ''
    } catch { fileContent.value = 'Error loading file' }
  }
}

function onNavigate(segments: string[]) {
  if (segments.length <= 1) { loadDir('.', ['Savia']); return }
  const path = segments.slice(1).join('/')
  loadDir(path, segments)
}

async function saveFile(content: string) {
  const path = currentPath.value === '.' ? fileName.value : `${currentPath.value}/${fileName.value}`
  const { post } = useBridge()
  await post('/files/content', { path, content })
  fileContent.value = content
}

onMounted(() => loadDir('.'))
</script>

<template>
  <div class="files-page">
    <div class="files-toolbar">
      <FileBreadcrumb :path="breadcrumb" @navigate="onNavigate" />
      <button class="toolbar-btn" @click="showDotfiles = !showDotfiles">
        <component :is="showDotfiles ? EyeOff : Eye" :size="15" />
        {{ showDotfiles ? t('common.hideDotfiles') : t('common.showDotfiles') }}
      </button>
    </div>

    <LoadingSpinner v-if="loading" />

    <div v-else class="files-body" :class="{ 'has-viewer': fileContent !== null }">
      <div class="files-list-panel">
        <EmptyState v-if="!visibleEntries.length" :title="t('files.empty')" />
        <ul v-else class="file-list">
          <FileListItem
            v-for="e in visibleEntries"
            :key="e.name"
            :entry="e"
            @open="openEntry"
          />
        </ul>
      </div>

      <div v-if="fileContent !== null" class="files-viewer-panel">
        <button class="close-viewer" @click="fileContent = null">{{ t('common.close') }}</button>
        <FileViewer :content="fileContent" :language="fileLanguage" :filename="fileName" :editable="fileName.endsWith('.md')" @save="saveFile" />
      </div>
    </div>
  </div>
</template>

<style scoped>
.files-page { display: flex; flex-direction: column; height: 100%; gap: 4px; }
.files-toolbar {
  display: flex; align-items: center; justify-content: space-between;
  padding: 6px 0; border-bottom: 1px solid var(--savia-surface-variant);
}
.toolbar-btn {
  display: flex; align-items: center; gap: 6px;
  padding: 4px 10px; border-radius: var(--savia-radius);
  background: var(--savia-surface-variant); border: none;
  font-size: 12px; cursor: pointer; font-family: inherit; color: var(--savia-on-surface);
}
.toolbar-btn:hover { background: var(--savia-outline); color: white; }
.files-body { flex: 1; overflow: hidden; }
.files-body.has-viewer { display: grid; grid-template-columns: 320px 1fr; gap: 12px; }
.files-list-panel { overflow-y: auto; }
.file-list { list-style: none; background: var(--savia-surface); border-radius: var(--savia-radius-lg); box-shadow: var(--savia-shadow); overflow: hidden; }
.files-viewer-panel { overflow: hidden; display: flex; flex-direction: column; gap: 6px; }
.close-viewer {
  align-self: flex-start; padding: 3px 10px;
  background: var(--savia-surface-variant); border: none; border-radius: var(--savia-radius);
  font-size: 12px; cursor: pointer; font-family: inherit;
}
</style>
