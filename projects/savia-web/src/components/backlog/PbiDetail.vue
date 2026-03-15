<script setup lang="ts">
import { ref, watch, computed } from 'vue'
import { X, Plus, BookOpen, Bug, Wrench, Lightbulb, ListTodo, FileText } from 'lucide-vue-next'
import { useBacklogStore } from '../../stores/backlog'
import StateBadge from './StateBadge.vue'

const store = useBacklogStore()
const activeTab = ref('desc')
const editingTitle = ref(false)
const editTitle = ref('')
const editDesc = ref('')

const pbiStates = ['New', 'Active', 'Resolved', 'Closed']
const specStates = ['Draft', 'In Progress', 'Done', 'Archived']
const typeIcon: Record<string, typeof BookOpen> = {
  'User Story': BookOpen, Bug, 'Tech Debt': Wrench, Spike: Lightbulb,
}

const isSpec = computed(() => store.selectedItemType === 'spec')
const item = computed(() => isSpec.value ? store.selectedSpec : store.selectedPbi)

watch(item, (val) => {
  if (val) { editTitle.value = val.title; editDesc.value = '' }
  editingTitle.value = false
  activeTab.value = 'desc'
})

function saveTitle() {
  if (!item.value || !editTitle.value.trim()) { editingTitle.value = false; return }
  if (isSpec.value) store.updateSpec(item.value.id, { title: editTitle.value.trim() })
  else store.updatePbi(item.value.id, { title: editTitle.value.trim() })
  editingTitle.value = false
}

function changeState(e: Event) {
  const state = (e.target as HTMLSelectElement).value
  if (isSpec.value && store.selectedSpec) store.updateSpec(store.selectedSpec.id, { state })
  else if (store.selectedPbi) store.updatePbi(store.selectedPbi.id, { state })
}

function close() {
  store.selectPbi(null)
}
</script>

<template>
  <div v-if="item" class="detail-panel">
    <div class="detail-header">
      <component :is="isSpec ? FileText : (typeIcon[(item as any).type] ?? BookOpen)" :size="16" class="header-icon" />
      <span class="detail-id">{{ item.id }}</span>
      <input v-if="editingTitle" v-model="editTitle" class="title-input" @blur="saveTitle" @keyup.enter="saveTitle" />
      <span v-else class="detail-title" @dblclick="editingTitle = true">{{ item.title }}</span>
      <button class="close-btn" @click="close"><X :size="16" /></button>
    </div>
    <div class="detail-meta">
      <select class="state-select" :value="item.state" @change="changeState">
        <option v-for="s in (isSpec ? specStates : pbiStates)" :key="s" :value="s">{{ s }}</option>
      </select>
      <template v-if="!isSpec && store.selectedPbi">
        <StateBadge :state="store.selectedPbi.type" />
        <span>{{ store.selectedPbi.assigned_to }}</span>
        <span>{{ store.selectedPbi.estimated_hours }}h</span>
      </template>
    </div>

    <!-- PBI tabs -->
    <template v-if="!isSpec && store.selectedPbi">
      <div class="tabs">
        <button :class="{ active: activeTab === 'desc' }" @click="activeTab = 'desc'">Description</button>
        <button :class="{ active: activeTab === 'tasks' }" @click="activeTab = 'tasks'">Tasks</button>
        <button :class="{ active: activeTab === 'specs' }" @click="activeTab = 'specs'">Specs</button>
        <button :class="{ active: activeTab === 'history' }" @click="activeTab = 'history'">History</button>
      </div>
      <div class="tab-content">
        <div v-if="activeTab === 'desc'">
          <textarea v-model="editDesc" class="desc-editor" placeholder="Write description..." rows="6" />
        </div>
        <div v-else-if="activeTab === 'tasks'">
          <div v-for="t in store.selectedPbi.tasks" :key="t.id" class="task-row">
            <ListTodo :size="13" class="task-icon" />
            <span class="task-id">{{ t.id }}</span>
            <span class="task-title">{{ t.title }}</span>
            <StateBadge :state="t.state" />
          </div>
          <button class="add-btn" @click="store.addTask(store.selectedPbi!.id)"><Plus :size="14" /> Add Task</button>
        </div>
        <div v-else class="placeholder">No data.</div>
      </div>
    </template>

    <!-- Spec tabs -->
    <template v-if="isSpec && store.selectedSpec">
      <div class="tabs">
        <button :class="{ active: activeTab === 'desc' }" @click="activeTab = 'desc'">Description</button>
        <button :class="{ active: activeTab === 'pbis' }" @click="activeTab = 'pbis'">PBIs</button>
      </div>
      <div class="tab-content">
        <div v-if="activeTab === 'desc'">
          <textarea v-model="editDesc" class="desc-editor" placeholder="Spec description..." rows="6" />
        </div>
        <div v-else-if="activeTab === 'pbis'">
          <div v-for="p in store.selectedSpec.pbis" :key="p.id" class="task-row" @click="store.selectPbi(p.id)">
            <component :is="typeIcon[p.type] ?? BookOpen" :size="13" class="pbi-mini-icon" />
            <span class="task-id">{{ p.id }}</span>
            <span class="task-title">{{ p.title }}</span>
            <StateBadge :state="p.state" />
          </div>
          <button class="add-btn" @click="store.addPbi('New PBI', 'User Story', store.selectedSpec!.id)"><Plus :size="14" /> Add PBI</button>
        </div>
      </div>
    </template>
  </div>
