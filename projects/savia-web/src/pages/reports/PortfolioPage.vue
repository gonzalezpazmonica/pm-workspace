<script setup lang="ts">
import { onMounted, computed } from 'vue'
import { useReportData } from '../../composables/useReportData'
import LoadingSpinner from '../../components/LoadingSpinner.vue'
import PortfolioRadar from '../../components/charts/PortfolioRadar.vue'
import type { PortfolioData } from '../../types/reports'

const portfolio = useReportData<PortfolioData>('/reports/portfolio')
onMounted(() => portfolio.load())

const radarProjects = computed(() =>
  (portfolio.data.value?.projects ?? []).map(p => ({
    name: p.name,
    health: typeof p.health === 'string' ? parseInt(p.health) || 0 : p.health,
    velocity: p.velocity,
    coverage: p.coverage,
    debtCount: p.debt,
    sprintProgress: p.satisfaction / 100,
  }))
)
</script>

<template>
  <div class="portfolio-page">
    <LoadingSpinner v-if="portfolio.loading.value" />
    <template v-else-if="portfolio.data.value">
      <section class="chart-card">
        <h3>Portfolio Health Radar</h3>
        <PortfolioRadar :projects="radarProjects" />
      </section>
      <section class="chart-card">
        <h3>Projects Overview</h3>
        <table class="portfolio-table">
          <thead><tr><th>Project</th><th>Health</th><th>Velocity</th><th>Coverage</th><th>Debt</th><th>Satisfaction</th></tr></thead>
          <tbody>
            <tr v-for="p in portfolio.data.value.projects" :key="p.name">
              <td><strong>{{ p.name }}</strong></td>
              <td>{{ p.health }}</td>
              <td>{{ p.velocity }} SP</td><td>{{ p.coverage }}%</td>
              <td>{{ p.debt }}</td><td>{{ p.satisfaction }}%</td>
            </tr>
          </tbody>
        </table>
      </section>
    </template>
  </div>
</template>

<style scoped>
.portfolio-page { display: flex; flex-direction: column; gap: 20px; }
.chart-card { background: var(--savia-surface); padding: 20px; border-radius: var(--savia-radius-lg); box-shadow: var(--savia-shadow); }
.chart-card h3 { font-size: 15px; margin-bottom: 12px; }
.portfolio-table { width: 100%; border-collapse: collapse; }
.portfolio-table th, .portfolio-table td { padding: 8px 12px; text-align: left; font-size: 13px; border-bottom: 1px solid var(--savia-surface-variant); }
.portfolio-table th { font-weight: 600; font-size: 12px; background: var(--savia-surface-variant); }
</style>
