<script setup lang="ts">
import { onMounted, watch } from 'vue'
import { useDashboardStore } from '../../stores/dashboard'
import { useReportData } from '../../composables/useReportData'
import LoadingSpinner from '../../components/LoadingSpinner.vue'
import WorkloadHeatmap from '../../components/charts/WorkloadHeatmap.vue'
import type { TeamWorkloadData } from '../../types/reports'

const dashboard = useDashboardStore()
const workload = useReportData<TeamWorkloadData>('/reports/team-workload')

function loadAll() {
  if (dashboard.data?.selectedProjectId) workload.load()
}

onMounted(loadAll)
watch(() => dashboard.data?.selectedProjectId, loadAll)
</script>

<template>
  <div class="workload-page">
    <LoadingSpinner v-if="workload.loading.value" />
    <template v-else-if="workload.data.value">
      <section class="chart-card">
        <h3>Team Capacity vs Assigned</h3>
        <WorkloadHeatmap :members="workload.data.value.members" />
      </section>
      <section class="chart-card">
        <h3>Details</h3>
        <table class="detail-table">
          <thead><tr><th>Member</th><th>Capacity</th><th>Assigned</th><th>Load</th></tr></thead>
          <tbody>
            <tr v-for="m in workload.data.value.members" :key="m.name">
              <td>{{ m.name }}</td><td>{{ m.capacity }}h</td><td>{{ m.assigned }}h</td>
              <td :style="{ color: m.assigned > m.capacity ? '#BA1A1A' : '#155724' }">
                {{ Math.round(m.assigned / m.capacity * 100) }}%
              </td>
            </tr>
          </tbody>
        </table>
      </section>
    </template>
  </div>
</template>

<style scoped>
.workload-page { display: flex; flex-direction: column; gap: 20px; }
.chart-card { background: var(--savia-surface); padding: 20px; border-radius: var(--savia-radius-lg); box-shadow: var(--savia-shadow); }
.chart-card h3 { font-size: 15px; margin-bottom: 12px; }
.detail-table { width: 100%; border-collapse: collapse; }
.detail-table th, .detail-table td { padding: 8px 12px; text-align: left; font-size: 13px; border-bottom: 1px solid var(--savia-surface-variant); }
.detail-table th { font-weight: 600; font-size: 12px; background: var(--savia-surface-variant); }
</style>
