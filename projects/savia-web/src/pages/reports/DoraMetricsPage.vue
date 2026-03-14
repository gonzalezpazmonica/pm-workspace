<script setup lang="ts">
import { onMounted, watch } from 'vue'
import { useDashboardStore } from '../../stores/dashboard'
import { useReportData } from '../../composables/useReportData'
import LoadingSpinner from '../../components/LoadingSpinner.vue'
import DoraGauges from '../../components/charts/DoraGauges.vue'
import type { DoraData } from '../../types/reports'

const dashboard = useDashboardStore()
const dora = useReportData<DoraData>('/reports/dora')

function loadAll() {
  if (dashboard.data?.selectedProjectId) dora.load()
}

onMounted(loadAll)
watch(() => dashboard.data?.selectedProjectId, loadAll)

function trendIcon(t: string) {
  return t === 'up' ? '\u2191' : t === 'down' ? '\u2193' : '\u2192'
}
</script>

<template>
  <div class="dora-page">
    <LoadingSpinner v-if="dora.loading.value" />
    <template v-else-if="dora.data.value">
      <section class="chart-card">
        <h3>DORA Metrics</h3>
        <DoraGauges
          :deploy-freq="dora.data.value.deployFrequency"
          :lead-time="dora.data.value.leadTime"
          :cfr="dora.data.value.changeFailureRate"
          :mttr="dora.data.value.mttr"
        />
      </section>
      <section class="chart-card">
        <h3>Trends</h3>
        <div class="trend-grid">
          <div class="trend-item">
            <span class="trend-label">Deploy Frequency</span>
            <span class="trend-value">{{ dora.data.value.deployFrequency.value }}/{{ dora.data.value.deployFrequency.unit }}</span>
            <span class="trend-arrow">{{ trendIcon(dora.data.value.deployFrequency.trend) }}</span>
          </div>
          <div class="trend-item">
            <span class="trend-label">Lead Time</span>
            <span class="trend-value">{{ dora.data.value.leadTime.value }} {{ dora.data.value.leadTime.unit }}</span>
            <span class="trend-arrow">{{ trendIcon(dora.data.value.leadTime.trend) }}</span>
          </div>
          <div class="trend-item">
            <span class="trend-label">Change Failure Rate</span>
            <span class="trend-value">{{ dora.data.value.changeFailureRate.value }}%</span>
            <span class="trend-arrow">{{ trendIcon(dora.data.value.changeFailureRate.trend) }}</span>
          </div>
          <div class="trend-item">
            <span class="trend-label">MTTR</span>
            <span class="trend-value">{{ dora.data.value.mttr.value }} {{ dora.data.value.mttr.unit }}</span>
            <span class="trend-arrow">{{ trendIcon(dora.data.value.mttr.trend) }}</span>
          </div>
        </div>
      </section>
    </template>
  </div>
</template>

<style scoped>
.dora-page { display: flex; flex-direction: column; gap: 20px; }
.chart-card { background: var(--savia-surface); padding: 20px; border-radius: var(--savia-radius-lg); box-shadow: var(--savia-shadow); }
.chart-card h3 { font-size: 15px; margin-bottom: 12px; }
.trend-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }
.trend-item { display: flex; align-items: center; gap: 8px; padding: 12px; background: var(--savia-surface-variant); border-radius: var(--savia-radius); }
.trend-label { flex: 1; font-size: 13px; }
.trend-value { font-weight: 600; font-size: 14px; color: var(--savia-primary); }
.trend-arrow { font-size: 18px; }
</style>
