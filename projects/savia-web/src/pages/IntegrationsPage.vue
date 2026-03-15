<script setup lang="ts">
import { useI18n } from 'vue-i18n'
const { t } = useI18n()
import { onMounted, ref } from 'vue'
import { Zap, Play, Pause, CheckCircle, XCircle, Loader } from 'lucide-vue-next'
import { useIntegrationsStore } from '../stores/integrations'
import LoadingSpinner from '../components/LoadingSpinner.vue'

const store = useIntegrationsStore()
const setupUrl = ref('')
const setupKey = ref('')
onMounted(() => store.load())

function saveSetup() { store.saveConnection(setupUrl.value, setupKey.value) }

const statusColor: Record<string, string> = {
  success: '#22c55e', error: '#ef4444', running: '#3b82f6',
}
</script>

<template>
  <div class="integrations-page">
    <h1 class="page-title"><Zap :size="20" />{{ t('integrations.title') }}</h1>
    <LoadingSpinner v-if="store.loading" />
    <template v-else>
      <section class="section">
        <h2>{{ t('integrations.connection') }}</h2>
        <div class="setup-form" v-if="!store.connection.connected">
          <input v-model="setupUrl" placeholder="n8n URL (e.g. http://localhost:5678)" class="input" />
          <input v-model="setupKey" placeholder="API Key" type="password" class="input" />
          <button class="btn-primary" @click="saveSetup">{{ t('common.connect') }}</button>
        </div>
        <div v-else class="connected-badge">Connected to {{ store.connection.url }}</div>
      </section>

      <section class="section">
        <h2>{{ t('integrations.workflows') }}</h2>
        <div class="workflow-grid">
          <div v-for="wf in store.workflows" :key="wf.id" class="wf-card">
            <div class="wf-header">
              <component :is="wf.active ? Play : Pause" :size="14" :style="{ color: wf.active ? '#22c55e' : '#9ca3af' }" />
              <span class="wf-name">{{ wf.name }}</span>
            </div>
            <div class="wf-meta">{{ wf.triggerType }} &middot; {{ wf.lastExecution }}</div>
          </div>
        </div>
      </section>

      <section class="section">
        <h2>{{ t('integrations.executions') }}</h2>
        <table class="exec-table">
          <thead><tr><th>Workflow</th><th>Status</th><th>Started</th><th>Duration</th></tr></thead>
          <tbody>
            <tr v-for="ex in store.executions" :key="ex.id">
              <td>{{ ex.workflowName }}</td>
              <td>
                <component :is="ex.status === 'success' ? CheckCircle : ex.status === 'error' ? XCircle : Loader" :size="14" :style="{ color: statusColor[ex.status] }" />
                {{ ex.status }}
              </td>
              <td>{{ ex.startedAt }}</td>
              <td>{{ ex.duration }}</td>
            </tr>
          </tbody>
        </table>
      </section>
    </template>
  </div>
</template>

<style scoped>
.integrations-page { max-width: 900px; }
.page-title { font-size: 18px; font-weight: 600; display: flex; align-items: center; gap: 8px; margin-bottom: 16px; }
.section { margin-bottom: 24px; }
.section h2 { font-size: 15px; font-weight: 600; margin-bottom: 10px; }
.setup-form { display: flex; gap: 8px; flex-wrap: wrap; }
.input { padding: 8px 12px; border: 1px solid var(--savia-outline); border-radius: var(--savia-radius); font-size: 13px; min-width: 200px; }
.btn-primary { padding: 8px 16px; background: var(--savia-primary); color: white; border-radius: var(--savia-radius); font-weight: 600; border: none; cursor: pointer; }
.connected-badge { padding: 8px 14px; background: var(--savia-success-container); color: var(--savia-success); border-radius: var(--savia-radius); font-size: 13px; display: inline-block; }
.workflow-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(240px, 1fr)); gap: 10px; }
.wf-card { background: var(--savia-surface); padding: 12px; border-radius: var(--savia-radius); box-shadow: var(--savia-shadow); }
.wf-header { display: flex; align-items: center; gap: 8px; margin-bottom: 4px; }
.wf-name { font-weight: 500; font-size: 13px; }
.wf-meta { font-size: 11px; color: var(--savia-outline); }
.exec-table { width: 100%; border-collapse: collapse; font-size: 13px; }
.exec-table th { text-align: left; padding: 8px; border-bottom: 1px solid var(--savia-surface-variant); font-weight: 600; font-size: 12px; color: var(--savia-outline); }
.exec-table td { padding: 8px; border-bottom: 1px solid var(--savia-surface-variant); }
.exec-table td:nth-child(2) { display: flex; align-items: center; gap: 4px; }
</style>
