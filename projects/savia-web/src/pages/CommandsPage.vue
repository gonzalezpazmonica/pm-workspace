<script setup lang="ts">
const families = [
  { id: 'sprint', name: 'Sprint & Reporting', icon: '📅', commands: ['sprint-status', 'sprint-plan', 'daily-routine', 'sprint-review', 'report-executive'] },
  { id: 'backlog', name: 'PBI & Discovery', icon: '📋', commands: ['pbi-decompose', 'backlog-prioritize', 'pbi-plan-sprint', 'spec-generate'] },
  { id: 'quality', name: 'Quality & PRs', icon: '✅', commands: ['pr-review', 'spec-verify', 'code-audit', 'security-review'] },
  { id: 'devops', name: 'DevOps & Infra', icon: '🔧', commands: ['pipeline-status', 'deploy-check', 'infra-plan', 'diagram-generate'] },
  { id: 'team', name: 'Team & Capacity', icon: '👥', commands: ['team-workload', 'capacity-forecast', 'burnout-radar'] },
  { id: 'reports', name: 'Metrics & DORA', icon: '📊', commands: ['kpi-dashboard', 'kpi-dora', 'velocity-trend', 'debt-analyze'] },
]
</script>

<template>
  <div class="commands-page">
    <h1>Commands</h1>
    <div class="families">
      <div v-for="f in families" :key="f.id" class="family-card">
        <div class="family-header">
          <span class="family-icon">{{ f.icon }}</span>
          <span class="family-name">{{ f.name }}</span>
        </div>
        <ul class="cmd-list">
          <li v-for="cmd in f.commands" :key="cmd" class="cmd-item">/{{ cmd }}</li>
        </ul>
      </div>
    </div>
  </div>
</template>

<style scoped>
.commands-page { max-width: 1000px; }
h1 { font-size: 20px; margin-bottom: 20px; }
.families { display: grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); gap: 16px; }
.family-card { background: var(--savia-surface); padding: 16px; border-radius: var(--savia-radius-lg); box-shadow: var(--savia-shadow); }
.family-header { display: flex; align-items: center; gap: 8px; margin-bottom: 12px; }
.family-icon { font-size: 20px; }
.family-name { font-weight: 600; font-size: 15px; }
.cmd-list { list-style: none; }
.cmd-item { padding: 4px 0; font-size: 13px; color: var(--savia-primary); font-family: monospace; cursor: pointer; }
.cmd-item:hover { text-decoration: underline; }
</style>
