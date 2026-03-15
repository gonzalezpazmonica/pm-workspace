<script setup lang="ts">
import { ref, computed } from 'vue'
import { Copy, Eye, Code } from 'lucide-vue-next'
import { marked } from 'marked'

const props = defineProps<{ content: string; language?: string; filename: string; editable?: boolean }>()
const emit = defineEmits<{ save: [content: string] }>()

const showRendered = ref(true)
const copied = ref(false)
const editing = ref(false)
const editContent = ref('')

const isMarkdown = computed(() => props.filename.endsWith('.md'))
const lineCount = computed(() => props.content.split('\n').length)

// Configure marked for LinkedIn-style rendering
marked.setOptions({ gfm: true, breaks: false })

const frontmatter = computed(() => {
  if (!isMarkdown.value || !props.content.startsWith('---')) return null
  const end = props.content.indexOf('---', 3)
  if (end === -1) return null
  const fm: Record<string, string> = {}
  props.content.slice(3, end).trim().split('\n').forEach(line => {
    const idx = line.indexOf(':')
    if (idx > 0) fm[line.slice(0, idx).trim()] = line.slice(idx + 1).trim().replace(/^["']|["']$/g, '')
  })
  return Object.keys(fm).length > 0 ? fm : null
})

const markdownBody = computed(() => {
  if (!isMarkdown.value) return ''
  let body = props.content
  if (body.startsWith('---')) {
    const end = body.indexOf('---', 3)
    if (end > 0) body = body.slice(end + 3).trim()
  }
  return marked.parse(body) as string
})

const lines = computed(() => props.content.split('\n'))

async function copyToClipboard() {
  await navigator.clipboard.writeText(props.content)
  copied.value = true
  setTimeout(() => { copied.value = false }, 1500)
}

function startEdit() {
  editContent.value = props.content
  editing.value = true
}

function saveEdit() {
  emit('save', editContent.value)
  editing.value = false
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
      <button v-if="editable && !editing" class="viewer-btn edit-btn" @click="startEdit">Edit</button>
      <button class="viewer-btn" @click="copyToClipboard">
        <Copy :size="14" /> {{ copied ? 'Copied!' : 'Copy' }}
      </button>
    </div>

    <!-- Edit mode -->
    <div v-if="editing" class="editor-wrap">
      <textarea v-model="editContent" class="editor-textarea" />
      <div class="editor-actions">
        <button class="btn-save" @click="saveEdit">Save</button>
        <button class="btn-cancel" @click="editing = false">Cancel</button>
      </div>
    </div>

    <!-- Frontmatter card -->
    <div v-else-if="isMarkdown && showRendered && frontmatter" class="fm-card">
      <div v-for="(v, k) in frontmatter" :key="k" class="fm-row">
        <span class="fm-key">{{ k }}</span>
        <span class="fm-val">{{ v }}</span>
      </div>
    </div>

    <!-- Rendered markdown (LinkedIn-style) -->
    <div v-if="!editing && isMarkdown && showRendered" class="viewer-markdown" v-html="markdownBody" />

    <!-- Raw code view -->
    <div v-if="!editing && !(isMarkdown && showRendered)" class="viewer-code">
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
  display: flex; align-items: center; gap: 8px; padding: 8px 14px;
  border-bottom: 1px solid var(--savia-surface-variant); font-size: 13px; flex-wrap: wrap;
}
.viewer-filename { flex: 1; font-weight: 500; font-family: monospace; }
.viewer-meta { color: var(--savia-outline); }
.viewer-btn {
  display: flex; align-items: center; gap: 4px; padding: 3px 8px;
  border-radius: var(--savia-radius); background: var(--savia-surface-variant);
  font-size: 12px; cursor: pointer; border: none; font-family: inherit; color: var(--savia-on-surface);
}
.viewer-btn:hover { background: var(--savia-outline); color: white; }
.edit-btn { background: var(--savia-primary); color: white; }

/* Frontmatter card */
.fm-card {
  margin: 12px 16px; padding: 10px 14px; background: var(--savia-surface-variant);
  border-radius: var(--savia-radius); border-left: 3px solid var(--savia-primary);
}
.fm-row { display: flex; gap: 8px; padding: 2px 0; font-size: 12px; }
.fm-key { font-weight: 600; min-width: 100px; color: var(--savia-outline); }
.fm-val { color: var(--savia-on-surface); }

/* LinkedIn-style markdown */
.viewer-markdown {
  padding: 20px 24px; overflow: auto; max-height: 65vh; font-size: 15px;
  line-height: 1.7; max-width: 720px; color: var(--savia-on-surface);
}
.viewer-markdown :deep(h1) { font-size: 24px; font-weight: 700; margin: 24px 0 12px; border-bottom: 1px solid var(--savia-surface-variant); padding-bottom: 8px; }
.viewer-markdown :deep(h2) { font-size: 20px; font-weight: 600; margin: 20px 0 10px; }
.viewer-markdown :deep(h3) { font-size: 16px; font-weight: 600; margin: 16px 0 8px; }
.viewer-markdown :deep(p) { margin: 0 0 12px; }
.viewer-markdown :deep(blockquote) { border-left: 3px solid var(--savia-primary); padding: 8px 16px; margin: 12px 0; font-style: italic; color: var(--savia-on-surface-variant); }
.viewer-markdown :deep(table) { width: 100%; border-collapse: collapse; margin: 12px 0; font-size: 13px; overflow-x: auto; display: block; }
.viewer-markdown :deep(th) { background: var(--savia-surface-variant); font-weight: 600; text-align: left; padding: 8px; border: 1px solid var(--savia-outline); }
.viewer-markdown :deep(td) { padding: 6px 8px; border: 1px solid var(--savia-surface-variant); }
.viewer-markdown :deep(tr:nth-child(even)) { background: var(--savia-surface-variant); }
.viewer-markdown :deep(code) { background: var(--savia-surface-variant); padding: 2px 6px; border-radius: 3px; font-size: 13px; }
.viewer-markdown :deep(pre) { background: var(--savia-background); padding: 12px; border-radius: var(--savia-radius); overflow-x: auto; margin: 12px 0; }
.viewer-markdown :deep(pre code) { background: none; padding: 0; font-size: 13px; line-height: 1.5; }
.viewer-markdown :deep(img) { max-width: 100%; border-radius: var(--savia-radius); margin: 8px 0; }
.viewer-markdown :deep(a) { color: var(--savia-primary); text-decoration: none; }
.viewer-markdown :deep(a:hover) { text-decoration: underline; }
.viewer-markdown :deep(ul), .viewer-markdown :deep(ol) { padding-left: 24px; margin: 8px 0; }
.viewer-markdown :deep(li) { margin: 4px 0; }
.viewer-markdown :deep(hr) { border: none; border-top: 1px solid var(--savia-surface-variant); margin: 20px 0; }

/* Raw code */
.viewer-code { overflow: auto; max-height: 65vh; font-family: monospace; font-size: 12px; }
.code-line { display: flex; }
.code-line:hover { background: var(--savia-surface-variant); }
.line-num { min-width: 44px; padding: 0 8px; text-align: right; color: var(--savia-outline); user-select: none; border-right: 1px solid var(--savia-surface-variant); }
.line-text { padding: 0 12px; white-space: pre; flex: 1; }

/* Editor */
.editor-wrap { padding: 12px; }
.editor-textarea { width: 100%; min-height: 300px; font-family: monospace; font-size: 13px; padding: 12px; border: 1px solid var(--savia-outline); border-radius: var(--savia-radius); resize: vertical; background: var(--savia-background); color: var(--savia-on-surface); }
.editor-actions { display: flex; gap: 8px; margin-top: 8px; }
.btn-save { padding: 6px 16px; background: var(--savia-primary); color: white; border: none; border-radius: var(--savia-radius); cursor: pointer; }
.btn-cancel { padding: 6px 16px; background: var(--savia-surface-variant); border: none; border-radius: var(--savia-radius); cursor: pointer; }
</style>
