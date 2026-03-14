<script setup lang="ts">
import { useDashboardStore } from '../stores/dashboard'
import { computed } from 'vue'

const dashboard = useDashboardStore()
const projects = computed(() => dashboard.data?.projects || [])

function onChange(e: Event) {
  const id = (e.target as HTMLSelectElement).value
  dashboard.selectProject(id)
}
</script>

<template>
  <select
    class="project-select"
    :value="dashboard.data?.selectedProjectId"
    @change="onChange"
  >
    <option v-for="p in projects" :key="p.id" :value="p.id">
      {{ p.name }}
    </option>
  </select>
</template>

<style scoped>
.project-select {
  padding: 6px 12px;
  border: 1px solid var(--savia-outline);
  border-radius: var(--savia-radius);
  background: var(--savia-surface);
  color: var(--savia-on-surface);
  font-size: 14px;
  min-width: 180px;
}
</style>
