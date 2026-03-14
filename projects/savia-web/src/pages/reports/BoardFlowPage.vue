<script setup lang="ts">
import { onMounted, watch } from 'vue'
import { useDashboardStore } from '../../stores/dashboard'
import { useReportData } from '../../composables/useReportData'
import LoadingSpinner from '../../components/LoadingSpinner.vue'
import CycleTimeChart from '../../components/charts/CycleTimeChart.vue'
import type { CycleTimeData } from '../../types/reports'

const dashboard = useDashboardStore()
const cycleTime = useReportData<CycleTimeData>('/reports/cycle-time')

function loadAll() {
  if (dashboard.data?.selectedProjectId) cycleTime.load('&sprints=5')
}

onMounted(loadAll)
watch(() => dashboard.data?.selectedProjectId, loadAll)
</script>

<template>
  <div class="board-flow">
    <LoadingSpinner v-if="cycleTime.loading.value" />
    <template v-else-if="cycleTime.data.value">
      <section class="chart-card">
        <h3>Cycle Time & Lead Time</h3>
        <CycleTimeChart :sprints="cycleTime.data.value.sprints" />
      </section>
      <section class="chart-card">
        <h3>Summary</h3>
        <table class="summary-table">
          <thead><tr><th>Sprint</th><th>Cycle Time (d)</th><th>Lead Time (d)</th></tr></thead>
          <tbody>
            <tr v-for="s in cycleTime.data.value.sprints" :key="s.name">
              <td>{{ s.name }}</td><td>{{ s.cycleTime }}</td><td>{{ s.leadTime }}</td>
            </tr>
          </tbody>
        </table>
      </section>
    </template>
  </div>
</template>

<style scoped>
.board-flow { display: flex; flex-direction: column; gap: 20px; }
.chart-card { background: var(--savia-surface); padding: 20px; border-radius: var(--savia-radius-lg); box-shadow: var(--savia-shadow); }
.chart-card h3 { font-size: 15px; margin-bottom: 12px; }
.summary-table { width: 100%; border-collapse: collapse; }
.summary-table th, .summary-table td { padding: 8px 12px; text-align: left; font-size: 13px; border-bottom: 1px solid var(--savia-surface-variant); }
.summary-table th { font-weight: 600; font-size: 12px; background: var(--savia-surface-variant); }
</style>
