<script setup lang="ts">
import { ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { X } from 'lucide-vue-next'
import { useBridge } from '../composables/useBridge'
import { useProjectStore } from '../stores/project'

const { t } = useI18n()
const emit = defineEmits<{ close: [] }>()
const { post } = useBridge()
const projectStore = useProjectStore()

const name = ref('')
const description = ref('')
const stack = ref('Vue')
const pm = ref('')
const client = ref('')
const sprintWeeks = ref('2')
const repoUrl = ref('')
const saving = ref(false)
const error = ref('')

const stacks = ['Vue', '.NET', 'Java', 'Python', 'Go', 'Rust', 'PHP', 'Ruby', 'Angular', 'React', 'Other']

async function create() {
  if (!name.value.trim()) { error.value = 'Project name is required'; return }
  if (pm.value && !pm.value.startsWith('@')) { error.value = 'PM must use @handle format'; return }
  saving.value = true; error.value = ''
  try {
    const slug = name.value.trim().toLowerCase().replace(/\s+/g, '-').replace(/[^a-z0-9-]/g, '')
    await post('/projects', {
      name: name.value.trim(), slug, description: description.value,
      stack: stack.value, pm: pm.value, client: client.value,
      sprintWeeks: parseInt(sprintWeeks.value), repoUrl: repoUrl.value,
    })
    await projectStore.load()
    projectStore.select(slug)
    emit('close')
  } catch (e) {
    error.value = 'Failed to create project'
  } finally { saving.value = false }
}
</script>

<template>
  <Teleport to="body">
  <div class="modal-overlay" @click.self="emit('close')">
    <div class="modal">
      <div class="modal-header">
        <h2>Create Project</h2>
        <button class="close-btn" @click="emit('close')"><X :size="18" /></button>
      </div>
      <div class="modal-body">
        <div class="field">
          <label>Project Name *</label>
          <input v-model="name" placeholder="My Project" />
        </div>
        <div class="field">
          <label>Description</label>
          <textarea v-model="description" rows="2" placeholder="Brief description..." />
        </div>
        <div class="field-row">
          <div class="field">
            <label>Stack</label>
            <select v-model="stack">
              <option v-for="s in stacks" :key="s">{{ s }}</option>
            </select>
          </div>
          <div class="field">
            <label>Sprint Duration</label>
            <select v-model="sprintWeeks">
              <option value="1">1 week</option>
              <option value="2">2 weeks</option>
              <option value="3">3 weeks</option>
              <option value="4">4 weeks</option>
            </select>
          </div>
        </div>
        <div class="field">
          <label>Project Manager (@handle)</label>
          <input v-model="pm" placeholder="@alice" />
        </div>
        <div class="field">
          <label>Client Name</label>
          <input v-model="client" placeholder="Client Corp" />
        </div>
        <div class="field">
          <label>Repository URL</label>
          <input v-model="repoUrl" placeholder="https://github.com/..." />
        </div>
        <p v-if="error" class="error">{{ error }}</p>
      </div>
      <div class="modal-footer">
        <button class="btn-cancel" @click="emit('close')">{{ t('common.cancel') }}</button>
        <button class="btn-create" @click="create" :disabled="saving">
          {{ saving ? t('common.loading') : t('common.create') }}
        </button>
      </div>
    </div>
  </div>
  </Teleport>
</template>

<style scoped>
.modal-overlay { position: fixed; inset: 0; background: rgba(0,0,0,0.5); display: flex; align-items: center; justify-content: center; z-index: 9999; padding: 16px; }
.modal { background: var(--savia-surface); border-radius: var(--savia-radius-lg); box-shadow: var(--savia-shadow); width: 480px; max-width: 100%; max-height: 90vh; overflow-y: auto; }
.modal-header { display: flex; align-items: center; justify-content: space-between; padding: 16px 20px; border-bottom: 1px solid var(--savia-surface-variant); }
.modal-header h2 { font-size: 16px; font-weight: 600; }
.close-btn { background: none; border: none; cursor: pointer; color: var(--savia-outline); display: flex; }
.modal-body { padding: 16px 20px; }
.field { margin-bottom: 12px; }
.field label { display: block; font-size: 12px; font-weight: 500; margin-bottom: 4px; color: var(--savia-on-surface-variant); }
.field input, .field textarea, .field select { width: 100%; padding: 7px 10px; border: 1px solid var(--savia-outline); border-radius: var(--savia-radius); font-size: 13px; background: var(--savia-background); color: var(--savia-on-surface); font-family: inherit; }
.field textarea { resize: vertical; }
.field-row { display: flex; gap: 12px; }
.field-row .field { flex: 1; }
.error { color: var(--savia-error); font-size: 12px; margin-top: 8px; }
.modal-footer { display: flex; justify-content: flex-end; gap: 8px; padding: 12px 20px; border-top: 1px solid var(--savia-surface-variant); }
.btn-cancel { padding: 7px 16px; background: var(--savia-surface-variant); border: none; border-radius: var(--savia-radius); cursor: pointer; font-size: 13px; }
.btn-create { padding: 7px 16px; background: var(--savia-primary); color: white; border: none; border-radius: var(--savia-radius); cursor: pointer; font-size: 13px; font-weight: 500; }
.btn-create:disabled { opacity: 0.6; }
</style>
