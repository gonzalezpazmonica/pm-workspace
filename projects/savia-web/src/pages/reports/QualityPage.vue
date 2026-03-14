<script setup lang="ts">
import { onMounted, watch, computed } from 'vue'
import { useDashboardStore } from '../../stores/dashboard'
import { useReportData } from '../../composables/useReportData'
import LoadingSpinner from '../../components/LoadingSpinner.vue'
import CoverageGauge from '../../components/charts/CoverageGauge.vue'
import BugSeverityPie from '../../components/charts/BugSeverityPie.vue'
import type { QualityData } from '../../types/reports'

const dashboard = useDashboardStore()
const quality = useReportData<QualityData>('/reports/quality')

function loadAll() {
  if (dashboard.data?.selectedProjectId) quality.load()
}

onMounted(loadAll)
watch(() => dashboard.data?.selectedProjectId, loadAll)

function bugCount(severity: string): number {
  return quality.data.value?.bugs.find(b => b.severity === severity)?.count ?? 0
}

const bugsObj = computed(() => ({
  critical: bugCount('critical'),
  high: bugCount('high'),
  medium: bugCount('medium'),
  low: bugCount('low'),
}))
</script>

<template>
  <div class="quality-page">
    <LoadingSpinner v-if="quality.loading.value" />
    <template v-else-if="quality.data.value">
      <div class="charts-row">
        <section class="chart-card">
          <h3>Test Coverage</h3>
          <CoverageGauge :coverage="quality.data.value.coverage" :target="quality.data.value.coverageTarget" />
        </section>
        <section class="chart-card">
          <h3>Bug Severity</h3>
          <BugSeverityPie :bugs="bugsObj" />
        </section>
      </div>
      <section class="chart-card">
        <h3>Quality Metrics</h3>
        <div class="metrics-row">
          <div class="metric">
            <div class="metric-value">{{ quality.data.value.coverage }}%</div>
            <div class="metric-label">Coverage</div>
          </div>
          <div class="metric">
            <div class="metric-value">{{ quality.data.value.escapeRate }}%</div>
            <div class="metric-label">Escape Rate</div>
          </div>
          <div class="metric">
            <div class="metric-value">{{ bugsObj.critical + bugsObj.high }}</div>
            <div class="metric-label">Critical+High Bugs</div>
          </div>
        </div>
      </section>
    </template>
  </div>
</template>

<style scoped>
.quality-page { display: flex; flex-direction: column; gap: 20px; }
.charts-row { display: grid; grid-template-columns: 1fr 1fr; gap: 20px; }
.chart-card { background: var(--savia-surface); padding: 20px; border-radius: var(--savia-radius-lg); box-shadow: var(--savia-shadow); }
.chart-card h3 { font-size: 15px; margin-bottom: 12px; }
.metrics-row { display: flex; gap: 32px; justify-content: center; }
.metric { text-align: center; }
.metric-value { font-size: 24px; font-weight: 700; color: var(--savia-primary); }
.metric-label { font-size: 12px; color: var(--savia-on-surface-variant); }
@media (max-width: 768px) { .charts-row { grid-template-columns: 1fr; } }
</style>
