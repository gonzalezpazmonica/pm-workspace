<script setup lang="ts">
import { useBacklogStore } from '../../stores/backlog'
import StateBadge from './StateBadge.vue'

const store = useBacklogStore()

function onDragStart(e: DragEvent, pbiId: string) {
  e.dataTransfer?.setData('text/plain', pbiId)
}

function onDrop(e: DragEvent, state: string) {
  const pbiId = e.dataTransfer?.getData('text/plain')
  if (pbiId) store.movePbi(pbiId, state)
}

function onDragOver(e: DragEvent) { e.preventDefault() }
</script>

<template>
  <div class="kanban">
    <div
      v-for="col in store.columns" :key="col"
      class="kanban-col"
      @drop="onDrop($event, col)"
      @dragover="onDragOver"
    >
      <div class="col-header">
        <span>{{ col }}</span>
        <span class="col-count">{{ store.filteredPbisByState[col]?.length ?? 0 }}</span>
      </div>
      <div class="col-body">
        <div
          v-for="pbi in store.filteredPbisByState[col]" :key="pbi.id"
          class="kanban-card"
          draggable="true"
          @dragstart="onDragStart($event, pbi.id)"
          @click="store.selectPbi(pbi.id)"
        >
          <div class="card-header">
            <span class="card-id">{{ pbi.id }}</span>
            <StateBadge :state="pbi.type" />
          </div>
          <div class="card-title">{{ pbi.title }}</div>
          <div class="card-footer">
            <span>{{ pbi.assigned_to }}</span>
            <span>{{ pbi.estimated_hours }}h</span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.kanban { display: flex; gap: 12px; overflow-x: auto; height: 100%; }
.kanban-col { min-width: 220px; flex: 1; display: flex; flex-direction: column; }
.col-header {
  display: flex; justify-content: space-between; align-items: center;
  padding: 8px 12px; font-weight: 600; font-size: 13px;
  background: var(--savia-surface); border-radius: var(--savia-radius) var(--savia-radius) 0 0;
}
.col-count {
  background: var(--savia-surface-variant); padding: 1px 8px;
  border-radius: 10px; font-size: 11px;
}
.col-body {
  flex: 1; padding: 8px; display: flex; flex-direction: column; gap: 8px;
  background: var(--savia-surface-variant); border-radius: 0 0 var(--savia-radius) var(--savia-radius);
  min-height: 100px; overflow-y: auto;
}
.kanban-card {
  background: var(--savia-surface); padding: 10px; border-radius: var(--savia-radius);
  box-shadow: var(--savia-shadow); cursor: grab; font-size: 13px;
}
.kanban-card:active { cursor: grabbing; }
.card-header { display: flex; justify-content: space-between; margin-bottom: 4px; }
.card-id { font-family: monospace; color: var(--savia-outline); font-size: 11px; }
.card-title { font-weight: 500; margin-bottom: 6px; }
.card-footer { display: flex; justify-content: space-between; color: var(--savia-outline); font-size: 12px; }
</style>
