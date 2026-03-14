<script setup lang="ts">
import { onMounted, watch } from 'vue'
import { useDashboardStore } from '../../stores/dashboard'
import { useReportData } from '../../composables/useReportData'
import LoadingSpinner from '../../components/LoadingSpinner.vue'
import BurndownChart from '../../components/charts/BurndownChart.vue'
import VelocityChart from '../../components/charts/VelocityChart.vue'
import SpDistribution from '../../components/charts/SpDistribution.vue'
import type { BurndownData, VelocityData } from '../../types/reports'

const dashboard = useDashboardStore()
const burndown = useReportData<BurndownData>('/reports/burndown')
const velocity = useReportData<VelocityData>('/reports/velocity')

function loadAll() {
  if (!dashboard.data?.selectedProjectId) return
  burndown.load()
  velocity.load('&sprints=5')
}

onMounted(loadAll)
watch(() => dashboard.data?.selectedProjectId, loadAll)
</script>

<template>
  <div class="sprint-report">
    <LoadingSpinner v-if="burndown.loading.value || velocity.loading.value" />
    <template v-else>
      <section class="chart-card">
        <h3>Burndown</h3>
        <BurndownChart v-if="burndown.data.value" :days="burndown.data.value.days" />
      </section>
      <section class="chart-card">
        <h3>Velocity</h3>
        <VelocityChart v-if="velocity.data.value" :sprints="velocity.data.value.sprints" />
      </section>
      <section v-if="burndown.data.value" class="chart-card">
        <h3>SP Distribution</h3>
        <SpDistribution :states="[
          { name: 'Remaining', value: burndown.data.value.days[burndown.data.value.days.length - 1]?.actual || 0 },
          { name: 'Completed', value: (burndown.data.value.days[0]?.ideal || 0) - (burndown.data.value.days[burndown.data.value.days.length - 1]?.actual || 0) }
        ]" />
      </section>
    </template>
  </div>
</template>

<style scoped>
.sprint-report { display: flex; flex-direction: column; gap: 20px; }
.chart-card { background: var(--savia-surface); padding: 20px; border-radius: var(--savia-radius-lg); box-shadow: var(--savia-shadow); }
.chart-card h3 { font-size: 15px; margin-bottom: 12px; color: var(--savia-on-surface); }
</style>
