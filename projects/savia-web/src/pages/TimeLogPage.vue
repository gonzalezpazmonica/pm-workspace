<script setup lang="ts">
import { useI18n } from 'vue-i18n'
const { t } = useI18n()
import { ref, onMounted } from 'vue'
import { useBridge } from '../composables/useBridge'
import { useDashboardStore } from '../stores/dashboard'
import LoadingSpinner from '../components/LoadingSpinner.vue'
import EmptyState from '../components/EmptyState.vue'
import type { TimeEntry } from '../types/bridge'

const { get } = useBridge()
const dashboard = useDashboardStore()
const entries = ref<TimeEntry[]>([])
const loading = ref(false)

async function load() {
  if (!dashboard.data?.selectedProjectId) return
  loading.value = true
  try { entries.value = await get<TimeEntry[]>(`/timelog?project=${dashboard.data.selectedProjectId}`) ?? [] }
  catch { /* ignore */ }
  finally { loading.value = false }
}

onMounted(() => { if (!dashboard.data) dashboard.load().then(load); else load() })
const totalHours = () => entries.value.reduce((s, e) => s + e.hours, 0)
</script>

<template>
  <div class="timelog-page">
    <h1>{{ t('time.title') }}</h1>
    <LoadingSpinner v-if="loading" />
    <EmptyState v-else-if="!entries.length" icon="⏱" title="No time entries" />
    <template v-else>
      <div class="total">Total: {{ totalHours().toFixed(1) }}h</div>
      <table class="entries-table">
        <thead><tr><th>Task</th><th>Hours</th><th>Date</th><th>Note</th></tr></thead>
        <tbody>
          <tr v-for="e in entries" :key="e.id">
            <td>{{ e.taskTitle }}</td>
            <td>{{ e.hours }}h</td>
            <td>{{ e.date }}</td>
            <td>{{ e.note || '-' }}</td>
          </tr>
        </tbody>
      </table>
    </template>
  </div>
</template>

<style scoped>
h1 { font-size: 20px; margin-bottom: 20px; }
.total { font-size: 16px; font-weight: 600; margin-bottom: 12px; color: var(--savia-primary); }
.entries-table { width: 100%; border-collapse: collapse; background: var(--savia-surface); border-radius: var(--savia-radius-lg); overflow: hidden; box-shadow: var(--savia-shadow); }
th, td { padding: 10px 14px; text-align: left; font-size: 13px; border-bottom: 1px solid var(--savia-surface-variant); }
th { background: var(--savia-surface-variant); font-weight: 600; font-size: 12px; text-transform: uppercase; }
</style>