</template>

<style scoped>
.detail-panel { background: var(--savia-surface); border-radius: var(--savia-radius-lg); box-shadow: var(--savia-shadow); overflow: hidden; display: flex; flex-direction: column; }
.detail-header { display: flex; align-items: center; gap: 8px; padding: 12px 16px; border-bottom: 1px solid var(--savia-surface-variant); }
.header-icon { color: var(--savia-primary); flex-shrink: 0; }
.detail-id { font-family: monospace; color: var(--savia-outline); }
.detail-title { flex: 1; font-weight: 600; cursor: pointer; }
.detail-title:hover { text-decoration: underline dotted; }
.title-input { flex: 1; font-size: 14px; font-weight: 600; padding: 2px 6px; border: 1px solid var(--savia-primary); border-radius: var(--savia-radius); }
.close-btn { background: none; border: none; cursor: pointer; color: var(--savia-outline); display: flex; }
.detail-meta { display: flex; gap: 12px; padding: 8px 16px; font-size: 13px; color: var(--savia-outline); align-items: center; }
.state-select { padding: 3px 8px; border: 1px solid var(--savia-outline); border-radius: var(--savia-radius); font-size: 12px; background: var(--savia-surface); }
.tabs { display: flex; border-bottom: 1px solid var(--savia-surface-variant); }
.tabs button { padding: 8px 16px; background: none; border: none; border-bottom: 2px solid transparent; font-size: 13px; cursor: pointer; font-family: inherit; color: var(--savia-on-surface-variant); }
.tabs button.active { border-bottom-color: var(--savia-primary); color: var(--savia-primary); font-weight: 600; }
.tab-content { padding: 12px 16px; flex: 1; overflow-y: auto; font-size: 13px; }
.desc-editor { width: 100%; border: 1px solid var(--savia-outline); border-radius: var(--savia-radius); padding: 8px; font-size: 13px; font-family: inherit; resize: vertical; background: var(--savia-background); color: var(--savia-on-surface); }
.task-row { display: flex; gap: 8px; align-items: center; padding: 4px 0; cursor: pointer; }
.task-row:hover { background: var(--savia-surface-variant); border-radius: var(--savia-radius); }
.task-icon, .pbi-mini-icon { color: var(--savia-outline); flex-shrink: 0; }
.task-id { font-family: monospace; font-size: 11px; color: var(--savia-outline); }
.task-title { flex: 1; }
.add-btn { display: flex; align-items: center; gap: 4px; margin-top: 8px; padding: 5px 12px; background: var(--savia-surface-variant); border: none; border-radius: var(--savia-radius); cursor: pointer; font-size: 12px; font-family: inherit; color: var(--savia-on-surface); }
.add-btn:hover { background: var(--savia-primary); color: white; }
.placeholder { color: var(--savia-outline); font-style: italic; }
</style>
