<script setup lang="ts">
import { ref, computed } from 'vue'
import { Copy, Eye, Code } from 'lucide-vue-next'
import { marked } from 'marked'

const props = defineProps<{
  content: string
  language?: string
  filename: string
}>()

const showRendered = ref(true)
const copied = ref(false)

const isMarkdown = computed(() => props.filename.endsWith('.md'))
const lineCount = computed(() => props.content.split('\n').length)

const renderedHtml = computed(() => {
  if (!isMarkdown.value) return ''
  return marked.parse(props.content) as string
})

const lines = computed(() => props.content.split('\n'))

async function copyToClipboard() {
  await navigator.clipboard.writeText(props.content)
  copied.value = true
  setTimeout(() => { copied.value = false }, 1500)
}
</script>

<template>
  <div class="viewer">
    <div class="viewer-header">
      <span class="viewer-filename">{{ filename }}</span>
      <span class="viewer-meta">{{ lineCount }} lines</span>
      <button v-if="isMarkdown" class="viewer-btn" @click="showRendered = !showRendered">
        <component :is="showRendered ? Code : Eye" :size="14" />
        {{ showRendered ? 'Raw' : 'Rendered' }}
      </button>
      <button class="viewer-btn" @click="copyToClipboard">
        <Copy :size="14" />
        {{ copied ? 'Copied!' : 'Copy' }}
      </button>
    </div>

    <div v-if="isMarkdown && showRendered" class="viewer-markdown" v-html="renderedHtml" />

    <div v-else class="viewer-code">
      <div v-for="(line, i) in lines" :key="i" class="code-line">
        <span class="line-num">{{ i + 1 }}</span>
        <span class="line-text">{{ line }}</span>
      </div>
    </div>
  </div>
</template>

<style scoped>
.viewer { background: var(--savia-surface); border-radius: var(--savia-radius); overflow: hidden; }
.viewer-header {
  display: flex; align-items: center; gap: 8px;
  padding: 8px 14px; border-bottom: 1px solid var(--savia-surface-variant);
  font-size: 13px; flex-wrap: wrap;
}
.viewer-filename { flex: 1; font-weight: 500; font-family: monospace; }
.viewer-meta { color: var(--savia-outline); }
.viewer-btn {
  display: flex; align-items: center; gap: 4px;
  padding: 3px 8px; border-radius: var(--savia-radius);
  background: var(--savia-surface-variant); font-size: 12px;
  cursor: pointer; border: none; font-family: inherit; color: var(--savia-on-surface);
}
.viewer-btn:hover { background: var(--savia-outline); color: white; }
.viewer-markdown { padding: 16px; overflow: auto; max-height: 65vh; font-size: 14px; line-height: 1.6; }
.viewer-code { overflow: auto; max-height: 65vh; font-family: monospace; font-size: 12px; }
.code-line { display: flex; }
.code-line:hover { background: var(--savia-surface-variant); }
.line-num {
  min-width: 44px; padding: 0 8px; text-align: right;
  color: var(--savia-outline); user-select: none; border-right: 1px solid var(--savia-surface-variant);
}
.line-text { padding: 0 12px; white-space: pre; flex: 1; }
</style>
