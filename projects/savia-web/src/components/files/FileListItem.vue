<script setup lang="ts">
import { computed } from 'vue'
import { Folder, FileText, FileCode, Image } from 'lucide-vue-next'

export interface FileEntry {
  name: string
  type: 'file' | 'directory'
  size: number
  modified?: string
}

const props = defineProps<{ entry: FileEntry }>()
const emit = defineEmits<{ open: [entry: FileEntry] }>()

const icon = computed(() => {
  if (props.entry.type === 'directory') return Folder
  const ext = props.entry.name.split('.').pop()?.toLowerCase() ?? ''
  if (['ts', 'js', 'vue', 'py', 'sh', 'json', 'yaml', 'yml', 'toml', 'css', 'html'].includes(ext)) return FileCode
  if (['png', 'jpg', 'jpeg', 'gif', 'svg', 'webp', 'ico'].includes(ext)) return Image
  return FileText
})

const formattedSize = computed(() => {
  if (props.entry.type === 'directory') return ''
  const kb = props.entry.size / 1024
  return kb < 1 ? `${props.entry.size}B` : `${kb.toFixed(1)}KB`
})

const relativeTime = computed(() => {
  if (!props.entry.modified) return ''
  const diff = Date.now() - new Date(props.entry.modified).getTime()
  const mins = Math.floor(diff / 60000)
  if (mins < 60) return `${mins}m ago`
  const hours = Math.floor(mins / 60)
  if (hours < 24) return `${hours}h ago`
  const days = Math.floor(hours / 24)
  if (days === 1) return 'yesterday'
  return `${days}d ago`
})
</script>

<template>
  <li class="file-item" @click="emit('open', entry)">
    <component :is="icon" :size="16" class="file-icon" :class="entry.type" />
    <span class="file-name">{{ entry.name }}</span>
    <span v-if="formattedSize" class="file-size">{{ formattedSize }}</span>
    <span v-if="relativeTime" class="file-modified">{{ relativeTime }}</span>
  </li>
</template>

<style scoped>
.file-item {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 9px 14px;
  border-bottom: 1px solid var(--savia-surface-variant);
  cursor: pointer;
  font-size: 14px;
  transition: background 0.12s;
}
.file-item:hover { background: var(--savia-surface-variant); }
.file-icon { flex-shrink: 0; }
.file-icon.directory { color: var(--savia-primary); }
.file-icon.file { color: var(--savia-on-surface-variant); }
.file-name { flex: 1; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.file-size { font-size: 12px; color: var(--savia-outline); min-width: 48px; text-align: right; }
.file-modified { font-size: 12px; color: var(--savia-outline); min-width: 64px; text-align: right; }
</style>
