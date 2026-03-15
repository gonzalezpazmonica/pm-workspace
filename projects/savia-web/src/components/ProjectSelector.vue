<script setup lang="ts">
import { useProjectStore } from '../stores/project'

const store = useProjectStore()

const healthColor: Record<string, string> = {
  healthy: '#22c55e',
  warning: '#f59e0b',
  critical: '#ef4444',
  unknown: '#9ca3af',
}

function onChange(e: Event) {
  const id = (e.target as HTMLSelectElement).value
  store.select(id)
}
</script>

<template>
  <div class="selector-wrapper">
    <select
      class="project-select"
      :value="store.selectedId"
      @change="onChange"
    >
      <option
        v-for="p in store.projects"
        :key="p.id"
        :value="p.id"
        class="project-item"
      >
        {{ p.name }}
      </option>
    </select>
    <span
      v-if="store.selected"
      class="health-dot"
      :style="{ background: healthColor[store.selected.health] ?? healthColor.unknown }"
    />
  </div>
</template>

<style scoped>
.selector-wrapper {
  position: relative;
  display: flex;
  align-items: center;
  gap: 6px;
}

.project-select {
  padding: 5px 10px;
  border: 1px solid var(--savia-outline);
  border-radius: var(--savia-radius);
  background: var(--savia-surface);
  color: var(--savia-on-surface);
  font-size: 13px;
  min-width: 180px;
  max-width: 220px;
  cursor: pointer;
}

.project-select:focus {
  outline: 2px solid var(--savia-primary);
  outline-offset: 1px;
}

.health-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  flex-shrink: 0;
  display: inline-block;
}

.project-item {
  padding: 4px 0;
}
</style>
