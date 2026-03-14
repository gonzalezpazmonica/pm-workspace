<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useBridge } from '../composables/useBridge'
import { useDashboardStore } from '../stores/dashboard'
import LoadingSpinner from '../components/LoadingSpinner.vue'
import EmptyState from '../components/EmptyState.vue'
import ProjectSelector from '../components/ProjectSelector.vue'
import type { BoardColumn } from '../types/bridge'

const { get } = useBridge()
const dashboard = useDashboardStore()
const columns = ref<BoardColumn[]>([])
const loading = ref(false)
const error = ref<string | null>(null)

async function load() {
  if (!dashboard.data?.selectedProjectId) return
  loading.value = true; error.value = null
  try {
    columns.value = await get<BoardColumn[]>(`/kanban?project=${dashboard.data.selectedProjectId}`) ?? []
  } catch (e) { error.value = String(e) }
  finally { loading.value = false }
}

onMounted(() => { if (!dashboard.data) dashboard.load().then(load); else load() })
</script>

<template>
  <div class="kanban-page">
    <div class="page-header">
      <h1>Kanban Board</h1>
      <ProjectSelector @change="load" />
    </div>
    <LoadingSpinner v-if="loading" />
    <EmptyState v-else-if="error" icon="⚠️" :title="error" />
    <div v-else class="board">
      <div v-for="col in columns" :key="col.name" class="column">
        <div class="col-header">
          <span>{{ col.name }}</span>
          <span class="col-count">{{ col.items.length }}</span>
        </div>
        <div class="col-cards">
          <div v-for="item in col.items" :key="item.id" class="card" :class="item.type.toLowerCase()">
            <div class="card-id">{{ item.id }}</div>
            <div class="card-title">{{ item.title }}</div>
            <div class="card-meta">
              <span v-if="item.assignedTo">{{ item.assignedTo }}</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.kanban-page { height: 100%; display: flex; flex-direction: column; }
.page-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
.page-header h1 { font-size: 20px; }
.board { display: flex; gap: 12px; flex: 1; overflow-x: auto; padding-bottom: 8px; }
.column { min-width: 260px; flex: 1; background: var(--savia-surface-variant); border-radius: var(--savia-radius-lg); display: flex; flex-direction: column; }
.col-header { display: flex; justify-content: space-between; padding: 12px; font-weight: 600; font-size: 14px; }
.col-count { background: var(--savia-primary); color: white; font-size: 11px; padding: 2px 8px; border-radius: 10px; }
.col-cards { flex: 1; overflow-y: auto; padding: 0 8px 8px; display: flex; flex-direction: column; gap: 8px; }
.card { background: var(--savia-surface); border-radius: var(--savia-radius); padding: 10px; box-shadow: var(--savia-shadow); }
.card-id { font-size: 11px; color: var(--savia-on-surface-variant); }
.card-title { font-size: 13px; margin: 4px 0; }
.card-meta { display: flex; justify-content: space-between; font-size: 11px; color: var(--savia-on-surface-variant); }
.sp { background: var(--savia-surface-variant); padding: 1px 6px; border-radius: 4px; }
</style>
