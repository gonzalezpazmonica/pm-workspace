<script setup lang="ts">
import { onMounted } from 'vue'
import { useDashboardStore } from '../stores/dashboard'
import { Target, BarChart2, AlertTriangle, Clock } from 'lucide-vue-next'
import LoadingSpinner from '../components/LoadingSpinner.vue'
import EmptyState from '../components/EmptyState.vue'

const store = useDashboardStore()
onMounted(() => { if (!store.data) store.load() })

const statIcons = [Target, BarChart2, AlertTriangle, Clock]
</script>

<template>
  <div class="home">
    <LoadingSpinner v-if="store.loading">Loading dashboard...</LoadingSpinner>
    <EmptyState v-else-if="store.error" icon="warning" :title="store.error"
      description="Check Bridge connection in Settings" />
    <template v-else-if="store.data">
      <h1 class="greeting">{{ store.data.greeting }}</h1>
      <div class="stats-row">
        <div class="stat-card glass-card" v-for="(stat, i) in [
          { value: store.data.sprint?.completedPoints ?? 0, label: 'SP Completed', icon: statIcons[0] },
          { value: store.data.sprint?.totalPoints ?? 0, label: 'SP Planned', icon: statIcons[1] },
          { value: store.data.blockedItems, label: 'Blocked', icon: statIcons[2] },
          { value: store.data.hoursToday.toFixed(1) + 'h', label: 'Today', icon: statIcons[3] },
        ]" :key="i">
          <component :is="stat.icon" :size="20" class="stat-icon" />
          <div class="stat-value">{{ stat.value }}</div>
          <div class="stat-label">{{ stat.label }}</div>
        </div>
      </div>
      <div class="grid-2">
        <section class="card glass-card">
          <h2>My Tasks</h2>
          <ul class="task-list">
            <li v-for="t in store.data.myTasks" :key="t.id" class="task-item">
              <span class="task-type" :class="t.type?.toLowerCase()">{{ t.type }}</span>
              <span class="task-title">{{ t.title }}</span>
              <span class="task-state">{{ t.state }}</span>
            </li>
          </ul>
          <EmptyState v-if="!store.data.myTasks.length" title="No tasks assigned" />
        </section>
        <section class="card glass-card">
          <h2>Recent Activity</h2>
          <ul class="activity-list">
            <li v-for="(a, i) in store.data.recentActivity" :key="i">{{ a }}</li>
          </ul>
          <EmptyState v-if="!store.data.recentActivity.length" title="No recent activity" />
        </section>
      </div>
    </template>
  </div>
</template>

<style scoped>
.home { max-width: 1200px; }
.greeting { font-size: 24px; margin-bottom: var(--space-6); color: var(--savia-on-background); font-weight: 600; }
.stats-row { display: grid; grid-template-columns: repeat(4, 1fr); gap: var(--space-4); margin-bottom: var(--space-6); }
.stat-card { padding: var(--space-5); text-align: center; }
.stat-icon { margin: 0 auto var(--space-2); color: var(--savia-primary); }
.stat-value { font-size: 28px; font-weight: 700; color: var(--savia-primary); }
.stat-label { font-size: 12px; color: var(--savia-on-surface-variant); margin-top: var(--space-1); }
.grid-2 { display: grid; grid-template-columns: 1fr 1fr; gap: var(--space-4); }
.card { padding: var(--space-5); }
.card h2 { font-size: 16px; margin-bottom: var(--space-3); color: var(--savia-on-surface); font-weight: 600; }
.task-list, .activity-list { list-style: none; }
.task-item { display: flex; gap: var(--space-2); align-items: center; padding: 8px 0; border-bottom: 1px solid var(--savia-surface-variant); font-size: 14px; }
.task-type { font-size: 11px; padding: 2px 6px; border-radius: 4px; background: var(--savia-surface-variant); font-weight: 600; }
.task-type.pbi { background: #e8d5f5; color: var(--savia-primary-dark); }
.task-type.bug { background: var(--savia-error-container); color: var(--savia-error); }
.task-title { flex: 1; }
.task-state { font-size: 12px; color: var(--savia-on-surface-variant); }
.activity-list li { padding: 6px 0; font-size: 14px; color: var(--savia-on-surface-variant); border-bottom: 1px solid var(--savia-surface-variant); }
@media (max-width: 768px) {
  .stats-row { grid-template-columns: repeat(2, 1fr); }
  .grid-2 { grid-template-columns: 1fr; }
}
</style>
