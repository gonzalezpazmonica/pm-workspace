<script setup lang="ts">
import { onMounted, watch } from 'vue'
import { useDashboardStore } from '../../stores/dashboard'
import { useReportData } from '../../composables/useReportData'
import LoadingSpinner from '../../components/LoadingSpinner.vue'
import DebtTrendLine from '../../components/charts/DebtTrendLine.vue'
import type { DebtData } from '../../types/reports'

const dashboard = useDashboardStore()
const debt = useReportData<DebtData>('/reports/debt')

function loadAll() {
  if (dashboard.data?.selectedProjectId) debt.load()
}

onMounted(loadAll)
watch(() => dashboard.data?.selectedProjectId, loadAll)

function severityColor(s: string) {
  return s === 'high' ? '#BA1A1A' : s === 'medium' ? '#E6A817' : '#6B4C9A'
}
</script>

<template>
  <div class="debt-page">
    <LoadingSpinner v-if="debt.loading.value" />
    <template v-else-if="debt.data.value">
      <section class="chart-card">
        <h3>Debt Trend ({{ debt.data.value.topItems.length }} items)</h3>
        <DebtTrendLine :trend="debt.data.value.trend" />
      </section>
      <section class="chart-card">
        <h3>Top Debt Items</h3>
        <table class="debt-table">
          <thead><tr><th>Title</th><th>Severity</th><th>Age (days)</th><th>Effort</th></tr></thead>
          <tbody>
            <tr v-for="(item, idx) in debt.data.value.topItems" :key="idx">
              <td>{{ item.title }}</td>
              <td><span class="severity-badge" :style="{ background: severityColor(item.severity) }">{{ item.severity }}</span></td>
              <td>{{ item.age }}d</td>
            </tr>
          </tbody>
        </table>
      </section>
    </template>
  </div>
</template>

<style scoped>
.debt-page { display: flex; flex-direction: column; gap: 20px; }
.chart-card { background: var(--savia-surface); padding: 20px; border-radius: var(--savia-radius-lg); box-shadow: var(--savia-shadow); }
.chart-card h3 { font-size: 15px; margin-bottom: 12px; }
.debt-table { width: 100%; border-collapse: collapse; }
.debt-table th, .debt-table td { padding: 8px 12px; text-align: left; font-size: 13px; border-bottom: 1px solid var(--savia-surface-variant); }
.debt-table th { font-weight: 600; font-size: 12px; background: var(--savia-surface-variant); }
.severity-badge { padding: 2px 8px; border-radius: 4px; color: white; font-size: 11px; font-weight: 600; text-transform: uppercase; }
</style>
