<script setup lang="ts">
import { useRoute } from 'vue-router'
import ProjectSelector from '../../components/ProjectSelector.vue'
import { useDashboardStore } from '../../stores/dashboard'
import { onMounted } from 'vue'

const route = useRoute()
const dashboard = useDashboardStore()
onMounted(() => { if (!dashboard.data) dashboard.load() })

const tabs = [
  { path: '/reports/sprint', label: 'Sprint' },
  { path: '/reports/board-flow', label: 'Board Flow' },
  { path: '/reports/team-workload', label: 'Workload' },
  { path: '/reports/portfolio', label: 'Portfolio' },
  { path: '/reports/dora', label: 'DORA' },
  { path: '/reports/quality', label: 'Quality' },
  { path: '/reports/debt', label: 'Debt' },
]
</script>

<template>
  <div class="reports">
    <div class="reports-header">
      <h1>Reports</h1>
      <ProjectSelector />
    </div>
    <nav class="tabs">
      <router-link
        v-for="tab in tabs" :key="tab.path" :to="tab.path"
        class="tab" :class="{ active: route.path === tab.path }"
      >{{ tab.label }}</router-link>
    </nav>
    <div class="reports-content">
      <router-view />
    </div>
  </div>
</template>

<style scoped>
.reports { display: flex; flex-direction: column; height: 100%; }
.reports-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
.reports-header h1 { font-size: 20px; }
.tabs { display: flex; gap: 4px; border-bottom: 2px solid var(--savia-surface-variant); padding-bottom: 0; margin-bottom: 20px; overflow-x: auto; }
.tab { padding: 8px 16px; font-size: 13px; color: var(--savia-on-surface-variant); text-decoration: none; border-bottom: 2px solid transparent; margin-bottom: -2px; white-space: nowrap; }
.tab:hover { color: var(--savia-primary); }
.tab.active { color: var(--savia-primary); border-bottom-color: var(--savia-primary); font-weight: 600; }
.reports-content { flex: 1; overflow-y: auto; }
</style>
