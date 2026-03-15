<script setup lang="ts">
import { useI18n } from 'vue-i18n'
const { t } = useI18n()
import { onMounted, ref } from 'vue'
import { List, LayoutGrid, Plus } from 'lucide-vue-next'
import { useBacklogStore } from '../stores/backlog'
import BacklogTree from '../components/backlog/BacklogTree.vue'
import BacklogKanban from '../components/backlog/BacklogKanban.vue'
import FilterBar from '../components/backlog/FilterBar.vue'
import PbiDetail from '../components/backlog/PbiDetail.vue'
import LoadingSpinner from '../components/LoadingSpinner.vue'

const store = useBacklogStore()
const showNewPbi = ref(false)
const newPbiTitle = ref('')
const newPbiType = ref('User Story')
onMounted(() => store.load())

function createPbi() {
  if (newPbiTitle.value.trim()) {
    store.addPbi(newPbiTitle.value.trim(), newPbiType.value)
    newPbiTitle.value = ''
    showNewPbi.value = false
  }
}
</script>

<template>
  <div class="backlog-page">
    <div class="backlog-toolbar">
      <h1 class="backlog-title">{{ t('backlog.title') }}</h1>
      <div class="toolbar-actions">
        <button class="new-pbi-btn" @click="showNewPbi = !showNewPbi">
          <Plus :size="14" /> New PBI
        </button>
        <div class="view-toggle">
          <button :class="{ active: store.viewMode === 'tree' }" @click="store.setViewMode('tree')">
            <List :size="14" /> Tree
          </button>
          <button :class="{ active: store.viewMode === 'kanban' }" @click="store.setViewMode('kanban')">
            <LayoutGrid :size="14" /> Kanban
          </button>
        </div>
      </div>
    </div>

    <div v-if="showNewPbi" class="new-pbi-form">
      <input v-model="newPbiTitle" :placeholder="t('backlog.pbiTitle')" class="new-pbi-input" @keyup.enter="createPbi" />
      <select v-model="newPbiType" class="new-pbi-type">
        <option>User Story</option><option>Bug</option><option>Tech Debt</option><option>Spike</option>
      </select>
      <button class="create-btn" @click="createPbi">{{ t('common.create') }}</button>
      <button class="cancel-btn" @click="showNewPbi = false">{{ t('common.cancel') }}</button>
    </div>

    <FilterBar />

    <LoadingSpinner v-if="store.loading" />

    <div v-else class="backlog-body" :class="{ 'has-detail': store.selectedItemId }">
      <div class="backlog-list">
        <BacklogTree v-if="store.viewMode === 'tree'" />
        <BacklogKanban v-else />
      </div>
      <PbiDetail v-if="store.selectedItemId" />
    </div>
  </div>
</template>

<style scoped>
.backlog-page { display: flex; flex-direction: column; height: 100%; }
.backlog-toolbar { display: flex; align-items: center; justify-content: space-between; padding: 0 0 12px; gap: 12px; }
.backlog-title { font-size: 18px; font-weight: 600; }
.toolbar-actions { display: flex; align-items: center; gap: 8px; }
.new-pbi-btn {
  display: flex; align-items: center; gap: 4px; padding: 5px 12px;
  background: var(--savia-primary); color: white; border: none; border-radius: var(--savia-radius);
  font-size: 12px; cursor: pointer; font-family: inherit; font-weight: 500;
}
.new-pbi-form {
  display: flex; gap: 8px; padding: 8px 0; align-items: center;
}
.new-pbi-input { flex: 1; padding: 6px 10px; border: 1px solid var(--savia-outline); border-radius: var(--savia-radius); font-size: 13px; }
.new-pbi-type { padding: 6px; border: 1px solid var(--savia-outline); border-radius: var(--savia-radius); font-size: 12px; }
.create-btn { padding: 6px 14px; background: var(--savia-primary); color: white; border: none; border-radius: var(--savia-radius); cursor: pointer; font-size: 12px; }
.cancel-btn { padding: 6px 14px; background: var(--savia-surface-variant); border: none; border-radius: var(--savia-radius); cursor: pointer; font-size: 12px; }
.view-toggle { display: flex; gap: 4px; }
.view-toggle button {
  display: flex; align-items: center; gap: 4px;
  padding: 5px 12px; border-radius: var(--savia-radius);
  background: var(--savia-surface-variant); border: none; font-size: 12px;
  cursor: pointer; font-family: inherit; color: var(--savia-on-surface);
}
.view-toggle button.active { background: var(--savia-primary); color: white; }
.backlog-body { flex: 1; overflow: hidden; }
.backlog-body.has-detail { display: grid; grid-template-columns: 1fr 380px; gap: 12px; }
.backlog-list { overflow: auto; }
</style>
