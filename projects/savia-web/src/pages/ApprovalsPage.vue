<script setup lang="ts">
import { useI18n } from 'vue-i18n'
const { t } = useI18n()
import { ref, onMounted } from 'vue'
import { useBridge } from '../composables/useBridge'
import { useDashboardStore } from '../stores/dashboard'
import LoadingSpinner from '../components/LoadingSpinner.vue'
import EmptyState from '../components/EmptyState.vue'
import type { ApprovalRequest } from '../types/bridge'

const { get } = useBridge()
const dashboard = useDashboardStore()
const approvals = ref<ApprovalRequest[]>([])
const loading = ref(false)

async function load() {
  if (!dashboard.data?.selectedProjectId) return
  loading.value = true
  try { approvals.value = await get<ApprovalRequest[]>(`/approvals?project=${dashboard.data.selectedProjectId}`) ?? [] }
  catch { /* ignore */ }
  finally { loading.value = false }
}

onMounted(() => { if (!dashboard.data) dashboard.load().then(load); else load() })
</script>

<template>
  <div class="approvals-page">
    <h1>{{ t('approvals.title') }}</h1>
    <LoadingSpinner v-if="loading" />
    <EmptyState v-else-if="!approvals.length" icon="✅" title="No pending approvals" />
    <div v-else class="approval-list">
      <div v-for="a in approvals" :key="a.id" class="approval-card">
        <div class="approval-type">{{ a.type }}</div>
        <h3>{{ a.title }}</h3>
        <p>{{ a.description }}</p>
        <div class="approval-meta">
          <span>By {{ a.requestedBy }}</span>
          <span>{{ a.createdAt }}</span>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
h1 { font-size: 20px; margin-bottom: 20px; }
.approval-list { display: flex; flex-direction: column; gap: 12px; }
.approval-card { background: var(--savia-surface); padding: 16px; border-radius: var(--savia-radius-lg); box-shadow: var(--savia-shadow); }
.approval-type { font-size: 11px; font-weight: 600; color: var(--savia-primary); text-transform: uppercase; margin-bottom: 4px; }
.approval-card h3 { font-size: 15px; margin-bottom: 4px; }
.approval-card p { font-size: 13px; color: var(--savia-on-surface-variant); margin-bottom: 8px; }
.approval-meta { display: flex; justify-content: space-between; font-size: 12px; color: var(--savia-outline); }
</style>
